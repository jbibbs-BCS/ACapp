import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var sitesState: LoadState<[Site]> = .idle
    @Published private(set) var alertCounts: AlertSummaryCounts = .empty

    private let client: CentralAPIClientProtocol

    // Site names hidden from the dashboard (compared case-insensitively).
    private let hiddenSiteNames: Set<String> = ["test equipment"]

    init(apiClient: CentralAPIClientProtocol) {
        self.client = apiClient
    }

    func load() async {
        sitesState = .loading
        await fetch()
    }

    func refresh() async {
        await fetch()
    }

    private func fetch() async {
        async let sitesTask = client.fetchSiteHealth()
        async let alertsTask = client.fetchAlerts(limit: 100, next: nil)

        do {
            let sites = try await sitesTask
            let visible = sites.filter { !hiddenSiteNames.contains($0.name.lowercased()) }
            sitesState = .loaded(visible.sorted { $0.healthLevel.sortOrder < $1.healthLevel.sortOrder })
        } catch let error as APIError {
            sitesState = .error(error)
        } catch {
            sitesState = .error(.networkError)
        }

        if let page = try? await alertsTask {
            alertCounts = AlertSummaryCounts(alerts: page.items.filter { !$0.isCleared })
        }
    }
}

struct AlertSummaryCounts {
    let critical: Int
    let major: Int
    let minor: Int
    let info: Int

    static let empty = AlertSummaryCounts(critical: 0, major: 0, minor: 0, info: 0)

    init(critical: Int, major: Int, minor: Int, info: Int) {
        self.critical = critical
        self.major = major
        self.minor = minor
        self.info = info
    }

    init(alerts: [CentralAlert]) {
        critical = alerts.filter { $0.severity == .critical }.count
        major    = alerts.filter { $0.severity == .major }.count
        minor    = alerts.filter { $0.severity == .minor }.count
        info     = alerts.filter { $0.severity == .info }.count
    }

    var total: Int  { critical + major + minor + info }
    var hasAny: Bool { total > 0 }
}

private extension HealthLevel {
    var sortOrder: Int {
        switch self {
        case .critical: return 0
        case .warning:  return 1
        case .good:     return 2
        }
    }
}
