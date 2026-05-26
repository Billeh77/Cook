import Foundation

enum Config {
    /// Backend base URL.
    /// - Local development (device on same WiFi): use your Mac's IP
    /// - Production: replace with your deployed URL
    static let baseURL = "http://192.168.1.22:8000"
}
