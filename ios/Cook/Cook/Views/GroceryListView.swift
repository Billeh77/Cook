import SwiftUI

struct GroceryListView: View {
    @State private var items: [GroceryListItem] = []
    @State private var isLoading = false
    @State private var showRecipePicker = false

    // Items split into unchecked (grouped by category) and checked
    private var unchecked: [GroceryListItem] { items.filter { !$0.checked } }
    private var checked:   [GroceryListItem] { items.filter {  $0.checked } }

    // Group unchecked by category, sorted
    private var categories: [(String, [GroceryListItem])] {
        let grouped = Dictionary(grouping: unchecked) { $0.category }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && items.isEmpty {
                    ProgressView("Loading…").tint(.orange)
                } else if items.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Grocery List")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !checked.isEmpty {
                        Button("Clear done") {
                            Task { await clearChecked() }
                        }
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showRecipePicker = true } label: {
                        Image(systemName: "plus")
                    }
                    .tint(.orange)
                }
            }
            .sheet(isPresented: $showRecipePicker) {
                RecipePickerSheet { selectedIds in
                    await generateList(from: selectedIds)
                }
            }
            .refreshable { await load() }
            .task { await load() }
        }
    }

    // MARK: - List

    private var list: some View {
        List {
            // Unchecked items grouped by category
            ForEach(categories, id: \.0) { category, catItems in
                Section(categoryLabel(category)) {
                    ForEach(catItems) { item in
                        GroceryRow(item: item) { await toggle(item) }
                    }
                    .onDelete { offsets in deleteItems(catItems, at: offsets) }
                }
            }

            // Checked items at the bottom
            if !checked.isEmpty {
                Section("Done") {
                    ForEach(checked) { item in
                        GroceryRow(item: item) { await toggle(item) }
                    }
                    .onDelete { offsets in deleteItems(checked, at: offsets) }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "cart")
                .font(.system(size: 52))
                .foregroundStyle(.orange.opacity(0.5))
            Text("List is empty")
                .font(.headline)
            Text("Tap + to pick recipes and we'll figure out\nwhat you need to buy.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Add recipes") { showRecipePicker = true }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
        }
        .padding(32)
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        items = (try? await APIClient.shared.getGroceryList()) ?? []
        isLoading = false
    }

    private func generateList(from recipeIds: [String]) async {
        guard !recipeIds.isEmpty else { return }
        items = (try? await APIClient.shared.generateGroceryList(recipeIds: recipeIds)) ?? items
    }

    private func toggle(_ item: GroceryListItem) async {
        // Optimistic update
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            let newChecked = !item.checked
            // Rebuild with toggled value (struct is immutable so re-fetch from API)
            if let updated = try? await APIClient.shared.checkGroceryItem(id: item.id, checked: newChecked) {
                items[idx] = updated
            }
        }
    }

    private func clearChecked() async {
        try? await APIClient.shared.clearCheckedGroceryItems()
        items.removeAll { $0.checked }
    }

    private func deleteItems(_ source: [GroceryListItem], at offsets: IndexSet) {
        let toDelete = offsets.map { source[$0] }
        items.removeAll { item in toDelete.contains { $0.id == item.id } }
        Task {
            for item in toDelete {
                try? await APIClient.shared.deleteGroceryItem(id: item.id)
            }
        }
    }

    private func categoryLabel(_ raw: String) -> String {
        raw.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

// MARK: - Grocery row

private struct GroceryRow: View {
    let item: GroceryListItem
    let onToggle: () async -> Void

    var body: some View {
        Button { Task { await onToggle() } } label: {
            HStack(spacing: 12) {
                Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.checked ? .green : Color(.tertiaryLabel))

                Text(item.canonicalName)
                    .strikethrough(item.checked)
                    .foregroundStyle(item.checked ? .secondary : .primary)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recipe picker sheet

private struct RecipePickerSheet: View {
    let onGenerate: ([String]) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var recipes: [RecipeListItem] = []
    @State private var selected = Set<String>()
    @State private var isLoading = true
    @State private var isGenerating = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading recipes…").tint(.orange)
                } else if recipes.isEmpty {
                    Text("No saved recipes yet.")
                        .foregroundStyle(.secondary)
                } else {
                    List(recipes, selection: $selected) { recipe in
                        HStack(spacing: 12) {
                            // Selection indicator
                            Image(systemName: selected.contains(recipe.id)
                                  ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selected.contains(recipe.id) ? .orange : Color(.tertiaryLabel))
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(recipe.dishName).font(.body)
                                Text("\(recipe.ingredientCount) ingredients")
                                    .font(.caption).foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selected.contains(recipe.id) { selected.remove(recipe.id) }
                            else { selected.insert(recipe.id) }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Pick Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isGenerating ? "Adding…" : "Add \(selected.count > 0 ? "(\(selected.count))" : "")") {
                        isGenerating = true
                        Task {
                            await onGenerate(Array(selected))
                            dismiss()
                        }
                    }
                    .disabled(selected.isEmpty || isGenerating)
                    .tint(.orange)
                }
            }
            .task {
                recipes = (try? await APIClient.shared.getRecipes()) ?? []
                isLoading = false
            }
        }
        .presentationDetents([.large])
    }
}
