import SwiftUI

struct InventoryView: View {
    @State private var items: [InventoryItem] = []
    @State private var isLoading = false
    @State private var showAddSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && items.isEmpty {
                    ProgressView("Loading pantry…").tint(.orange)
                } else if items.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Pantry")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus")
                    }
                    .tint(.orange)
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddInventoryItemSheet { name, status in
                    await addItem(name: name, status: status)
                }
            }
            .refreshable { await load() }
            .task { await load() }
        }
    }

    // MARK: - List

    private var list: some View {
        List {
            ForEach(items) { item in
                InventoryRow(item: item) { newStatus in
                    await updateStatus(item: item, to: newStatus)
                }
            }
            .onDelete { offsets in
                let toDelete = offsets.map { items[$0] }
                items.remove(atOffsets: offsets)
                Task {
                    for item in toDelete {
                        try? await APIClient.shared.deleteInventoryItem(id: item.id)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "archivebox")
                .font(.system(size: 52))
                .foregroundStyle(.orange.opacity(0.5))
            Text("Your pantry is empty")
                .font(.headline)
            Text("Tap + to add ingredients you already have.\nThe app uses this to build your grocery list.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Add first item") { showAddSheet = true }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
        }
        .padding(32)
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        items = (try? await APIClient.shared.getInventory()) ?? []
        isLoading = false
    }

    private func addItem(name: String, status: String) async {
        guard let item = try? await APIClient.shared.addInventoryItem(name: name, status: status) else { return }
        // Upsert: replace if canonical name already exists, else prepend
        if let idx = items.firstIndex(where: { $0.canonicalName == item.canonicalName }) {
            items[idx] = item
        } else {
            items.insert(item, at: 0)
        }
        items.sort { $0.canonicalName < $1.canonicalName }
    }

    private func updateStatus(item: InventoryItem, to status: String) async {
        guard let updated = try? await APIClient.shared.updateInventoryItem(id: item.id, status: status) else { return }
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx] = updated
        }
    }
}

// MARK: - Inventory row

private struct InventoryRow: View {
    let item: InventoryItem
    let onStatusChange: (String) async -> Void

    @State private var showPicker = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.canonicalName)
                    .font(.body)
                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(statusColor.opacity(0.8))
            }

            Spacer()

            // Status pill — tap to change
            Button { showPicker = true } label: {
                Circle()
                    .fill(statusColor)
                    .frame(width: 14, height: 14)
                    .padding(8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .confirmationDialog("Update status for \(item.canonicalName)",
                            isPresented: $showPicker,
                            titleVisibility: .visible) {
            ForEach(InventoryStatus.allCases) { s in
                Button(s.label) { Task { await onStatusChange(s.rawValue) } }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var statusLabel: String { InventoryStatus(rawValue: item.status)?.label ?? item.status }
    private var statusColor: Color  { InventoryStatus(rawValue: item.status)?.color ?? .gray }
}

// MARK: - Status enum

enum InventoryStatus: String, CaseIterable, Identifiable {
    case inStock    = "in_stock"
    case low        = "low"
    case alwaysHave = "always_have"
    case outOfStock = "out_of_stock"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .inStock:    return "In stock"
        case .low:        return "Running low"
        case .alwaysHave: return "Always have"
        case .outOfStock: return "Out of stock"
        }
    }

    var color: Color {
        switch self {
        case .inStock:    return .green
        case .low:        return .orange
        case .alwaysHave: return .blue
        case .outOfStock: return .red
        }
    }
}

// MARK: - Add item sheet

private struct AddInventoryItemSheet: View {
    let onAdd: (String, String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var status = InventoryStatus.inStock
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Ingredient") {
                    TextField("e.g. olive oil, chicken breast…", text: $name)
                        .autocorrectionDisabled()
                }
                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(InventoryStatus.allCases) { s in
                            Label(s.label, systemImage: statusIcon(s))
                                .tag(s)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("Add to Pantry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        isSaving = true
                        Task {
                            await onAdd(name.lowercased().trimmingCharacters(in: .whitespaces), status.rawValue)
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func statusIcon(_ s: InventoryStatus) -> String {
        switch s {
        case .inStock:    return "checkmark.circle.fill"
        case .low:        return "exclamationmark.circle.fill"
        case .alwaysHave: return "star.circle.fill"
        case .outOfStock: return "xmark.circle.fill"
        }
    }
}
