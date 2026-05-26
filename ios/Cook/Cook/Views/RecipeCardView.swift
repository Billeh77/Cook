import SwiftUI

struct RecipeCardView: View {
    let recipe: IngestResponse
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text(recipe.dishName ?? "Unknown Dish")
                        .font(.title2.bold())

                    if let creator = recipe.creatorName {
                        Label(creator, systemImage: "person.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let urlStr = recipe.sourceURL, let url = URL(string: urlStr) {
                        Link(destination: url) {
                            Label("Watch original video", systemImage: "play.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                // Ingredients
                if !recipe.ingredients.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ingredients")
                            .font(.headline)

                        ForEach(recipe.ingredients) { ingredient in
                            IngredientRow(ingredient: ingredient)
                        }
                    }
                    .padding()
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                // Confidence badge
                HStack {
                    Spacer()
                    Text("Extraction confidence: \(Int(recipe.confidence * 100))%")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                // Done button
                Button(action: onDismiss) {
                    Text("Done")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding()
        }
    }
}

struct IngredientRow: View {
    let ingredient: IngredientResponse

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: categoryIcon(ingredient.category))
                .frame(width: 20)
                .foregroundStyle(.orange.opacity(0.8))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if let qty = ingredient.quantity {
                        Text(qty)
                            .fontWeight(.medium)
                    }
                    if let unit = ingredient.unit {
                        Text(unit)
                            .foregroundStyle(.secondary)
                    }
                    Text(ingredient.canonicalName)
                }
                .font(.subheadline)

                if ingredient.rawText.lowercased() != ingredient.canonicalName.lowercased() {
                    Text(ingredient.rawText)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
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
