import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text("Share a recipe video")
                    .font(.title2.bold())
                Text("Open TikTok or Instagram, tap Share,\nand choose Cook.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Hint
            Label("Works with TikTok links", systemImage: "checkmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)
        }
        .padding()
    }
}
