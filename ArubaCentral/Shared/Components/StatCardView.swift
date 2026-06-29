import SwiftUI

struct StatCardView: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title3.bold())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

#Preview {
    HStack {
        StatCardView(title: "APs",     value: "24",  systemImage: "antenna.radiowaves.left.and.right")
        StatCardView(title: "Clients", value: "310", systemImage: "person.2")
    }
    .padding()
}
