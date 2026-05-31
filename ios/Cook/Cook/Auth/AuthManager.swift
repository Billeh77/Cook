import Foundation
internal import Combine
import Supabase

/// Central auth state. Owned by CookApp, injected as @EnvironmentObject.
/// Also writes the current access token to the shared App Group so the
/// Share Extension can attach it to API requests without importing Supabase.
@MainActor
final class AuthManager: ObservableObject {

    static let shared = AuthManager()

    // MARK: - Supabase client (shared across the whole app)

    let supabase = SupabaseClient(
        supabaseURL: URL(string: "https://nammoajmiidvrqjkvlzn.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5hbW1vYWptaWlkdnJxamt2bHpuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk4MjQ1NTMsImV4cCI6MjA5NTQwMDU1M30.-bovz3nWtvgDRWjr3BH3iHZSC022uUZ-scE_VKJGzJc"
    )

    // MARK: - Published state

    @Published var isAuthenticated = false
    @Published var isLoading = true          // true until first auth event fires

    // MARK: - App Group shared storage (read by Share Extension)

    private let appGroup = UserDefaults(suiteName: "group.com.Emile.Cook")!
    private static let tokenKey = "supabase_access_token"

    // MARK: - Init

    private init() {
        Task { await startListening() }
    }

    // MARK: - Auth state listener

    private func startListening() async {
        for await (event, session) in supabase.auth.authStateChanges {
            switch event {
            case .initialSession, .signedIn, .tokenRefreshed:
                isAuthenticated = session != nil
                appGroup.set(session?.accessToken, forKey: Self.tokenKey)
            case .signedOut, .userDeleted:
                isAuthenticated = false
                appGroup.removeObject(forKey: Self.tokenKey)
            default:
                break
            }
            isLoading = false
        }
    }

    // MARK: - Actions

    func signInWithGoogle() async throws {
        try await supabase.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "cook://login-callback")
        )
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
    }

    /// Called from CookApp.onOpenURL to complete the OAuth redirect.
    func handleDeepLink(_ url: URL) {
        Task {
            try? await supabase.auth.session(from: url)
        }
    }

    // MARK: - Token access (for APIClient)

    var accessToken: String? {
        appGroup.string(forKey: Self.tokenKey)
    }

    // MARK: - User info

    /// First name extracted from Google OAuth metadata, or email prefix as fallback.
    var firstName: String {
        if let meta = supabase.auth.currentUser?.userMetadata {
            // Google sends "full_name" or "name"
            for key in ["full_name", "name"] {
                if let raw = meta[key],
                   case let .string(name) = raw,
                   !name.isEmpty {
                    return name.components(separatedBy: " ").first ?? name
                }
            }
        }
        if let email = supabase.auth.currentUser?.email {
            return email.components(separatedBy: "@").first?.capitalized ?? "Chef"
        }
        return "Chef"
    }

    /// Google avatar URL from OAuth metadata, if available.
    var avatarURL: URL? {
        if let meta = supabase.auth.currentUser?.userMetadata,
           let raw = meta["avatar_url"],
           case let .string(urlStr) = raw,
           let url = URL(string: urlStr) {
            return url
        }
        return nil
    }
}
