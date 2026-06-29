import SwiftUI

// Placeholder — replaced in Task 10
struct SiteDetailView: View {
    let site: Site

    var body: some View {
        Text(site.name)
            .navigationTitle(site.name)
    }
}

#Preview {
    NavigationStack {
        SiteDetailView(site: Site(
            id: "s1",
            name: "HQ Campus",
            healthScore: 95,
            apCount: 24,
            switchCount: 4,
            clientCount: 310
        ))
    }
}
