import Foundation

// Self-contained API client for the Share Extension.
// Cannot import the main app target, so we read the auth token from the
// shared App Group UserDefaults that AuthManager writes to on every refresh.
//
// Token refresh: Supabase access tokens expire after 1 hour. The extension
// therefore stores the refresh token too, and uses a try → 401 → refresh → retry
// pattern so sharing works even if the app hasn't been opened recently.

private let backendBaseURL = "https://cook-backend-production-17b1.up.railway.app"
private let appGroupID     = "group.com.Emile.Cook"
private let tokenKey       = "supabase_access_token"
private let refreshTokenKey = "supabase_refresh_token"

// Supabase project constants (anon key is public by design — not a secret)
private let supabaseURL     = "https://nammoajmiidvrqjkvlzn.supabase.co"
private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5hbW1vYWptaWlkdnJxamt2bHpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk4MjQ1NTMsImV4cCI6MjA5NTQwMDU1M30.-bovz3nWtvgDRWjr3BH3iHZSC022uUZ-scE_VKJGzJc"

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

// MARK: - Public entry point

func ingestLinkInExtension(urlString: String) async throws -> ExtensionRecipeResult {
    // Try with whatever token is currently stored. If the backend returns 401
    // (token expired), refresh and retry once.
    do {
        return try await _callBackend(urlString: urlString)
    } catch ExtensionAPIError.httpError(401) {
        try await _refreshStoredToken()
        return try await _callBackend(urlString: urlString)
    }
}

// MARK: - Backend call

private func _callBackend(urlString: String) async throws -> ExtensionRecipeResult {
    guard let endpoint = URL(string: "\(backendBaseURL)/ingest/link") else {
        throw ExtensionAPIError.badURL
    }

    let defaults = UserDefaults(suiteName: appGroupID)
    guard let token = defaults?.string(forKey: tokenKey), !token.isEmpty else {
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

    if let http = response as? HTTPURLResponse {
        guard (200...299).contains(http.statusCode) else {
            throw ExtensionAPIError.httpError(http.statusCode)
        }
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

// MARK: - Token refresh

/// Calls Supabase's token endpoint with the stored refresh token and writes
/// the new access token (and refresh token) back into the shared App Group.
private func _refreshStoredToken() async throws {
    let defaults = UserDefaults(suiteName: appGroupID)

    guard let refreshToken = defaults?.string(forKey: refreshTokenKey),
          !refreshToken.isEmpty else {
        // No refresh token stored — user must open the app to re-authenticate
        throw ExtensionAPIError.unauthenticated
    }

    guard let url = URL(string: "\(supabaseURL)/auth/v1/token?grant_type=refresh_token") else {
        throw ExtensionAPIError.badURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
    request.timeoutInterval = 15

    struct RefreshBody: Encodable { let refresh_token: String }
    request.httpBody = try JSONEncoder().encode(RefreshBody(refresh_token: refreshToken))

    let (data, response) = try await URLSession.shared.data(for: request)

    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
        throw ExtensionAPIError.unauthenticated
    }

    struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String
    }

    let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

    // Persist the fresh tokens so the main app also picks them up on next launch
    defaults?.set(tokenResponse.access_token,  forKey: tokenKey)
    defaults?.set(tokenResponse.refresh_token, forKey: refreshTokenKey)
}
