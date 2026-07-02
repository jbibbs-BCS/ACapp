import SwiftUI

struct AlertSeverityBadgeView: View {
    let severity: AlertSeverity

    var body: some View {
        Text(severity.rawValue)
            .font(.caption.weight(.semibold))
            .foregroundStyle(severity.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(severity.color.opacity(0.12), in: Capsule())
            .accessibilityHidden(true) // parent row provides combined accessibility label
    }
}

#Preview {
    HStack(spacing: 10) {
        AlertSeverityBadgeView(severity: .critical)
        AlertSeverityBadgeView(severity: .major)
        AlertSeverityBadgeView(severity: .minor)
        AlertSeverityBadgeView(severity: .info)
    }
    .padding()
}
