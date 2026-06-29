import SwiftUI

struct OfflineBannerView: View {
    let lastUpdated: Date?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("No Internet Connection")
                    .font(.footnote.bold())
                if let date = lastUpdated {
                    Text("Last updated \(date.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.red.opacity(0.15))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.red.opacity(0.4)),
            alignment: .bottom
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(offlineBannerAccessibilityLabel)
    }

    private var offlineBannerAccessibilityLabel: String {
        if let date = lastUpdated {
            return "No Internet Connection. Last updated \(date.formatted(.relative(presentation: .named)))."
        }
        return "No Internet Connection."
    }
}

#Preview {
    VStack(spacing: 0) {
        OfflineBannerView(lastUpdated: Date())
        Spacer()
    }
}
