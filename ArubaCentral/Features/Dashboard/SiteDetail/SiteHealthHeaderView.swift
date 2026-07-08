import SwiftUI

struct SiteHealthHeaderView: View {
    let site: Site

    @Environment(\.colorScheme) private var colorScheme

    private var healthColor: Color { Color.healthColor(for: site.healthLevel) }
    private var downDeviceCount: Int { site.deviceCount - site.upDeviceCount }

    var body: some View {
        VStack(spacing: 12) {
            healthRing
            statRow
        }
        .padding(16)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.cardBorder, lineWidth: 0.5)
        )
        .shadow(
            color: colorScheme == .light ? .black.opacity(0.06) : .clear,
            radius: 8, x: 0, y: 2
        )
    }

    private var healthRing: some View {
        ZStack {
            Circle()
                .stroke(healthColor.opacity(0.2), lineWidth: 6)
            Circle()
                .trim(from: 0, to: CGFloat(site.healthPct) / 100.0)
                .stroke(healthColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(site.healthPct)%")
                    .font(.callout.bold())
                    .monospacedDigit()
                    .foregroundStyle(healthColor)
                Text("Health")
                    .font(.caption2.weight(.medium))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 64, height: 64)
    }

    private var statRow: some View {
        HStack(spacing: 8) {
            StatCardView(
                title: "Up Devices",
                value: "\(site.upDeviceCount)",
                systemImage: "checkmark.circle.fill",
                accentColor: .healthGood
            )
            StatCardView(
                title: "Down",
                value: "\(downDeviceCount)",
                systemImage: "xmark.circle.fill",
                accentColor: .healthCritical
            )
            StatCardView(
                title: "Clients",
                value: "\(site.clientCount)",
                systemImage: "person.2.fill",
                accentColor: .brandOrange
            )
        }
    }
}

#Preview {
    SiteHealthHeaderView(
        site: Site(id: "s1", name: "HQ Campus", healthPct: 74,
                   deviceCount: 12, clientCount: 87)
    )
    .padding()
}
