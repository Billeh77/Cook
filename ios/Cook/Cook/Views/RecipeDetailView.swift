import SwiftUI
import WebKit

// MARK: - Main detail view

struct RecipeDetailView: View {
    let recipeId: String
    let recipeTitle: String

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
                TikTokFullscreenView(url: url, isPresented: $showFullscreenVideo)
            }
        }
    }

    private func load() async {
        isLoading = true
        do { recipe = try await APIClient.shared.getRecipe(id: recipeId) }
        catch { self.error = error.localizedDescription }
        isLoading = false
    }
}

// MARK: - Scrollable content

private struct RecipeDetailContent: View {
    let recipe: RecipeDetail
    @Binding var showFullscreenVideo: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                TikTokThumbnailPlayer(recipe: recipe, showFullscreen: $showFullscreenVideo)

                if !recipe.ingredients.isEmpty {
                    SectionCard(title: "Ingredients", icon: "cart") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(recipe.ingredients) { ing in
                                IngredientDetailRow(ingredient: ing)
                                if ing.id != recipe.ingredients.last?.id { Divider() }
                            }
                        }
                    }
                }

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

// MARK: - Thumbnail player card

private struct TikTokThumbnailPlayer: View {
    let recipe: RecipeDetail
    @Binding var showFullscreen: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let creator = recipe.creatorName {
                Label(creator, systemImage: "person.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Tappable thumbnail — tap anywhere to go fullscreen
            Button { showFullscreen = true } label: {
                ZStack {
                    // Thumbnail image
                    Group {
                        if let urlStr = recipe.thumbnailURL, let url = URL(string: urlStr) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable().scaledToFill()
                                case .failure:
                                    thumbnailPlaceholder
                                default:
                                    thumbnailPlaceholder.overlay(ProgressView())
                                }
                            }
                        } else {
                            thumbnailPlaceholder
                        }
                    }
                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
                    .clipped()

                    // Dim overlay
                    Color.black.opacity(0.25)

                    // Play button
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 2)
                }
            }
            .buttonStyle(.plain)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var thumbnailPlaceholder: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .aspectRatio(9.0 / 16.0, contentMode: .fit)
            .overlay(
                Image(systemName: "film")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
            )
    }
}

// MARK: - Fullscreen TikTok player (real WKWebView, not Safari)

struct TikTokFullscreenView: View {
    let url: URL
    @Binding var isPresented: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            TikTokBrowserView(url: url)
                .ignoresSafeArea()

            Button { isPresented = false } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 34))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color(.systemGray2).opacity(0.7))
                    .shadow(radius: 4)
            }
            .padding(.top, 56)
            .padding(.leading, 16)
        }
        .background(.black)
    }
}

// MARK: - WKWebView that loads the real TikTok page

struct TikTokBrowserView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        // Mobile Safari UA so TikTok serves the mobile web player
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
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
                HStack(spacing: 4) {
                    if let qty = ingredient.quantity { Text(qty).fontWeight(.medium) }
                    if let unit = ingredient.unit { Text(unit).foregroundStyle(.secondary) }
                    Text(ingredient.canonicalName).fontWeight(.medium)
                }
                .font(.subheadline)

                if ingredient.rawText.lowercased() != ingredient.canonicalName.lowercased() {
                    Text(ingredient.rawText)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if let notes = ingredient.notes {
                    Text(notes).font(.caption).foregroundStyle(.secondary).italic()
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
