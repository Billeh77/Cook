import SwiftUI

struct InventoryView: View {
    @State private var items: [InventoryItem] = []
    @State private var isLoading = false
    @State private var showAddSheet = false

    private var categories: [(String, [InventoryItem])] {
        let grouped = Dictionary(grouping: items) { $0.category }
        return grouped.sorted { categoryOrder($0.key) < categoryOrder($1.key) }
    }

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
            ForEach(categories, id: \.0) { category, catItems in
                Section(categoryLabel(category)) {
                    ForEach(catItems) { item in
                        InventoryRow(item: item) { newStatus in
                            await updateStatus(item: item, to: newStatus)
                        } onDelete: {
                            deleteItem(item)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
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

    // MARK: - Helpers

    private func categoryLabel(_ raw: String) -> String {
        switch raw {
        case "produce": return "Produce"
        case "dairy":   return "Dairy"
        case "meat":    return "Meat & Seafood"
        case "grain":   return "Grains & Bread"
        case "spice":   return "Spices & Seasonings"
        case "pantry":  return "Pantry"
        default:        return "Other"
        }
    }

    private func categoryOrder(_ raw: String) -> Int {
        ["produce", "meat", "dairy", "grain", "pantry", "spice", "other"]
            .firstIndex(of: raw) ?? 99
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        items = (try? await APIClient.shared.getInventory()) ?? []
        isLoading = false
    }

    private func addItem(name: String, status: String) async {
        guard let item = try? await APIClient.shared.addInventoryItem(name: name, status: status) else { return }
        if let idx = items.firstIndex(where: { $0.canonicalName == item.canonicalName }) {
            items[idx] = item
        } else {
            items.append(item)
        }
    }

    private func updateStatus(item: InventoryItem, to status: String) async {
        guard let updated = try? await APIClient.shared.updateInventoryItem(id: item.id, status: status) else { return }
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx] = updated
        }
    }

    private func deleteItem(_ item: InventoryItem) {
        items.removeAll { $0.id == item.id }
        Task { try? await APIClient.shared.deleteInventoryItem(id: item.id) }
    }
}

// MARK: - Inventory row

private struct InventoryRow: View {
    let item: InventoryItem
    let onStatusChange: (String) async -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.canonicalName)
                    .font(.body)
                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }

            Spacer()
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            ForEach(InventoryStatus.allCases) { s in
                if s.rawValue != item.status {
                    Button {
                        Task { await onStatusChange(s.rawValue) }
                    } label: {
                        Label(s.label, systemImage: statusIcon(s))
                    }
                    .tint(s.color)
                }
            }
        }
        .contextMenu {
            ForEach(InventoryStatus.allCases) { s in
                Button {
                    Task { await onStatusChange(s.rawValue) }
                } label: {
                    Label(s.label, systemImage: statusIcon(s))
                }
            }
            Divider()
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var statusLabel: String { InventoryStatus(rawValue: item.status)?.label ?? item.status }
    private var statusColor: Color  { InventoryStatus(rawValue: item.status)?.color ?? .gray }

    private func statusIcon(_ s: InventoryStatus) -> String {
        switch s {
        case .inStock:    return "checkmark.circle.fill"
        case .low:        return "exclamationmark.circle.fill"
        case .alwaysHave: return "star.circle.fill"
        case .outOfStock: return "xmark.circle.fill"
        }
    }
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
