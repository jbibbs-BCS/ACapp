import SwiftUI

struct HealthBadgeView: View {
    let level: HealthLevel

    var body: some View {
        Image(systemName: level.systemImage)
            .foregroundStyle(Color.healthColor(for: level))
            .imageScale(.medium)
            .accessibilityLabel("Health: \(level.accessibilityLabel)")
    }
}

#Preview {
    HStack(spacing: 16) {
        HealthBadgeView(level: .good)
        HealthBadgeView(level: .warning)
        HealthBadgeView(level: .critical)
    }
    .padding()
}
