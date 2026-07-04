import SwiftUI

/// A single list row representing a switch stack as one logical device.
/// Shows the stack name, model, a member-count badge, and the aggregate status.
struct StackRowView: View {
    let stack: SwitchStack

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(stack.name)
                    .font(.headline)
                HStack(spacing: 8) {
                    Text("\(stack.model) · Stack")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    memberBadge
                }
            }
            Spacer()
            DeviceStatusBadge(status: stack.status)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stack.name), stack of \(stack.memberCount) switches, \(stack.status == .up ? "online" : (stack.status == .down ? "offline" : "unknown"))")
    }

    private var memberBadge: some View {
        Text("\(stack.memberCount) members")
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(.secondary.opacity(0.15), in: Capsule())
    }
}
