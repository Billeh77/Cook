import SwiftUI

struct GroceryListView: View {
    @EnvironmentObject var store: RecipeStore

    @State private var items: [GroceryListItem] = []
    @State private var isLoading = false
    @State private var showRecipePicker = false
    @State private var showUnlockSheet = false

    private var checked: [GroceryListItem] { items.filter { $0.checked } }

    private var categories: [(String, [GroceryListItem])] {
        let grouped = Dictionary(grouping: items) { $0.category }
        return grouped.sorted { $0.key < $1.key }
    }

    /// Recipes that are currently missing ingredients but would be fully cookable
    /// once every item on this grocery list is bought.
    private var unlockedRecipes: [CookabilityItem] {
        let groceryNames = Set(items.map { $0.canonicalName.lowercased() })
        return store.cookabilityItems
            .filter { recipe in
                guard recipe.missingCount > 0 else { return false }
                return recipe.missingIngredients.allSatisfy {
                    groceryNames.contains($0.lowercased())
                }
            }
            .sorted { $0.dishName < $1.dishName }
    }

    /// How many unlockable recipes each grocery item appears in as a missing ingredient.
    /// e.g. { "eggs": 3, "milk": 1 }
    private var ingredientRecipeCount: [String: Int] {
        var counts: [String: Int] = [:]
        for recipe in unlockedRecipes {
            for ingredient in recipe.missingIngredients {
                counts[ingredient.lowercased(), default: 0] += 1
            }
        }
        return counts
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
            .sheet(isPresented: $showUnlockSheet) {
                UnlockRecipesSheet(recipes: unlockedRecipes)
            }
            .refreshable { await load() }
            .task { await load() }
            // FAB — only when list is non-empty
            .safeAreaInset(edge: .bottom, alignment: .trailing) {
                if !items.isEmpty {
                    unlockFAB
                        .padding(.trailing, 20)
                        .padding(.bottom, 12)
                }
            }
        }
    }

    // MARK: - Floating action button

    private var unlockFAB: some View {
        Button { showUnlockSheet = true } label: {
            ZStack {
                Circle()
                    .fill(.orange)
                    .frame(width: 56, height: 56)
                    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
            // Green badge showing unlock count
            .overlay(alignment: .topTrailing) {
                if !unlockedRecipes.isEmpty {
                    Text("\(unlockedRecipes.count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(.green, in: Capsule())
                        .offset(x: 6, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - List

    private var list: some View {
        List {
            ForEach(categories, id: \.0) { category, catItems in
                Section(categoryLabel(category)) {
                    ForEach(catItems) { item in
                        GroceryRow(
                            item: item,
                            recipeCount: ingredientRecipeCount[item.canonicalName.lowercased()] ?? 0
                        ) { await toggle(item) }
                    }
                    .onDelete { offsets in deleteItems(catItems, at: offsets) }
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
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            if let updated = try? await APIClient.shared.checkGroceryItem(id: item.id, checked: !item.checked) {
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
    let recipeCount: Int
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

                // Recipe unlock count badge — only shown when this item
                // contributes to at least one unlockable recipe
                if recipeCount > 0 && !item.checked {
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9, weight: .bold))
                        Text("\(recipeCount)")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.orange, in: Capsule())
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Unlock recipes sheet

private struct UnlockRecipesSheet: View {
    let recipes: [CookabilityItem]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if recipes.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "cart.badge.questionmark")
                            .font(.system(size: 44))
                            .foregroundStyle(.orange.opacity(0.4))
                        Text("No recipes unlocked yet")
                            .font(.headline)
                        Text("Add more missing ingredients to your list\nand they'll appear here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(recipes) { recipe in
                                UnlockRecipeRow(recipe: recipe)
                                if recipe.id != recipes.last?.id {
                                    Divider().padding(.leading, 80)
                                }
                            }
                        }
                        .background(
                            .quaternary.opacity(0.4),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle(recipes.isEmpty
                ? "Unlocks After Shopping"
                : "Unlocks \(recipes.count) Recipe\(recipes.count == 1 ? "" : "s")"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Unlock recipe row

private struct UnlockRecipeRow: View {
    let recipe: CookabilityItem

    private var missingText: String {
        if recipe.missingCount == 1 {
            return "Missing: \(recipe.missingIngredients.first ?? "")"
        } else if recipe.missingCount <= 3 {
            return "Missing: \(recipe.missingIngredients.joined(separator: ", "))"
        } else {
            return "Missing \(recipe.missingCount) ingredients"
        }
    }

    var body: some View {
        NavigationLink {
            RecipeDetailView(
                recipeId: recipe.id,
                recipeTitle: recipe.dishName,
                missingIngredients: recipe.missingIngredients
            )
        } label: {
            HStack(spacing: 14) {
                // Thumbnail
                Group {
                    if let urlStr = recipe.thumbnailURL, let url = URL(string: urlStr) {
                        CachedAsyncImage(url: url) { img in img.resizable().scaledToFill() }
                            placeholder: { Color(.systemGray5) }
                    } else {
                        Color(.systemGray5)
                            .overlay(Image(systemName: "fork.knife").foregroundStyle(.tertiary))
                    }
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.dishName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    // Grocery list covers all missing — show what's being unlocked
                    HStack(spacing: 4) {
                        Image(systemName: "cart.fill.badge.plus")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text(missingText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
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
