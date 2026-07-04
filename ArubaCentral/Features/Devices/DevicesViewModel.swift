@preconcurrency import Foundation
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
    case stack(SwitchStack)

    var id: String {
        switch self {
        case .ap(let ap):      return ap.serial
        case .switch_(let sw): return sw.serial
        case .stack(let s):    return "stack-\(s.stackId)"
        }
    }

    var serial: String {
        switch self {
        case .ap(let ap):      return ap.serial
        case .switch_(let sw): return sw.serial
        case .stack(let s):    return s.representative.serial
        }
    }

    var name: String {
        switch self {
        case .ap(let ap):      return ap.name
        case .switch_(let sw): return sw.name
        case .stack(let s):    return s.name
        }
    }

    var model: String {
        switch self {
        case .ap(let ap):      return ap.model
        case .switch_(let sw): return sw.model
        case .stack(let s):    return s.model
        }
    }

    var status: DeviceStatus {
        switch self {
        case .ap(let ap):      return ap.status
        case .switch_(let sw): return sw.status
        case .stack(let s):    return s.status
        }
    }

    var uptime: Int? {
        switch self {
        case .ap(let ap):      return ap.uptime
        case .switch_(let sw): return sw.uptime
        case .stack:           return nil
        }
    }

    var siteName: String? {
        switch self {
        case .ap(let ap):      return ap.siteName
        case .switch_(let sw): return sw.siteName
        case .stack(let s):    return s.siteName
        }
    }

    /// Convenience for filter comparisons in tests
    var deviceType: DeviceFilterType {
        switch self {
        case .ap:      return .ap
        case .switch_: return .switch_
        case .stack:   return .switch_
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
            async let apsPage      = apiClient.fetchAPs(site: selectedSite, search: nil,
                                                        limit: pageSize, next: nil)
            async let switchesPage = apiClient.fetchSwitches(site: selectedSite, search: nil,
                                                             limit: pageSize, next: nil)
            let (aps, switches) = try await (apsPage, switchesPage)

            // Build list: APs first, then switches — stacked members collapsed into one row per stack.
            var items: [DeviceItem] = aps.items.map { .ap($0) }
            for entry in switches.items.groupedIntoStacks() {
                switch entry {
                case .standalone(let sw): items.append(.switch_(sw))
                case .stack(let stack):   items.append(.stack(stack))
                }
            }

            allItems = items
            applyFilter()
        } catch let error as APIError {
            devicesState = .error(error)
        } catch {
            devicesState = .error(.networkError)
        }
    }

    func refresh() async { await load() }

    // MARK: - Phase 10 helpers

    func devices(forSite siteID: String) -> [DeviceItem] {
        allItems.filter { $0.siteName == siteID }
    }

    func device(withSerial serial: String) -> DeviceItem? {
        // For a stack, `serial` is the representative (conductor) serial.
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
