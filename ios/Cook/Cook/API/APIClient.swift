import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case serverError(Int, String)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:           return "Invalid URL"
        case .serverError(let code, let msg): return "Server error \(code): \(msg)"
        case .decodingError(let e): return "Could not read response: \(e.localizedDescription)"
        }
    }
}

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let base = Config.baseURL

    // MARK: - Recipes

    func getRecipes() async throws -> [RecipeListItem] {
        let endpoint = try makeURL("/recipes")
        let req = URLRequest(url: endpoint)
        return try await send(req, as: [RecipeListItem].self)
    }

    func getRecipe(id: String) async throws -> RecipeDetail {
        let endpoint = try makeURL("/recipes/\(id)")
        let req = URLRequest(url: endpoint)
        return try await send(req, as: RecipeDetail.self)
    }

    func deleteRecipe(id: String) async throws {
        let endpoint = try makeURL("/recipes/\(id)")
        var req = URLRequest(url: endpoint)
        req.httpMethod = "DELETE"
        let (_, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw APIError.serverError(http.statusCode, "Delete failed")
        }
    }

    // MARK: - Ingest

    func ingestLink(url: String) async throws -> IngestResponse {
        let endpoint = try makeURL("/ingest/link")
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 45   // LLM extraction takes a moment
        req.httpBody = try JSONEncoder().encode(["url": url])

        return try await send(req, as: IngestResponse.self)
    }

    // MARK: - Helpers

    private func makeURL(_ path: String) throws -> URL {
        guard let url = URL(string: base + path) else { throw APIError.invalidURL }
        return url
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
