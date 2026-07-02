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
    case stackMember(StackMember, parentSerial: String)

    var id: String {
        switch self {
        case .ap(let ap):                      return ap.serial
        case .switch_(let sw):                 return sw.serial
        case .stackMember(let m, _):           return "member-\(m.serial)"
        }
    }

    var serial: String {
        switch self {
        case .ap(let ap):                      return ap.serial
        case .switch_(let sw):                 return sw.serial
        case .stackMember(let m, _):           return m.serial
        }
    }

    var name: String {
        switch self {
        case .ap(let ap):                      return ap.name
        case .switch_(let sw):                 return sw.name
        case .stackMember(let m, _):           return m.serial
        }
    }

    var model: String {
        switch self {
        case .ap(let ap):                      return ap.model
        case .switch_(let sw):                 return sw.model
        case .stackMember(let m, _):           return m.model ?? "Stack Member"
        }
    }

    var status: DeviceStatus {
        switch self {
        case .ap(let ap):                      return ap.status
        case .switch_(let sw):                 return sw.status
        case .stackMember(let m, _):           return m.status
        }
    }

    var uptime: Int? {
        switch self {
        case .ap(let ap):                      return ap.uptime
        case .switch_(let sw):                 return sw.uptime
        case .stackMember:                     return nil
        }
    }

    var siteName: String? {
        switch self {
        case .ap(let ap):                      return ap.siteName
        case .switch_(let sw):                 return sw.siteName
        case .stackMember:                     return nil
        }
    }

    /// Convenience for filter comparisons in tests
    var deviceType: DeviceFilterType {
        switch self {
        case .ap:           return .ap
        case .switch_:      return .switch_
        case .stackMember:  return .switch_
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

            // Collect stack members for stacked switches (best-effort; failures are silently ignored)
            var stackMembers: [String: [StackMember]] = [:]
            let allSwitchSerials = Set(switches.items.map { $0.serial })
            for sw in switches.items {
                guard let stackId = sw.stackId, stackMembers[stackId] == nil else { continue }
                if let members = try? await apiClient.fetchStackMembers(serial: stackId) {
                    // Exclude the conductor (already shown as the switch row itself)
                    stackMembers[stackId] = members.filter { !allSwitchSerials.contains($0.serial) }
                }
            }

            // Build list: APs first, then each switch followed by its stack members
            var items: [DeviceItem] = aps.items.map { .ap($0) }
            for sw in switches.items {
                items.append(.switch_(sw))
                if let stackId = sw.stackId, let members = stackMembers[stackId] {
                    items.append(contentsOf: members.map { .stackMember($0, parentSerial: sw.serial) })
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
        allItems.first {
            guard case .stackMember = $0 else { return $0.serial == serial }
            return false
        }
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
