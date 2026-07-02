import SwiftUI

struct BrandedTabPicker: View {
    let tabs: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs.indices, id: \.self) { index in
                Button {
                    selection = index
                } label: {
                    Text(tabs[index])
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            selection == index ? Color.brandOrange : Color.clear,
                            in: Capsule()
                        )
                        .foregroundStyle(
                            selection == index ? Color.white : Color.secondary
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == index ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Color.brandNavy.opacity(0.07), in: Capsule())
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    @Previewable @State var selection = 0
    VStack(spacing: 16) {
        BrandedTabPicker(tabs: ["Overview", "Radios", "Clients"], selection: $selection)
        BrandedTabPicker(tabs: ["Overview", "Ports", "VLANs"], selection: $selection)
        Text("Selected: \(selection)")
    }
    .padding()
}
