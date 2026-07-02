import Foundation
import Combine

@MainActor
final class SiteDetailViewModel: ObservableObject {
    @Published private(set) var apsState: LoadState<[AccessPoint]>        = .idle
    @Published private(set) var switchesState: LoadState<[CentralSwitch]> = .idle
    @Published private(set) var stackMembersMap: [String: [StackMember]]  = [:]

    let site: Site
    private let apiClient: CentralAPIClientProtocol
    private let pageSize = 100

    private var apNextCursor:       String? = nil
    private var apHasMore:          Bool    = false
    private var isLoadingMoreAPs:   Bool    = false

    private var switchNextCursor:       String? = nil
    private var switchHasMore:          Bool    = false
    private var isLoadingMoreSwitches:  Bool    = false

    init(site: Site, apiClient: CentralAPIClientProtocol) {
        self.site      = site
        self.apiClient = apiClient
    }

    func load() async {
        apsState      = .loading
        switchesState = .loading
        apNextCursor      = nil
        switchNextCursor  = nil

        async let apsTask      = fetchAPs(next: nil, appending: false)
        async let switchesTask = fetchSwitches(next: nil, appending: false)
        await apsTask
        await switchesTask
    }

    func refresh() async {
        apNextCursor     = nil
        switchNextCursor = nil
        async let apsTask      = fetchAPs(next: nil, appending: false)
        async let switchesTask = fetchSwitches(next: nil, appending: false)
        await apsTask
        await switchesTask
    }

    func loadNextAPPage() async {
        guard apHasMore, !isLoadingMoreAPs else { return }
        isLoadingMoreAPs = true
        defer { isLoadingMoreAPs = false }
        await fetchAPs(next: apNextCursor, appending: true)
    }

    func loadNextSwitchPage() async {
        guard switchHasMore, !isLoadingMoreSwitches else { return }
        isLoadingMoreSwitches = true
        defer { isLoadingMoreSwitches = false }
        await fetchSwitches(next: switchNextCursor, appending: true)
    }

    // MARK: - Private fetch

    private func fetchAPs(next: String?, appending: Bool) async {
        do {
            let page = try await apiClient.fetchAPs(site: site.name, search: nil,
                                                    limit: pageSize, next: next)
            apNextCursor = page.next
            apHasMore    = page.hasMore

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

    private func fetchSwitches(next: String?, appending: Bool) async {
        do {
            let page = try await apiClient.fetchSwitches(site: site.name, search: nil,
                                                         limit: pageSize, next: next)
            switchNextCursor = page.next
            switchHasMore    = page.hasMore

            let switches: [CentralSwitch]
            if appending, case .loaded(let existing) = switchesState {
                switches = existing + page.items
            } else {
                switches = page.items
            }
            switchesState = .loaded(switches)

            // Fetch stack members for any stacked switches on this page (best-effort)
            let allSerials = Set(switches.map { $0.serial })
            for sw in page.items where sw.stackId != nil {
                guard let stackId = sw.stackId, stackMembersMap[stackId] == nil else { continue }
                if let members = try? await apiClient.fetchStackMembers(serial: stackId) {
                    stackMembersMap[stackId] = members.filter { !allSerials.contains($0.serial) }
                }
            }
        } catch let error as APIError {
            if !appending { switchesState = .error(error) }
        } catch {
            if !appending { switchesState = .error(.networkError) }
        }
    }
}
