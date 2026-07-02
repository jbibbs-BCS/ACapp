import SwiftUI

struct DeviceStatusBadge: View {
    let status: DeviceStatus

    private var color: Color { status == .up ? .healthGood : .healthCritical }
    private var label: String { status == .up ? "Up" : "Down" }

    var body: some View {
        Text(label)
            .font(.system(.caption2).weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
            .accessibilityHidden(true) // parent row provides combined accessibility label
    }
}

#Preview {
    HStack(spacing: 10) {
        DeviceStatusBadge(status: .up)
        DeviceStatusBadge(status: .down)
    }
    .padding()
}
