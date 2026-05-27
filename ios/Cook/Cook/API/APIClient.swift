import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthenticated
    case serverError(Int, String)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:                         return "Invalid URL"
        case .unauthenticated:                    return "Not signed in"
        case .serverError(let code, let msg):     return "Server error \(code): \(msg)"
        case .decodingError(let e):               return "Could not read response: \(e.localizedDescription)"
        }
    }
}

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let base = Config.baseURL

    // MARK: - Recipes

    func getRecipes() async throws -> [RecipeListItem] {
        let req = try makeRequest(path: "/recipes")
        return try await send(req, as: [RecipeListItem].self)
    }

    func getRecipe(id: String) async throws -> RecipeDetail {
        let req = try makeRequest(path: "/recipes/\(id)")
        return try await send(req, as: RecipeDetail.self)
    }

    func deleteRecipe(id: String) async throws {
        var req = try makeRequest(path: "/recipes/\(id)")
        req.httpMethod = "DELETE"
        let (_, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw APIError.serverError(http.statusCode, "Delete failed")
        }
    }

    // MARK: - Ingest

    func ingestLink(url: String) async throws -> IngestResponse {
        var req = try makeRequest(path: "/ingest/link")
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 60  // LLM extraction takes a moment
        req.httpBody = try JSONEncoder().encode(["url": url])
        return try await send(req, as: IngestResponse.self)
    }

    // MARK: - Helpers

    private func makeRequest(path: String) throws -> URLRequest {
        guard let url = URL(string: base + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        // Attach Supabase JWT — token is stored in the shared App Group by AuthManager
        if let token = AuthManager.shared.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    private func send<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.serverError(http.statusCode, body)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
