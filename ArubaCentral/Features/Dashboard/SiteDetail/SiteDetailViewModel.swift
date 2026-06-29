import Foundation
import Combine

@MainActor
final class SiteDetailViewModel: ObservableObject {
    @Published private(set) var apsState: LoadState<[AccessPoint]>        = .idle
    @Published private(set) var switchesState: LoadState<[CentralSwitch]> = .idle

    let site: Site
    private let client: CentralAPIClientProtocol
    private let pageSize = 100

    private var apOffset          = 0
    private var apHasMore         = false
    private var isLoadingMoreAPs  = false

    private var switchOffset          = 0
    private var switchHasMore         = false
    private var isLoadingMoreSwitches = false

    init(site: Site, client: CentralAPIClientProtocol) {
        self.site   = site
        self.client = client
    }

    func load() async {
        apsState      = .loading
        switchesState = .loading
        apOffset      = 0
        switchOffset  = 0

        async let apsTask      = fetchAPs(offset: 0, appending: false)
        async let switchesTask = fetchSwitches(offset: 0, appending: false)
        await apsTask
        await switchesTask
    }

    func refresh() async {
        apOffset     = 0
        switchOffset = 0
        async let apsTask      = fetchAPs(offset: 0, appending: false)
        async let switchesTask = fetchSwitches(offset: 0, appending: false)
        await apsTask
        await switchesTask
    }

    func loadNextAPPage() async {
        guard apHasMore, !isLoadingMoreAPs else { return }
        isLoadingMoreAPs = true
        defer { isLoadingMoreAPs = false }
        await fetchAPs(offset: apOffset, appending: true)
    }

    func loadNextSwitchPage() async {
        guard switchHasMore, !isLoadingMoreSwitches else { return }
        isLoadingMoreSwitches = true
        defer { isLoadingMoreSwitches = false }
        await fetchSwitches(offset: switchOffset, appending: true)
    }

    // MARK: - Private fetch

    private func fetchAPs(offset: Int, appending: Bool) async {
        do {
            let page = try await client.fetchAPs(site: site.name, search: nil,
                                                 limit: pageSize, offset: offset)
            apOffset  = offset + page.items.count
            apHasMore = page.hasMore

            if appending, case .loaded(let existing) = apsState {
                apsState = .loaded(existing + page.items)
            } else {
                apsState = .loaded(page.items)
            }
        } catch let error as APIError {
            if !appending { apsState = .error(error) }
        } catch {
            if !appending { apsState = .error(.networkError) }
        }
    }

    private func fetchSwitches(offset: Int, appending: Bool) async {
        do {
            let page = try await client.fetchSwitches(site: site.name, search: nil,
                                                      limit: pageSize, offset: offset)
            switchOffset  = offset + page.items.count
            switchHasMore = page.hasMore

            if appending, case .loaded(let existing) = switchesState {
                switchesState = .loaded(existing + page.items)
            } else {
                switchesState = .loaded(page.items)
            }
        } catch let error as APIError {
            if !appending { switchesState = .error(error) }
        } catch {
            if !appending { switchesState = .error(.networkError) }
        }
    }
}
