import SwiftUI

// MARK: - Main detail view

struct RecipeDetailView: View {
    let recipeId: String
    let recipeTitle: String

    @State private var recipe: RecipeDetail?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading…").tint(.orange)
            } else if let error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle).foregroundStyle(.red)
                    Text(error).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .padding()
            } else if let recipe {
                RecipeDetailContent(recipe: recipe)
            }
        }
        .navigationTitle(recipeTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        do { recipe = try await APIClient.shared.getRecipe(id: recipeId) }
        catch { self.error = error.localizedDescription }
        isLoading = false
    }
}

// MARK: - Scrollable content

private struct RecipeDetailContent: View {
    let recipe: RecipeDetail

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                VideoThumbnailCard(recipe: recipe)

                if !recipe.ingredients.isEmpty {
                    SectionCard(title: "Ingredients", icon: "cart") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(recipe.ingredients) { ing in
                                IngredientDetailRow(ingredient: ing)
                                if ing.id != recipe.ingredients.last?.id { Divider() }
                            }
                        }
                    }
                }

                if !recipe.steps.isEmpty {
                    SectionCard(title: "Instructions", icon: "list.number") {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                        .frame(width: 28, height: 28)
                                        .background(.orange, in: Circle())
                                    Text(step)
                                        .font(.body)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }

                HStack {
                    Spacer()
                    Text("Extraction confidence: \(Int(recipe.confidence * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                }
            }
            .padding()
        }
    }
}

// MARK: - Square thumbnail card with platform watch button

private struct VideoThumbnailCard: View {
    let recipe: RecipeDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let creator = recipe.creatorName {
                Label(creator, systemImage: "person.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ZStack(alignment: .bottomTrailing) {
                // Rectangle establishes the square FIRST — image fills it via overlay.
                // This prevents AsyncImage from dictating its own size.
                Rectangle()
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Group {
                            if let urlStr = recipe.thumbnailURL, let url = URL(string: urlStr) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let img):
                                        img.resizable().scaledToFill()
                                    default:
                                        Color(.systemGray5)
                                    }
                                }
                            } else {
                                Color(.systemGray5)
                                    .overlay(
                                        Image(systemName: "film")
                                            .font(.largeTitle)
                                            .foregroundStyle(.tertiary)
                                    )
                            }
                        }
                    )
                    .clipped()

                // Discrete "Watch on …" button — bottom right
                if let urlStr = recipe.sourceURL, let url = URL(string: urlStr) {
                    Link(destination: url) {
                        HStack(spacing: 5) {
                            Text(watchLabel)
                                .font(.caption.weight(.semibold))
                            Image(systemName: "arrow.up.right")
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.55), in: Capsule())
                    }
                    .padding(10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    /// "Watch on TikTok", "Watch on Instagram", etc.
    private var watchLabel: String {
        switch recipe.platform.lowercased() {
        case "tiktok":    return "Watch on TikTok"
        case "instagram": return "Watch on Instagram"
        case "youtube":   return "Watch on YouTube"
        default:          return "Watch Video"
        }
    }
}

// MARK: - Reusable section card

private struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.headline)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Ingredient row

private struct IngredientDetailRow: View {
    let ingredient: IngredientResponse

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: categoryIcon(ingredient.category))
                .frame(width: 20)
                .foregroundStyle(.orange.opacity(0.8))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if let qty = ingredient.quantity { Text(qty).fontWeight(.medium) }
                    if let unit = ingredient.unit    { Text(unit).foregroundStyle(.secondary) }
                    Text(ingredient.canonicalName).fontWeight(.medium)
                }
                .font(.subheadline)

                if ingredient.rawText.lowercased() != ingredient.canonicalName.lowercased() {
                    Text(ingredient.rawText)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if let notes = ingredient.notes {
                    Text(notes).font(.caption).foregroundStyle(.secondary).italic()
                }
            }
        }
    }

    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "produce":  return "leaf.fill"
        case "dairy":    return "drop.fill"
        case "meat":     return "flame.fill"
        case "pantry":   return "cabinet.fill"
        case "spice":    return "sparkles"
        case "grain":    return "circle.grid.2x2.fill"
        default:         return "circle.fill"
        }
    }
}
