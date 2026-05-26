import Foundation

// Self-contained API client for the Share Extension.
// Cannot share code with the main app target without a framework,
// so we keep this minimal and independent.

private let backendBaseURL = "http://192.168.1.22:8000"

struct ExtensionRecipeResult {
    let dishName: String
    let ingredientCount: Int
}

enum ExtensionAPIError: Error {
    case badURL
    case httpError(Int)
    case noRecipeFound
}

func ingestLinkInExtension(urlString: String) async throws -> ExtensionRecipeResult {
    guard let endpoint = URL(string: "\(backendBaseURL)/ingest/link") else {
        throw ExtensionAPIError.badURL
    }

    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 60  // Claude extraction takes a moment

    struct Body: Encodable { let url: String }
    request.httpBody = try JSONEncoder().encode(Body(url: urlString))

    let (data, response) = try await URLSession.shared.data(for: request)

    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
        throw ExtensionAPIError.httpError(http.statusCode)
    }

    // Parse just what we need to show in the card
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
