import SwiftUI

// Placeholder — replaced per feature phase
struct DashboardPlaceholder: View {
    var body: some View { Text("Dashboard").navigationTitle("Dashboard") }
}

struct DevicesPlaceholder: View {
    var body: some View { Text("Devices").navigationTitle("Devices") }
}

struct ClientsPlaceholder: View {
    var body: some View { Text("Clients").navigationTitle("Clients") }
}

struct AlertsPlaceholder: View {
    var body: some View { Text("Alerts").navigationTitle("Alerts") }
}

struct SettingsPlaceholder: View {
    var body: some View { Text("Settings").navigationTitle("Settings") }
}

// MARK: - Device detail placeholders (replaced in Phase 5)

struct APDetailPlaceholder: View {
    let ap: AccessPoint
    var body: some View { Text(ap.name).navigationTitle(ap.name) }
}

struct SwitchDetailPlaceholder: View {
    let sw: CentralSwitch
    var body: some View { Text(sw.name).navigationTitle(sw.name) }
}
