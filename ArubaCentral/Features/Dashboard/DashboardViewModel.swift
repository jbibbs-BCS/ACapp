import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var sitesState: LoadState<[Site]> = .idle

    private let client: CentralAPIClientProtocol

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
        do {
            let sites = try await client.fetchSiteHealth()
            let sorted = sites.sorted {
                $0.healthLevel.sortOrder < $1.healthLevel.sortOrder
            }
            sitesState = .loaded(sorted)
        } catch let error as APIError {
            sitesState = .error(error)
        } catch {
            sitesState = .error(.networkError)
        }
    }
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
