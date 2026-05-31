import SwiftUI

// MARK: - Album kind

enum AlbumKind {
    case all
    case favorites
    case custom(id: String, name: String)
}

// MARK: - Album detail view

struct AlbumDetailView: View {
    let kind: AlbumKind

    @State private var recipes: [RecipeListItem] = []
    @State private var isLoading = false
    @State private var deleteError: String?
    @State private var showAddSheet = false

    private var title: String {
        switch kind {
        case .all:              return "All"
        case .favorites:        return "Favorites"
        case .custom(_, let n): return n
        }
    }

    private var isCustom: Bool {
        if case .custom = kind { return true }
        return false
    }

    private var customAlbumId: String? {
        if case .custom(let id, _) = kind { return id }
        return nil
    }

    private var canDeleteFromList: Bool {
        // Favorites: no swipe-delete (unfavorite via detail view)
        if case .favorites = kind { return false }
        return true
    }

    var body: some View {
        mainContent
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isCustom {
                        Button { showAddSheet = true } label: {
                            Image(systemName: "plus")
                        }
                        .tint(.orange)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet, onDismiss: { Task { await load() } }) {
                if let albumId = customAlbumId {
                    AddToAlbumSheet(albumId: albumId, existingIds: Set(recipes.map { $0.id }))
                }
            }
            .alert("Error", isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )) {
                Button("OK", role: .cancel) { deleteError = nil }
            } message: {
                Text(deleteError ?? "")
            }
            .task { await load() }
            .onAppear { Task { await load() } }
    }

    @ViewBuilder
    private var mainContent: some View {
        if isLoading && recipes.isEmpty {
            ProgressView("Loading…").tint(.orange)
        } else if recipes.isEmpty {
            emptyState
        } else {
            recipeList
        }
    }

    private var recipeList: some View {
        List {
            ForEach(recipes) { recipe in
                NavigationLink(destination: RecipeDetailView(
                    recipeId: recipe.id,
                    recipeTitle: recipe.dishName
                )) {
                    RecipeRow(recipe: recipe)
                }
            }
            .onDelete(perform: canDeleteFromList ? { handleDelete(at: $0) } : nil)
        }
        .listStyle(.plain)
        .refreshable { await load() }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: emptyIcon)
                .font(.system(size: 52))
                .foregroundStyle(.orange.opacity(0.4))
            Text(emptyTitle).font(.headline)
            Text(emptyMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyIcon: String {
        switch kind {
        case .all:      return "bookmark"
        case .favorites: return "heart"
        case .custom:   return "rectangle.stack"
        }
    }

    private var emptyTitle: String {
        switch kind {
        case .all:      return "No saved recipes"
        case .favorites: return "No favorites yet"
        case .custom:   return "Album is empty"
        }
    }

    private var emptyMessage: String {
        switch kind {
        case .all:      return "Share a cooking video from TikTok or Instagram to save recipes."
        case .favorites: return "Heart a recipe to add it to your favorites."
        case .custom:   return "Tap + to add recipes to this album."
        }
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        switch kind {
        case .all:
            if let r = try? await APIClient.shared.getRecipes() { recipes = r }
        case .favorites:
            if let r = try? await APIClient.shared.getRecipes() { recipes = r.filter { $0.isFavorited } }
        case .custom(let id, _):
            if let r = try? await APIClient.shared.getAlbumRecipes(id: id) { recipes = r }
        }
        isLoading = false
    }

    // MARK: - Delete

    private func handleDelete(at offsets: IndexSet) {
        let toDelete = offsets.map { recipes[$0] }
        recipes.remove(atOffsets: offsets)
        Task {
            for recipe in toDelete {
                do {
                    switch kind {
                    case .all:
                        try await APIClient.shared.deleteRecipe(id: recipe.id)
                    case .custom(let albumId, _):
                        try await APIClient.shared.removeRecipeFromAlbum(albumId: albumId, recipeId: recipe.id)
                    case .favorites:
                        break
                    }
                } catch {
                    await MainActor.run {
                        recipes.insert(recipe, at: 0)
                        deleteError = error.localizedDescription
                    }
                }
            }
        }
    }
}

// MARK: - Add to album sheet

struct AddToAlbumSheet: View {
    let albumId: String
    let existingIds: Set<String>

    @Environment(\.dismiss) private var dismiss
    @State private var allRecipes: [RecipeListItem] = []
    @State private var selected = Set<String>()
    @State private var isLoading = true
    @State private var isAdding = false

    private var available: [RecipeListItem] { allRecipes.filter { !existingIds.contains($0.id) } }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading recipes…").tint(.orange)
                } else if available.isEmpty {
                    Text("All your recipes are already in this album.")
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    List(available) { recipe in
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
            .navigationTitle("Add to Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isAdding ? "Adding…" : "Add\(selected.isEmpty ? "" : " (\(selected.count))")") {
                        isAdding = true
                        Task {
                            for id in selected {
                                try? await APIClient.shared.addRecipeToAlbum(albumId: albumId, recipeId: id)
                            }
                            dismiss()
                        }
                    }
                    .disabled(selected.isEmpty || isAdding)
                    .tint(.orange)
                }
            }
            .task {
                allRecipes = (try? await APIClient.shared.getRecipes()) ?? []
                isLoading = false
            }
        }
        .presentationDetents([.large])
    }
}
