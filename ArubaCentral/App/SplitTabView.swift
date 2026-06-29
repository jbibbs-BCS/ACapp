import SwiftUI

struct SplitTabView<Sidebar: View, Content: View>: View {
    @ViewBuilder let sidebar: () -> Sidebar
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationSplitView {
            sidebar()
                .navigationSplitViewColumnWidth(min: 200, ideal: 320, max: 320)
        } detail: {
            content()
        }
    }
}
