import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthenticated
    case serverError(Int, String)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:                     return "Invalid URL"
        case .unauthenticated:                return "Not signed in"
        case .serverError(let code, let msg): return "Server error \(code): \(msg)"
        case .decodingError(let e):           return "Could not read response: \(e.localizedDescription)"
        }
    }
}

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let base = Config.baseURL

    // MARK: - Recipes

    func getRecipes() async throws -> [RecipeListItem] {
        try await send(makeRequest("/recipes"), as: [RecipeListItem].self)
    }

    func getRecipe(id: String) async throws -> RecipeDetail {
        try await send(makeRequest("/recipes/\(id)"), as: RecipeDetail.self)
    }

    func deleteRecipe(id: String) async throws {
        var req = makeRequest("/recipes/\(id)")
        req.httpMethod = "DELETE"
        _ = try await perform(req)
    }

    func setFavorite(id: String, isFavorited: Bool) async throws {
        var req = makeRequest("/recipes/\(id)/favorite")
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["is_favorited": isFavorited])
        _ = try await perform(req)
    }

    // MARK: - Ingest

    func ingestLink(url: String) async throws -> IngestResponse {
        var req = makeRequest("/ingest/link")
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 60
        req.httpBody = try JSONEncoder().encode(["url": url])
        return try await send(req, as: IngestResponse.self)
    }

    func getCookability() async throws -> [CookabilityItem] {
        try await send(makeRequest("/recipes/cookability"), as: [CookabilityItem].self)
    }

    // MARK: - Inventory

    func getInventory() async throws -> [InventoryItem] {
        try await send(makeRequest("/inventory"), as: [InventoryItem].self)
    }

    func addInventoryItem(name: String, status: String = "in_stock") async throws -> InventoryItem {
        var req = makeRequest("/inventory")
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["canonical_name": name, "status": status])
        return try await send(req, as: InventoryItem.self)
    }

    func updateInventoryItem(id: String, status: String) async throws -> InventoryItem {
        var req = makeRequest("/inventory/\(id)")
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["status": status])
        return try await send(req, as: InventoryItem.self)
    }

    func deleteInventoryItem(id: String) async throws {
        var req = makeRequest("/inventory/\(id)")
        req.httpMethod = "DELETE"
        _ = try await perform(req)
    }

    // MARK: - Grocery list

    func getGroceryList() async throws -> [GroceryListItem] {
        try await send(makeRequest("/grocery-list"), as: [GroceryListItem].self)
    }

    func generateGroceryList(recipeIds: [String]) async throws -> [GroceryListItem] {
        var req = makeRequest("/grocery-list/generate")
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["recipe_ids": recipeIds])
        return try await send(req, as: [GroceryListItem].self)
    }

    func checkGroceryItem(id: String, checked: Bool, updateInventory: Bool = true) async throws -> GroceryListItem {
        var req = makeRequest("/grocery-list/items/\(id)/check")
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["checked": checked, "update_inventory": updateInventory])
        return try await send(req, as: GroceryListItem.self)
    }

    func deleteGroceryItem(id: String) async throws {
        var req = makeRequest("/grocery-list/items/\(id)")
        req.httpMethod = "DELETE"
        _ = try await perform(req)
    }

    func clearCheckedGroceryItems() async throws {
        var req = makeRequest("/grocery-list")
        req.httpMethod = "DELETE"
        _ = try await perform(req)
    }

    // MARK: - Albums

    func getAlbums() async throws -> [AlbumItem] {
        try await send(makeRequest("/albums"), as: [AlbumItem].self)
    }

    func createAlbum(name: String) async throws -> AlbumItem {
        var req = makeRequest("/albums")
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["name": name])
        return try await send(req, as: AlbumItem.self)
    }

    func deleteAlbum(id: String) async throws {
        var req = makeRequest("/albums/\(id)")
        req.httpMethod = "DELETE"
        _ = try await perform(req)
    }

    func getAlbumRecipes(id: String) async throws -> [RecipeListItem] {
        try await send(makeRequest("/albums/\(id)/recipes"), as: [RecipeListItem].self)
    }

    func addRecipeToAlbum(albumId: String, recipeId: String) async throws {
        var req = makeRequest("/albums/\(albumId)/recipes/\(recipeId)")
        req.httpMethod = "POST"
        _ = try await perform(req)
    }

    func removeRecipeFromAlbum(albumId: String, recipeId: String) async throws {
        var req = makeRequest("/albums/\(albumId)/recipes/\(recipeId)")
        req.httpMethod = "DELETE"
        _ = try await perform(req)
    }

    // MARK: - Planner

    func getPlannedMeals() async throws -> [PlannedMealItem] {
        try await send(makeRequest("/planner"), as: [PlannedMealItem].self)
    }

    func addToPlanner(recipeId: String) async throws {
        var req = makeRequest("/planner/\(recipeId)")
        req.httpMethod = "POST"
        _ = try await perform(req)
    }

    func removeFromPlanner(recipeId: String) async throws {
        var req = makeRequest("/planner/\(recipeId)")
        req.httpMethod = "DELETE"
        _ = try await perform(req)
    }

    // MARK: - Cooking log

    func getCookingHistory() async throws -> [CookingLogEntry] {
        try await send(makeRequest("/cooking-log"), as: [CookingLogEntry].self)
    }

    func logCooked(recipeId: String, servings: Int) async throws -> CookingLogEntry {
        var req = makeRequest("/cooking-log/\(recipeId)")
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["servings": servings, "remove_from_planner": true])
        return try await send(req, as: CookingLogEntry.self)
    }

    // MARK: - Stats

    func getKitchenStats() async throws -> KitchenStats {
        try await send(makeRequest("/stats"), as: KitchenStats.self)
    }

    // MARK: - Helpers

    private func makeRequest(_ path: String) -> URLRequest {
        let url = URL(string: base + path)!
        var req = URLRequest(url: url)
        if let token = AuthManager.shared.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.serverError(http.statusCode, body)
        }
        return data
    }

    private func send<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let data = try await perform(request)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
