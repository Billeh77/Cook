import Foundation

enum Config {
    /// Backend base URL.
    /// - Local development (device on same WiFi): use your Mac's IP
    /// - Production: replace with your deployed URL
    static let baseURL = "https://cook-backend-production-17b1.up.railway.app"
}
