import SwiftUI

struct RecipesListView: View {
    @State private var recipes: [RecipeListItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && recipes.isEmpty {
                    ProgressView("Loading recipes…").tint(.orange)

                } else if recipes.isEmpty {
                    EmptyStateView()

                } else {
                    List {
                        ForEach(recipes) { recipe in
                            NavigationLink(destination: RecipeDetailView(recipeId: recipe.id, recipeTitle: recipe.dishName)) {
                                RecipeRow(recipe: recipe)
                            }
                        }
                        .onDelete(perform: deleteRecipes)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Cook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "fork.knife.circle.fill")
                            .foregroundStyle(.orange)
                        Text("Cook")
                            .font(.headline.bold())
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: loadRecipes) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .tint(.orange)
                }
            }
            .refreshable { loadRecipes() }
        }
        .task { loadRecipes() }
    }

    private func loadRecipes() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let result = try await APIClient.shared.getRecipes()
                await MainActor.run {
                    recipes = result
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func deleteRecipes(at offsets: IndexSet) {
        let toDelete = offsets.map { recipes[$0] }
        recipes.remove(atOffsets: offsets)
        Task {
            for recipe in toDelete {
                try? await APIClient.shared.deleteRecipe(id: recipe.id)
            }
        }
    }
}

// MARK: - Recipe row

struct RecipeRow: View {
    let recipe: RecipeListItem

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            Group {
                if let urlStr = recipe.thumbnailURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .failure, .empty:
                            placeholder
                        @unknown default:
                            placeholder
                        }
                    }
                } else {
                    placeholder
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.dishName)
                    .font(.headline)
                    .lineLimit(2)

                if let creator = recipe.creatorName {
                    Text(creator)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text("\(recipe.ingredientCount) ingredients")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.orange.opacity(0.12))
            Image(systemName: "fork.knife")
                .foregroundStyle(.orange)
        }
    }
}

