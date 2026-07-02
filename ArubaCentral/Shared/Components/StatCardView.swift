import SwiftUI

struct StatCardView: View {
    let title: String
    let value: String
    let systemImage: String
    var accentColor: Color = .brandOrange

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 3pt top accent bar
            Rectangle()
                .fill(accentColor)
                .frame(height: 3)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: systemImage)
                        .foregroundStyle(accentColor)
                        .imageScale(.small)
                        .accessibilityHidden(true)
                    Text(title.uppercased())
                        .font(.caption2.weight(.medium))
                        .tracking(0.5)
                        .foregroundStyle(.secondary)
                }
                Text(value)
                    .font(.title2.bold())
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 11)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.cardBorder, lineWidth: 0.5)
        )
        .shadow(
            color: colorScheme == .light ? .black.opacity(0.06) : .clear,
            radius: 8, x: 0, y: 2
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

#Preview {
    HStack(spacing: 12) {
        StatCardView(title: "APs",     value: "24",  systemImage: "antenna.radiowaves.left.and.right")
        StatCardView(title: "Clients", value: "310", systemImage: "person.2")
        StatCardView(title: "Down",    value: "3",   systemImage: "xmark.circle.fill", accentColor: .healthCritical)
    }
    .padding()
}
