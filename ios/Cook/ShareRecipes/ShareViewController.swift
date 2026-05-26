import UIKit
import SwiftUI
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        extractSharedURL { [weak self] url in
            DispatchQueue.main.async { self?.presentCard(urlString: url?.absoluteString) }
        }
    }

    // MARK: - URL extraction

    private func extractSharedURL(completion: @escaping (URL?) -> Void) {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments else {
            completion(nil)
            return
        }

        // Try public.url first (TikTok, most apps)
        for provider in attachments where provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier) { value, _ in
                completion(value as? URL)
            }
            return
        }

        // Fallback: extract URL from plain text
        for provider in attachments where provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { value, _ in
                guard let text = value as? String else { completion(nil); return }
                completion(Self.firstURL(in: text))
            }
            return
        }

        completion(nil)
    }

    private static func firstURL(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        return detector.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))?.url
    }

    // MARK: - UI

    private func presentCard(urlString: String?) {
        let card = ShareCardView(urlString: urlString) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }

        let host = UIHostingController(rootView: card)
        host.view.backgroundColor = .clear
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)
    }
}
