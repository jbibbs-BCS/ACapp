import SwiftUI

struct LoadStateView<T, Content: View>: View {
    let state: LoadState<T>
    let content: (T) -> Content
    let retry: () -> Void

    var body: some View {
        switch state {
        case .idle:
            Color.clear

        case .loading:
            VStack {
                Spacer()
                ProgressView()
                    .controlSize(.large)
                Spacer()
            }

        case .loaded(let value):
            content(value)

        case .error(let error):
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(error.userMessage)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                Button("Try Again", action: retry)
                    .buttonStyle(.bordered)
                Spacer()
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        LoadStateView(
            state: LoadState<String>.loading,
            content: { Text($0) },
            retry: {}
        )
        LoadStateView(
            state: LoadState<String>.error(.networkError),
            content: { Text($0) },
            retry: {}
        )
        LoadStateView(
            state: LoadState<String>.loaded("Content here"),
            content: { Text($0) },
            retry: {}
        )
    }
}
