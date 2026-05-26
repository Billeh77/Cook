import SwiftUI
internal import Combine

struct LoadingView: View {
    @State private var dots = ""
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.6)
                .tint(.orange)

            Text("Extracting recipe\(dots)")
                .font(.headline)
                .foregroundStyle(.secondary)
                .animation(nil, value: dots)
        }
        .onReceive(timer) { _ in
            dots = dots.count < 3 ? dots + "." : ""
        }
    }
}
