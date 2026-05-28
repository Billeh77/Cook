import SwiftUI

/// Drop-in replacement for AsyncImage that caches downloads in ImageCache.
/// Each image URL is downloaded at most once per app session; subsequent
/// loads are served instantly from memory.
///
/// Usage mirrors AsyncImage:
///   CachedAsyncImage(url: url) { img in
///       img.resizable().scaledToFill()
///   } placeholder: {
///       Color(.systemGray5)
///   }
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @State private var uiImage: UIImage?

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let uiImage {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
            }
        }
        // Re-runs whenever the URL changes (e.g. list reuse)
        .task(id: url?.absoluteString) {
            await load()
        }
    }

    private func load() async {
        guard let url else { return }

        // Serve from cache instantly if available
        if let cached = ImageCache.shared.image(for: url) {
            uiImage = cached
            return
        }

        // Download and cache
        guard
            let (data, _) = try? await URLSession.shared.data(from: url),
            let img = UIImage(data: data)
        else { return }

        ImageCache.shared.store(img, for: url)
        uiImage = img
    }
}
