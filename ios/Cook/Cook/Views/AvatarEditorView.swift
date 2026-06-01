import SwiftUI
import PhotosUI

// MARK: - Style options

private struct AvatarStyle: Identifiable {
    let id: String       // value sent to the API
    let label: String
    let emoji: String
}

private let avatarStyles: [AvatarStyle] = [
    AvatarStyle(id: "Clay",       label: "Clay",       emoji: "🧸"),
    AvatarStyle(id: "Toy",        label: "Toy",        emoji: "🪆"),
    AvatarStyle(id: "Video game", label: "Video Game", emoji: "🎮"),
    AvatarStyle(id: "3D",         label: "3D",         emoji: "✨"),
    AvatarStyle(id: "Pixels",     label: "Pixel Art",  emoji: "🕹️"),
    AvatarStyle(id: "Emoji",      label: "Emoji",      emoji: "😊"),
]

// MARK: - Avatar editor sheet

struct AvatarEditorView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    // Photo picker
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showCamera = false

    // Style selection
    @State private var selectedStyle = "Clay"

    // Generation state
    @State private var isGenerating = false
    @State private var generatedURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {

                    // ── Current / generated avatar ─────────────────────────
                    avatarDisplay
                        .padding(.top, 24)

                    // ── Style picker ──────────────────────────────────────
                    if !isGenerating {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Avatar Style")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 24)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(avatarStyles) { style in
                                        Button {
                                            selectedStyle = style.id
                                            // Clear previous result if style changes
                                            generatedURL = nil
                                            errorMessage = nil
                                        } label: {
                                            VStack(spacing: 5) {
                                                Text(style.emoji)
                                                    .font(.title2)
                                                Text(style.label)
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(selectedStyle == style.id ? .white : .primary)
                                            }
                                            .frame(width: 72, height: 64)
                                            .background(
                                                selectedStyle == style.id
                                                    ? Color.orange
                                                    : Color(.secondarySystemGroupedBackground)
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .stroke(selectedStyle == style.id ? Color.clear : Color(.separator).opacity(0.5), lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    // ── Action buttons ────────────────────────────────────
                    if !isGenerating {
                        VStack(spacing: 12) {
                            PhotosPicker(
                                selection: $selectedPhotoItem,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Label("Choose from Library", systemImage: "photo.on.rectangle")
                                    .font(.body.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            Button {
                                showCamera = true
                            } label: {
                                Label("Take a Selfie", systemImage: "camera.fill")
                                    .font(.body.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 24)
                    }

                    // ── Generating indicator ──────────────────────────────
                    if isGenerating {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.4)
                                .tint(.orange)
                            Text("Creating your chef avatar…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("This usually takes 20–40 seconds")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 16)
                    }

                    // ── Error ─────────────────────────────────────────────
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Chef Avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            // Photo picker selection handler
            .onChange(of: selectedPhotoItem) { _, item in
                guard let item else { return }
                Task { await loadAndGenerate(from: item) }
            }
            // Camera
            .fullScreenCover(isPresented: $showCamera) {
                CameraPickerView { image in
                    showCamera = false
                    if let jpeg = image.jpegData(compressionQuality: 0.85) {
                        Task { await generate(imageData: jpeg) }
                    }
                }
                .ignoresSafeArea()
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Avatar display

    @ViewBuilder
    private var avatarDisplay: some View {
        let displayURL = generatedURL ?? auth.avatarURL

        ZStack(alignment: .bottomTrailing) {
            Group {
                if let url = displayURL {
                    CachedAsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        chefPlaceholder
                    }
                } else {
                    chefPlaceholder
                }
            }
            .frame(width: 160, height: 160)
            .clipShape(Circle())
            .overlay(Circle().stroke(.orange.opacity(0.35), lineWidth: 3))
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)

            if generatedURL != nil {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.green)
                    .background(Circle().fill(.background).padding(3))
                    .offset(x: 4, y: 4)
            }
        }

        if generatedURL != nil {
            Text("Your new chef avatar is ready!")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.green)
        } else {
            Text("Pick a style, then upload a photo\nto generate your AI chef avatar")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var chefPlaceholder: some View {
        ZStack {
            Color.orange.opacity(0.1)
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.orange.opacity(0.4))
        }
    }

    // MARK: - Generation

    private func loadAndGenerate(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            errorMessage = "Couldn't load the selected photo."
            return
        }
        guard let uiImage = UIImage(data: data),
              let jpeg = uiImage.jpegData(compressionQuality: 0.85) else {
            errorMessage = "Couldn't process the selected image."
            return
        }
        await generate(imageData: jpeg)
    }

    private func generate(imageData: Data) async {
        isGenerating = true
        errorMessage = nil
        generatedURL = nil

        do {
            let url = try await APIClient.shared.generateAvatar(imageData: imageData, style: selectedStyle)
            generatedURL = url
            auth.setCustomAvatarURL(url)
            Task { await auth.refreshSession() }
        } catch {
            errorMessage = "Generation failed: \(error.localizedDescription)\nPlease try again."
        }

        isGenerating = false
    }
}

// MARK: - Camera picker (UIImagePickerController wrapper)

private struct CameraPickerView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.cameraDevice = .front
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
