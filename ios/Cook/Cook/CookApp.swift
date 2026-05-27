import SwiftUI

@main
struct CookApp: App {
    @ObservedObject private var auth = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isLoading {
                    // Brief loading state while Supabase restores the session
                    ProgressView()
                        .tint(.orange)
                } else if auth.isAuthenticated {
                    ContentView()
                } else {
                    SignInView()
                }
            }
            .environmentObject(auth)
            .onOpenURL { url in
                // Handles the cook://login-callback redirect after Google OAuth
                auth.handleDeepLink(url)
            }
        }
    }
}
