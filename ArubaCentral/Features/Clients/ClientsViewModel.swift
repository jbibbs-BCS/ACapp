import Foundation
import Combine

@MainActor
final class ClientsViewModel: ObservableObject {
    @Published private(set) var clientsState: LoadState<[CentralClient]> = .idle
    @Published var selectedSite: String? = nil

    private let client: CentralAPIClientProtocol
    private let pageSize = 100
    private var nextCursor: String? = nil
    private var hasMore  = false
    private var isLoadingMore = false

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

    func selectSite(_ site: String?) async {
        selectedSite = site
        guard let site else { clientsState = .idle; return }
        nextCursor = nil
        clientsState = .loading
        await fetchClients(site: site, search: nil, next: nil, appending: false)
    }

    func search(query: String) async {
        guard !query.isEmpty else {
            if let site = selectedSite { await fetchClientsForSite(site) }
            else { clientsState = .idle }
            return
        }
        nextCursor = nil
        clientsState = .loading
        await fetchClients(site: selectedSite, search: query, next: nil, appending: false)
    }

    func loadNextPage() async {
        guard hasMore, !isLoadingMore else { return }
        guard let site = selectedSite else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        await fetchClients(site: site, search: nil, next: nextCursor, appending: true)
    }

    func refresh() async {
        guard let site = selectedSite else { return }
        nextCursor = nil
        await fetchClients(site: site, search: nil, next: nil, appending: false)
    }

    // MARK: - Private

    private func fetchClientsForSite(_ site: String) async {
        nextCursor = nil
        await fetchClients(site: site, search: nil, next: nil, appending: false)
    }

    private func fetchClients(site: String?, search: String?, next: String?, appending: Bool) async {
        do {
            let page = try await client.fetchClients(site: site, search: search,
                                                     limit: pageSize, next: next)
            self.nextCursor = page.next
            self.hasMore    = page.hasMore

            if appending, case .loaded(let existing) = clientsState {
                clientsState = .loaded(existing + page.items)
            } else {
                clientsState = .loaded(page.items)
            }
        } catch let error as APIError {
            if !appending { clientsState = .error(error) }
        } catch {
            if !appending { clientsState = .error(.networkError) }
        }
    }
}
