import SwiftUI
import WebKit
import SafariServices

// MARK: - Main detail view

struct RecipeDetailView: View {
    let recipeId: String
    let recipeTitle: String  // shown immediately while loading

    @State private var recipe: RecipeDetail?
    @State private var isLoading = true
    @State private var error: String?
    @State private var showFullscreenVideo = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading…").tint(.orange)
            } else if let error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle).foregroundStyle(.red)
                    Text(error).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .padding()
            } else if let recipe {
                RecipeDetailContent(recipe: recipe, showFullscreenVideo: $showFullscreenVideo)
            }
        }
        .navigationTitle(recipeTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .fullScreenCover(isPresented: $showFullscreenVideo) {
            if let recipe, let urlStr = recipe.sourceURL, let url = URL(string: urlStr) {
                FullscreenVideoView(url: url, isPresented: $showFullscreenVideo)
            }
        }
    }

    private func load() async {
        isLoading = true
        do {
            recipe = try await APIClient.shared.getRecipe(id: recipeId)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Content (scrollable body)

private struct RecipeDetailContent: View {
    let recipe: RecipeDetail
    @Binding var showFullscreenVideo: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // ── Video player ──────────────────────────────────────────────
                TikTokPlayerSection(recipe: recipe, showFullscreen: $showFullscreenVideo)

                // ── Ingredients ───────────────────────────────────────────────
                if !recipe.ingredients.isEmpty {
                    SectionCard(title: "Ingredients", icon: "cart") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(recipe.ingredients) { ing in
                                IngredientDetailRow(ingredient: ing)
                                if ing.id != recipe.ingredients.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }

                // ── Instructions (optional) ───────────────────────────────────
                if !recipe.steps.isEmpty {
                    SectionCard(title: "Instructions", icon: "list.number") {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                        .frame(width: 28, height: 28)
                                        .background(.orange, in: Circle())
                                    Text(step)
                                        .font(.body)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }

                // ── Confidence badge ──────────────────────────────────────────
                HStack {
                    Spacer()
                    Text("Extraction confidence: \(Int(recipe.confidence * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                }
            }
            .padding()
        }
    }
}

// MARK: - TikTok player section

private struct TikTokPlayerSection: View {
    let recipe: RecipeDetail
    @Binding var showFullscreen: Bool

    // Fixed height: portrait 9:16 ratio capped so ingredients stay visible
    private let playerHeight: CGFloat = 500

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let creator = recipe.creatorName {
                Label(creator, systemImage: "person.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ZStack(alignment: .bottomTrailing) {
                if let videoID = tiktokVideoID() {
                    // Direct TikTok iframe — dark player, no white card
                    TikTokWebView(videoID: videoID)
                        .frame(height: playerHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else if let urlStr = recipe.sourceURL, let url = URL(string: urlStr) {
                    Link(destination: url) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.black)
                                .frame(height: 200)
                            VStack(spacing: 8) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.white)
                                Text("Watch on TikTok")
                                    .foregroundStyle(.white.opacity(0.8))
                                    .font(.subheadline)
                            }
                        }
                    }
                }

                if recipe.sourceURL != nil {
                    Button { showFullscreen = true } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.black.opacity(0.6), in: Circle())
                    }
                    .padding(10)
                }
            }
        }
    }

    /// Extracts the TikTok video ID, trying two sources in order:
    /// 1. The source URL path  (works for full tiktok.com/@user/video/ID URLs)
    /// 2. data-video-id attr in embed_html (works for all URLs incl. short vt.tiktok.com)
    private func tiktokVideoID() -> String? {
        // 1. Source URL
        if let urlString = recipe.sourceURL,
           let url = URL(string: urlString),
           url.host?.contains("tiktok.com") == true {
            let parts = url.pathComponents
            if let idx = parts.firstIndex(of: "video"), idx + 1 < parts.count {
                return parts[idx + 1]
            }
        }
        // 2. embed_html: look for data-video-id="7123456789"
        if let html = recipe.embedHTML,
           let start = html.range(of: "data-video-id=\"")?.upperBound,
           let end = html[start...].firstIndex(of: "\"") {
            return String(html[start..<end])
        }
        return nil
    }
}

// MARK: - WKWebView wrapper — loads TikTok's direct iframe player (dark, no card)

struct TikTokWebView: UIViewRepresentable {
    let videoID: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = true
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
          <style>
            * { margin: 0; padding: 0; }
            html, body { width: 100%; height: 100%; background: #000; overflow: hidden; }
            iframe { width: 100%; height: 100%; border: none; display: block; }
          </style>
        </head>
        <body>
          <iframe
            src="https://www.tiktok.com/embed/v2/\(videoID)?autoplay=1&loop=1&music_info=1&description=0"
            allow="autoplay; fullscreen; picture-in-picture"
            allowfullscreen>
          </iframe>
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: URL(string: "https://www.tiktok.com"))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}

// MARK: - Fullscreen video (SFSafariViewController)

struct FullscreenVideoView: UIViewControllerRepresentable {
    let url: URL
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, SFSafariViewControllerDelegate {
        var parent: FullscreenVideoView
        init(_ parent: FullscreenVideoView) { self.parent = parent }
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            parent.isPresented = false
        }
    }
}

// MARK: - Reusable section card

private struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.headline)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Ingredient row

private struct IngredientDetailRow: View {
    let ingredient: IngredientResponse

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: categoryIcon(ingredient.category))
                .frame(width: 20)
                .foregroundStyle(.orange.opacity(0.8))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                // Quantity + canonical name
                HStack(spacing: 4) {
                    if let qty = ingredient.quantity { Text(qty).fontWeight(.medium) }
                    if let unit = ingredient.unit { Text(unit).foregroundStyle(.secondary) }
                    Text(ingredient.canonicalName).fontWeight(.medium)
                }
                .font(.subheadline)

                // Raw text (original from caption)
                if ingredient.rawText.lowercased() != ingredient.canonicalName.lowercased() {
                    Text(ingredient.rawText)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                // Notes
                if let notes = ingredient.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }
        }
    }

    private func categoryIcon(_ category: String) -> String {
        switch category {
        case "produce":  return "leaf.fill"
        case "dairy":    return "drop.fill"
        case "meat":     return "flame.fill"
        case "pantry":   return "cabinet.fill"
        case "spice":    return "sparkles"
        case "grain":    return "circle.grid.2x2.fill"
        default:         return "circle.fill"
        }
    }
}
