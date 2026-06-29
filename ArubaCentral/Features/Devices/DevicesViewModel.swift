import Foundation
import Combine

// MARK: - DeviceFilterType

enum DeviceFilterType: String, CaseIterable, Identifiable, Equatable {
    case all     = "All"
    case ap      = "APs"
    case switch_ = "Switches"
    var id: String { rawValue }
}

// MARK: - DeviceItem (enum — wraps AP or Switch)

enum DeviceItem: Identifiable {
    case ap(AccessPoint)
    case switch_(CentralSwitch)

    var id: String {
        switch self {
        case .ap(let ap):      return ap.serial
        case .switch_(let sw): return sw.serial
        }
    }

    var serial: String { id }

    var name: String {
        switch self {
        case .ap(let ap):      return ap.name
        case .switch_(let sw): return sw.name
        }
    }

    var model: String {
        switch self {
        case .ap(let ap):      return ap.model
        case .switch_(let sw): return sw.model
        }
    }

    var status: DeviceStatus {
        switch self {
        case .ap(let ap):      return ap.status
        case .switch_(let sw): return sw.status
        }
    }

    var uptime: Int? {
        switch self {
        case .ap(let ap):      return ap.uptime
        case .switch_(let sw): return sw.uptime
        }
    }

    var siteName: String? {
        switch self {
        case .ap(let ap):      return ap.siteName
        case .switch_(let sw): return sw.siteName
        }
    }

    /// Convenience for filter comparisons in tests
    var deviceType: DeviceFilterType {
        switch self {
        case .ap:      return .ap
        case .switch_: return .switch_
        }
    }
}

// MARK: - DevicesViewModel

@MainActor
final class DevicesViewModel: ObservableObject {
    @Published private(set) var devicesState: LoadState<[DeviceItem]> = .idle
    @Published var filterType: DeviceFilterType = .all {
        didSet { applyFilter() }
    }
    @Published var selectedSite: String? = nil

    let apiClient: CentralAPIClientProtocol
    private var allItems: [DeviceItem] = []
    private let pageSize = 100

    init(apiClient: CentralAPIClientProtocol) {
        self.apiClient = apiClient
    }

    // MARK: - Load

    func load() async {
        devicesState = .loading
        do {
            async let apsPage     = apiClient.fetchAPs(site: selectedSite, search: nil,
                                                       limit: pageSize, offset: 0)
            async let switchesPage = apiClient.fetchSwitches(site: selectedSite, search: nil,
                                                             limit: pageSize, offset: 0)
            let (aps, switches) = try await (apsPage, switchesPage)
            allItems = aps.items.map { .ap($0) } + switches.items.map { .switch_($0) }
            applyFilter()
        } catch let error as APIError {
            devicesState = .error(error)
        } catch {
            devicesState = .error(.networkError)
        }
    }

    func refresh() async { await load() }

    // MARK: - Search (API-backed; empty query resets to full load)

    func search(query: String) async {
        guard !query.isEmpty else { await load(); return }
        devicesState = .loading
        do {
            async let apsPage     = apiClient.fetchAPs(site: selectedSite, search: query,
                                                       limit: pageSize, offset: 0)
            async let switchesPage = apiClient.fetchSwitches(site: selectedSite, search: query,
                                                             limit: pageSize, offset: 0)
            let (aps, switches) = try await (apsPage, switchesPage)
            allItems = aps.items.map { .ap($0) } + switches.items.map { .switch_($0) }
            applyFilter()
        } catch let error as APIError {
            devicesState = .error(error)
        } catch {
            devicesState = .error(.networkError)
        }
    }

    // MARK: - Phase 10 helpers

    func devices(forSite siteID: String) -> [DeviceItem] {
        allItems.filter { $0.siteName == siteID }
    }

    func device(withSerial serial: String) -> DeviceItem? {
        allItems.first { $0.serial == serial }
    }

    // MARK: - Private

    private func applyFilter() {
        let filtered: [DeviceItem]
        switch filterType {
        case .all:     filtered = allItems
        case .ap:      filtered = allItems.filter { $0.deviceType == .ap }
        case .switch_: filtered = allItems.filter { $0.deviceType == .switch_ }
        }
        devicesState = .loaded(filtered)
    }
}
