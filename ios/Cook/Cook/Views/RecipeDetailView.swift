import SwiftUI

// MARK: - Main detail view

struct RecipeDetailView: View {
    let recipeId: String
    let recipeTitle: String
    /// Canonical names of ingredients not in the user's pantry.
    /// Passed from CanCookView; empty when opened from Saved tab.
    var missingIngredients: [String] = []

    @EnvironmentObject var store: RecipeStore
    @State private var recipe: RecipeDetail?
    @State private var isLoading = true
    @State private var error: String?
    @State private var isFavorited = false
    @State private var showGroceryToast = false
    @State private var showCookPlanDialog = false
    @State private var showServingsSheet = false
    @State private var actionToastMessage: String?
    @Environment(\.dismiss) private var dismiss

    private var isPlanned: Bool {
        store.plannedRecipeIds.contains(recipeId)
    }

    /// Missing count from the store if available, otherwise fall back to what was passed in.
    private var missingCount: Int {
        store.cookabilityItems.first { $0.id == recipeId }?.missingCount
            ?? missingIngredients.count
    }

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
                    isPlanned: isPlanned,
                    onToggleFavorite: { toggleFavorite() },
                    onCookPlan: { showCookPlanDialog = true },
                    onAddToGroceries: missingIngredients.isEmpty ? nil : { Task { await addToGroceries() } }
                )
            }
        }
        .navigationTitle(recipeTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        // ── Cook / Plan dialog ─────────────────────────────────────────────────
        .confirmationDialog(
            recipeTitle,
            isPresented: $showCookPlanDialog,
            titleVisibility: .visible
        ) {
            if isPlanned {
                Button("Cook Now") { showServingsSheet = true }
                Button("Remove from Plan", role: .destructive) {
                    Task {
                        await store.removeFromPlanner(id: recipeId)
                        await showToast("Removed from your plan")
                    }
                }
            } else {
                Button("Cook Now") { showServingsSheet = true }
                Button("Add to Plan") {
                    Task {
                        await store.addToPlanner(id: recipeId)
                        if missingCount > 0 {
                            _ = try? await APIClient.shared.generateGroceryList(recipeIds: [recipeId])
                            await showToast("Added to plan · missing items → grocery list")
                        } else {
                            await showToast("Added to your meal plan")
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(isPlanned ? "This recipe is already in your plan." : "What would you like to do?")
        }
        // ── Servings sheet ─────────────────────────────────────────────────────
        .sheet(isPresented: $showServingsSheet) {
            DetailServingsSheet(mealName: recipeTitle) { servings in
                showServingsSheet = false
                Task {
                    await store.markCooked(recipeId: recipeId, servings: servings)
                    await showToast("Cooked! Added to your history 🎉")
                }
            }
        }
        // ── Toasts ─────────────────────────────────────────────────────────────
        .overlay(alignment: .bottom) {
            VStack(spacing: 10) {
                if let msg = actionToastMessage {
                    Text(msg)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(.orange.opacity(0.92), in: Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
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
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom, 28)
        }
        .animation(.spring(duration: 0.35), value: showGroceryToast)
        .animation(.spring(duration: 0.35), value: actionToastMessage)
    }

    // MARK: - Helpers

    @MainActor
    private func showToast(_ message: String) async {
        withAnimation { actionToastMessage = message }
        try? await Task.sleep(for: .seconds(2))
        withAnimation { actionToastMessage = nil }
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
                isFavorited.toggle()
            }
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
    let isPlanned: Bool
    let onToggleFavorite: () -> Void
    let onCookPlan: () -> Void
    let onAddToGroceries: (() -> Void)?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {

                VideoThumbnailCard(
                    recipe: recipe,
                    isFavorited: isFavorited,
                    isPlanned: isPlanned,
                    onToggleFavorite: onToggleFavorite,
                    onCookPlan: onCookPlan,
                    onAddToGroceries: onAddToGroceries
                )

                // Tags strip
                if hasTags {
                    TagFlow(spacing: 6) {
                        if let mt = recipe.mealType { TagChip(mealTypeTag: mt) }
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
                        if let src = recipe.proteinSource { TagChip(proteinSourceTag: src) }
                    }
                }

                // Missing ingredients summary
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
        recipe.mealType != nil || recipe.timeMinutes != nil || recipe.servings != nil
        || recipe.proteinLevel == "high" || recipe.proteinSource != nil
    }

    private func timeLabel(_ mins: Int) -> String {
        mins < 60 ? "\(mins) min" : "\(mins / 60)h \(mins % 60 > 0 ? "\(mins % 60)m" : "")"
    }
}

// MARK: - Thumbnail card with action buttons

private struct VideoThumbnailCard: View {
    let recipe: RecipeDetail
    let isFavorited: Bool
    let isPlanned: Bool
    let onToggleFavorite: () -> Void
    let onCookPlan: () -> Void
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
                // Watch button — bottom left
                .overlay(alignment: .bottomLeading) {
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
                // Action buttons — bottom right
                .overlay(alignment: .bottomTrailing) {
                    HStack(spacing: 10) {
                        // Favourite
                        CardActionButton(
                            systemImage: isFavorited ? "heart.fill" : "heart",
                            color: isFavorited ? .red : .white,
                            action: onToggleFavorite
                        )
                        // Add to grocery (only when ingredients are missing)
                        if let onCart = onAddToGroceries {
                            CardActionButton(systemImage: "cart.badge.plus", action: onCart)
                        }
                        // Cook / Plan — replaces trash
                        CardActionButton(
                            systemImage: isPlanned
                                ? "list.bullet.clipboard.fill"
                                : "list.bullet.clipboard",
                            color: isPlanned ? .orange : .white,
                            action: onCookPlan
                        )
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

// MARK: - Servings sheet (self-contained)

private struct DetailServingsSheet: View {
    let mealName: String
    let onConfirm: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var servings = 2

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Servings: \(servings)", value: $servings, in: 1...20)
                } header: {
                    Text(mealName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .textCase(nil)
                } footer: {
                    Text("Logged to your cooking history and weekly stats.")
                }
            }
            .navigationTitle("Mark as Cooked")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onConfirm(servings) }
                        .tint(.orange)
                }
            }
        }
        .presentationDetents([.medium])
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
