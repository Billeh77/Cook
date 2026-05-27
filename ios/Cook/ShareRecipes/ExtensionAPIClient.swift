import Foundation

// Self-contained API client for the Share Extension.
// Cannot import the main app target, so we read the auth token from the
// shared App Group UserDefaults that AuthManager writes to on every refresh.

private let backendBaseURL = "https://cook-backend-production-17b1.up.railway.app"
private let appGroupID     = "group.com.Emile.Cook"
private let tokenKey       = "supabase_access_token"

struct ExtensionRecipeResult {
    let dishName: String
    let ingredientCount: Int
}

enum ExtensionAPIError: Error {
    case badURL
    case unauthenticated
    case httpError(Int)
    case noRecipeFound
}

func ingestLinkInExtension(urlString: String) async throws -> ExtensionRecipeResult {
    guard let endpoint = URL(string: "\(backendBaseURL)/ingest/link") else {
        throw ExtensionAPIError.badURL
    }

    // Retrieve the JWT the main app stored in the shared App Group
    guard let token = UserDefaults(suiteName: appGroupID)?.string(forKey: tokenKey),
          !token.isEmpty else {
        throw ExtensionAPIError.unauthenticated
    }

    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.timeoutInterval = 60  // Claude extraction takes a moment

    struct Body: Encodable { let url: String }
    request.httpBody = try JSONEncoder().encode(Body(url: urlString))

    let (data, response) = try await URLSession.shared.data(for: request)

    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
        throw ExtensionAPIError.httpError(http.statusCode)
    }

    struct PartialResponse: Decodable {
        let status: String
        let dish_name: String?
        let ingredients: [EmptyDecodable]
        struct EmptyDecodable: Decodable {}
    }

    let parsed = try JSONDecoder().decode(PartialResponse.self, from: data)

    guard parsed.status == "success", let dishName = parsed.dish_name else {
        throw ExtensionAPIError.noRecipeFound
    }

    return ExtensionRecipeResult(
        dishName: dishName,
        ingredientCount: parsed.ingredients.count
    )
}
