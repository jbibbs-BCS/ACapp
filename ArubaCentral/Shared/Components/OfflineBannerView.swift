import SwiftUI

struct OfflineBannerView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("No Internet Connection")
                    .font(.footnote.bold())
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemOrange).opacity(0.15))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color(.systemOrange).opacity(0.4)),
            alignment: .bottom
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(offlineBannerAccessibilityLabel)
    }

    private var offlineBannerAccessibilityLabel: String {
        return "No Internet Connection."
    }
}

#Preview {
    VStack(spacing: 0) {
        OfflineBannerView()
        Spacer()
    }
}
