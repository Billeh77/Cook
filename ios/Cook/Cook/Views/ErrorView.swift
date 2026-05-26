import SwiftUI

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.red.opacity(0.8))

            Text("Something went wrong")
                .font(.title3.bold())

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try again", action: onRetry)
                .buttonStyle(.borderedProminent)
                .tint(.orange)
        }
        .padding()
    }
}
