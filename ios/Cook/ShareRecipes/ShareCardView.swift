import SwiftUI

struct ShareCardView: View {
    let urlString: String?
    let onDismiss: () -> Void

    @State private var phase: Phase = .loading

    enum Phase {
        case loading
        case success(dishName: String, ingredientCount: Int)
        case failure(String)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.01).ignoresSafeArea()

            VStack(spacing: 18) {
                // Branding
                HStack(spacing: 10) {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.orange)
                    Text("Cook")
                        .font(.title2.bold())
                }

                Divider()

                Group {
                    switch phase {
                    case .loading:
                        ProgressView().scaleEffect(1.3).tint(.orange)
                        Text("Extracting recipe…")
                            .foregroundStyle(.secondary)

                    case .success(let dish, let count):
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.green)
                        Text(dish)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        Text("\(count) ingredient\(count == 1 ? "" : "s") saved")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                    case .failure(let msg):
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.red)
                        Text("Couldn't save recipe")
                            .font(.headline)
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            .padding(28)
            .frame(maxWidth: 320)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 24, y: 8)
        }
        .task {
            await process()
        }
    }

    private func process() async {
        guard let urlString else {
            withAnimation { phase = .failure("No link found. Share a TikTok or Instagram video.") }
            await autoDismiss()
            return
        }

        do {
            let result = try await ingestLinkInExtension(urlString: urlString)
            withAnimation(.spring(duration: 0.4)) {
                phase = .success(dishName: result.dishName, ingredientCount: result.ingredientCount)
            }
        } catch {
            let message: String
            switch error as? ExtensionAPIError {
            case .noRecipeFound:
                message = "No recipe detected in this video."
            case .unauthenticated:
                message = "Please open the Cook app and sign in, then try again."
            case .httpError(401):
                message = "Session expired. Open the Cook app to refresh, then try again."
            case .httpError(let c):
                message = "Server error \(c). Please try again in a moment."
            default:
                message = "Couldn't reach the server. Check your internet connection."
            }
            withAnimation(.spring(duration: 0.4)) {
                phase = .failure(message)
            }
        }

        await autoDismiss()
    }

    private func autoDismiss() async {
        try? await Task.sleep(for: .seconds(2.5))
        onDismiss()
    }
}
