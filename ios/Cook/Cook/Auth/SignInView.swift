import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var isSigningIn = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Branding
            VStack(spacing: 12) {
                Image(systemName: "basket.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.orange)

                Text("Cook")
                    .font(.system(size: 42, weight: .bold, design: .rounded))

                Text("Your inventory-aware\ngrocery assistant")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Sign-in button
            VStack(spacing: 16) {
                Button {
                    Task { await signIn() }
                } label: {
                    HStack(spacing: 10) {
                        if isSigningIn {
                            ProgressView()
                                .tint(.primary)
                        } else {
                            // Google "G" using SF Symbol approximation
                            Image(systemName: "globe")
                                .font(.body.weight(.medium))
                        }
                        Text("Continue with Google")
                            .font(.body.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                }
                .disabled(isSigningIn)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private func signIn() async {
        isSigningIn = true
        errorMessage = nil
        do {
            try await auth.signInWithGoogle()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSigningIn = false
    }
}
