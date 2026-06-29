import SwiftUI

enum LayoutHelper {
    static func isThreeColumn(width: CGFloat) -> Bool {
        width >= 1024
    }
}

struct AdaptiveNavigationView<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ViewBuilder let content: () -> Content

    var body: some View {
        if sizeClass == .regular {
            content()
        } else {
            NavigationStack {
                content()
            }
        }
    }
}
