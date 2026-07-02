import SwiftUI

struct HealthBadgePillView: View {
    enum Size { case compact, standard }

    let size: Size
    let level: HealthLevel

    private var color: Color { Color.healthColor(for: level) }

    var body: some View {
        switch size {
        case .compact:  compactView
        case .standard: standardView
        }
    }

    private var compactView: some View {
        Image(systemName: level.systemImage)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 28, height: 28)
            .background(color.opacity(0.12), in: Circle())
            .accessibilityLabel("Health: \(level.accessibilityLabel)")
    }

    private var standardView: some View {
        Label(level.accessibilityLabel, systemImage: level.systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
            .accessibilityLabel("Health: \(level.accessibilityLabel)")
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            HealthBadgePillView(size: .standard, level: .good)
            HealthBadgePillView(size: .standard, level: .warning)
            HealthBadgePillView(size: .standard, level: .critical)
        }
        HStack(spacing: 12) {
            HealthBadgePillView(size: .compact, level: .good)
            HealthBadgePillView(size: .compact, level: .warning)
            HealthBadgePillView(size: .compact, level: .critical)
        }
    }
    .padding()
}
