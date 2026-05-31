import SwiftUI

// MARK: - Main detail view

struct RecipeDetailView: View {
    let recipeId: String
    let recipeTitle: String
    /// Canonical names of ingredients not in the user's pantry.
    /// Passed from CanCookView; empty when opened from Saved tab.
    var missingIngredients: [String] = []

    @State private var recipe: RecipeDetail?
    @State private var isLoading = true
    @State private var error: String?
    @State private var isFavorited = false
    @State private var showGroceryToast = false
    @Environment(\.dismiss) private var dismiss

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
                RecipeDetailContent(
                    recipe: recipe,
                    missingIngredients: missingIngredients,
                    isFavorited: isFavorited,
                    onToggleFavorite: { toggleFavorite() },
                    onDelete: { deleteRecipe() },
                    onAddToGroceries: missingIngredients.isEmpty ? nil : { Task { await addToGroceries() } }
                )
            }
        }
        .navigationTitle(recipeTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .overlay(alignment: .bottom) {
            if showGroceryToast {
                HStack(spacing: 8) {
                    Image(systemName: "cart.badge.checkmark")
                        .font(.subheadline.weight(.semibold))
                    Text("Missing items added to grocery list")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.green.opacity(0.92), in: Capsule())
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                .padding(.bottom, 28)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: showGroceryToast)
    }

    private func load() async {
        isLoading = true
        do {
            let r = try await APIClient.shared.getRecipe(id: recipeId)
            recipe = r
            isFavorited = r.isFavorited
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func toggleFavorite() {
        isFavorited.toggle()
        Task {
            do {
                try await APIClient.shared.setFavorite(id: recipeId, isFavorited: isFavorited)
            } catch {
                isFavorited.toggle() // revert on failure
            }
        }
    }

    private func deleteRecipe() {
        Task {
            try? await APIClient.shared.deleteRecipe(id: recipeId)
            dismiss()
        }
    }

    private func addToGroceries() async {
        _ = try? await APIClient.shared.generateGroceryList(recipeIds: [recipeId])
        withAnimation { showGroceryToast = true }
        try? await Task.sleep(for: .seconds(2))
        withAnimation { showGroceryToast = false }
    }
}

// MARK: - Scrollable content

private struct RecipeDetailContent: View {
    let recipe: RecipeDetail
    let missingIngredients: [String]
    let isFavorited: Bool
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void
    let onAddToGroceries: (() -> Void)?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {

                VideoThumbnailCard(
                    recipe: recipe,
                    isFavorited: isFavorited,
                    onToggleFavorite: onToggleFavorite,
                    onDelete: onDelete,
                    onAddToGroceries: onAddToGroceries
                )

                // Tags strip
                if hasTags {
                    TagFlow(spacing: 6) {
                        if let effort = recipe.effort { TagChip(effortTag: effort) }
                        if let mins = recipe.timeMinutes {
                            TagChip(text: timeLabel(mins), icon: "clock", color: .blue)
                        }
                        if let servings = recipe.servings {
                            TagChip(
                                text: "\(servings) serving\(servings == 1 ? "" : "s")",
                                icon: "person.2",
                                color: .purple
                            )
                        }
                        if let protein = recipe.proteinLevel, protein == "high" {
                            TagChip(text: "High protein", icon: "bolt.fill", color: .green)
                        }
                        if let cal = recipe.calorieLevel { TagChip(calorieTag: cal) }
                        if let src = recipe.proteinSource { TagChip(proteinSourceTag: src) }
                    }
                }

                // Missing ingredients summary (only when we have that info)
                if !missingIngredients.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "cart.badge.plus")
                            .foregroundStyle(.orange)
                        Text("Missing \(missingIngredients.count) ingredient\(missingIngredients.count == 1 ? "" : "s")")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.orange)
                    }
                }

                // Ingredients
                if !recipe.ingredients.isEmpty {
                    SectionCard(title: "Ingredients", icon: "cart") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(recipe.ingredients) { ing in
                                let isMissing = missingIngredients.contains(
                                    where: { $0.lowercased() == ing.canonicalName.lowercased() }
                                )
                                IngredientDetailRow(ingredient: ing, isMissing: isMissing)
                                if ing.id != recipe.ingredients.last?.id { Divider() }
                            }
                        }
                    }
                }

                // Steps
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

    private var hasTags: Bool {
        recipe.effort != nil || recipe.timeMinutes != nil || recipe.servings != nil
        || recipe.proteinLevel != nil || recipe.calorieLevel != nil || recipe.proteinSource != nil
    }

    private func timeLabel(_ mins: Int) -> String {
        mins < 60 ? "\(mins) min" : "\(mins / 60)h \(mins % 60 > 0 ? "\(mins % 60)m" : "")"
    }
}

// MARK: - Square thumbnail card with platform watch button + action buttons

private struct VideoThumbnailCard: View {
    let recipe: RecipeDetail
    let isFavorited: Bool
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void
    let onAddToGroceries: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let creator = recipe.creatorName {
                Label(creator, systemImage: "person.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }

            Rectangle()
                .aspectRatio(1, contentMode: .fit)
                .overlay(thumbnailContent)
                .clipped()
                // Watch button — bottom right
                .overlay(alignment: .bottomTrailing) {
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
                // Action buttons — bottom left
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: 10) {
                        CardActionButton(
                            systemImage: isFavorited ? "heart.fill" : "heart",
                            color: isFavorited ? .red : .white,
                            action: onToggleFavorite
                        )
                        if let onCart = onAddToGroceries {
                            CardActionButton(systemImage: "cart.badge.plus", action: onCart)
                        }
                        CardActionButton(systemImage: "trash", action: onDelete)
                    }
                    .padding(10)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        if let urlStr = recipe.thumbnailURL, let url = URL(string: urlStr) {
            CachedAsyncImage(url: url) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Color(.systemGray5)
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
    var isMissing: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: categoryIcon(ingredient.category))
                .frame(width: 20)
                .foregroundStyle(isMissing ? .orange : .orange.opacity(0.8))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if let qty = ingredient.quantity {
                        Text(qty).fontWeight(.medium)
                    }
                    if let unit = ingredient.unit {
                        Text(unit).foregroundStyle(.secondary)
                    }
                    Text(ingredient.canonicalName).fontWeight(.medium)

                    if isMissing {
                        Text("missing")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red, in: Capsule())
                    }
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
