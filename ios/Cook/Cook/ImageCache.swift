import UIKit

/// In-memory image cache backed by NSCache.
/// Automatically evicts entries under memory pressure.
final class ImageCache {
    static let shared = ImageCache()

    private let cache: NSCache<NSURL, UIImage> = {
        let c = NSCache<NSURL, UIImage>()
        c.countLimit = 150                      // max 150 images
        c.totalCostLimit = 75 * 1024 * 1024    // max ~75 MB
        return c
    }()

    private init() {}

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func store(_ image: UIImage, for url: URL) {
        // Cost = rough byte size (width × height × 4 RGBA channels)
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
}
