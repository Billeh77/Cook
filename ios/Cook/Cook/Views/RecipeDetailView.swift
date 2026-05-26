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
    @State private var playerHeight: CGFloat = 300

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Creator
            if let creator = recipe.creatorName {
                Label(creator, systemImage: "person.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Embedded player or thumbnail fallback
            ZStack(alignment: .bottomTrailing) {
                if let html = recipe.embedHTML {
                    TikTokWebView(embedHTML: html, height: $playerHeight)
                        .frame(height: playerHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else if let urlStr = recipe.sourceURL, let url = URL(string: urlStr) {
                    // Fallback: link button when no embed HTML
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

                // Fullscreen button
                if recipe.sourceURL != nil {
                    Button {
                        showFullscreen = true
                    } label: {
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
}

// MARK: - WKWebView wrapper for TikTok embed

struct TikTokWebView: UIViewRepresentable {
    let embedHTML: String
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        let wrappedHTML = """
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
          <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { background: #000; display: flex; justify-content: center; align-items: flex-start; }
            .tiktok-embed { margin: 0 auto !important; }
          </style>
        </head>
        <body>
          \(embedHTML)
        </body>
        </html>
        """

        webView.loadHTMLString(wrappedHTML, baseURL: URL(string: "https://www.tiktok.com"))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: TikTokWebView
        init(_ parent: TikTokWebView) { self.parent = parent }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Read the content height after the TikTok embed script has run
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                webView.evaluateJavaScript("document.body.scrollHeight") { result, _ in
                    if let h = result as? CGFloat, h > 100 {
                        self.parent.height = min(h, 780)
                    }
                }
            }
        }
    }
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
