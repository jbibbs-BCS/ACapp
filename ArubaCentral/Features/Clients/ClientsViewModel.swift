import Foundation
import Combine

@MainActor
final class ClientsViewModel: ObservableObject {
    @Published private(set) var clientsState: LoadState<[CentralClient]> = .idle
    @Published var selectedSite: String? = nil
    @Published private(set) var sites: [String] = []

    private let client: CentralAPIClientProtocol
    private let pageSize = 100

    var wirelessClients: [CentralClient] {
        guard case .loaded(let items) = clientsState else { return [] }
        return items.filter { $0.connectionType == .wireless }
    }

    var wiredClients: [CentralClient] {
        guard case .loaded(let items) = clientsState else { return [] }
        return items.filter { $0.connectionType == .wired }
    }

    init(apiClient: CentralAPIClientProtocol) {
        self.client = apiClient
    }

    func loadSites() async {
        guard sites.isEmpty else { return }
        if let fetched = try? await client.fetchSiteHealth() {
            sites = fetched.map { $0.name }.sorted()
        }
    }

    func selectSite(_ site: String?) async {
        selectedSite = site
        guard let site else { clientsState = .idle; return }
        clientsState = .loading

        var all: [CentralClient] = []
        var cursor: String? = nil
        do {
            repeat {
                let page = try await client.fetchClients(site: site, search: nil,
                                                         limit: pageSize, next: cursor)
                all.append(contentsOf: page.items)
                cursor = page.next
                clientsState = .loaded(all)
            } while cursor != nil
        } catch let error as APIError {
            if all.isEmpty { clientsState = .error(error) }
        } catch {
            if all.isEmpty { clientsState = .error(.networkError) }
        }
    }

    func refresh() async {
        await selectSite(selectedSite)
    }

}
