import SwiftUI
internal import Combine

/// Single source of truth for cookability data, planned meal IDs, and cooking history.
/// Injected at the root and consumed by both CanCookView and MealPlannerView so both
/// views always agree on missing ingredient counts.
final class RecipeStore: ObservableObject {

    // MARK: - Published state

    @Published var cookabilityItems: [CookabilityItem] = []
    @Published var plannedRecipeIds: Set<String> = []
    @Published var history: [CookingLogEntry] = []

    // Pagination for cooking history
    @Published var historyHasMore: Bool = false
    @Published var historyDaysLoaded: Int = 7
    @Published var historyIsLoadingMore: Bool = false

    // MARK: - Derived

    /// Planned recipes backed by the authoritative cookability data.
    /// missingCount / missingIngredients are always correct here.
    var plannedItems: [CookabilityItem] {
        cookabilityItems.filter { plannedRecipeIds.contains($0.id) }
    }

    // MARK: - Load

    @MainActor
    func load() async {
        // Reset to first page on a fresh full load (pull-to-refresh)
        historyDaysLoaded = 7
        async let c = try? APIClient.shared.getCookability()
        async let p = try? APIClient.shared.getPlannedMeals()
        async let h = try? APIClient.shared.getCookingHistory(days: 7)
        if let items   = await c { cookabilityItems = items }
        if let planned = await p { plannedRecipeIds = Set(planned.map { $0.recipeId }) }
        if let page    = await h {
            history = page.entries
            historyHasMore = page.hasMore
        }
    }

    @MainActor
    func reloadCookability() async {
        if let items = try? await APIClient.shared.getCookability() {
            cookabilityItems = items
        }
    }

    @MainActor
    func reloadHistory() async {
        if let page = try? await APIClient.shared.getCookingHistory(days: historyDaysLoaded) {
            history = page.entries
            historyHasMore = page.hasMore
        }
    }

    /// Loads the next 3 weeks of history on top of whatever is already loaded.
    @MainActor
    func loadMoreHistory() async {
        guard !historyIsLoadingMore else { return }
        historyIsLoadingMore = true
        historyDaysLoaded += 21
        if let page = try? await APIClient.shared.getCookingHistory(days: historyDaysLoaded) {
            history = page.entries
            historyHasMore = page.hasMore
        }
        historyIsLoadingMore = false
    }

    // MARK: - Planner mutations

    @MainActor
    func addToPlanner(id: String) async {
        try? await APIClient.shared.addToPlanner(recipeId: id)
        plannedRecipeIds.insert(id)
    }

    @MainActor
    func removeFromPlanner(id: String) async {
        try? await APIClient.shared.removeFromPlanner(recipeId: id)
        plannedRecipeIds.remove(id)
    }

    // MARK: - Cooking log

    /// Logs a cook, removes from planner, and prepends the new entry to history.
    @MainActor
    func markCooked(recipeId: String, servings: Int) async {
        plannedRecipeIds.remove(recipeId)
        if let entry = try? await APIClient.shared.logCooked(recipeId: recipeId, servings: servings) {
            history.insert(entry, at: 0)
        } else {
            // API failed — re-sync planned IDs to reflect true server state
            if let p = try? await APIClient.shared.getPlannedMeals() {
                plannedRecipeIds = Set(p.map { $0.recipeId })
            }
        }
    }

    /// Logs a cook directly (from the history "+" button), without removing from planner.
    @MainActor
    func logDirectly(recipeId: String, servings: Int) async {
        if let entry = try? await APIClient.shared.logCooked(recipeId: recipeId, servings: servings) {
            history.insert(entry, at: 0)
            plannedRecipeIds.remove(recipeId)
        }
    }
}
