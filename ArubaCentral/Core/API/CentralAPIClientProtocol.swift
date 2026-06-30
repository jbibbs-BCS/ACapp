import Foundation

protocol CentralAPIClientProtocol: AnyObject {
    // Sites
    func fetchSiteHealth() async throws -> [Site]

    // APs
    func fetchAPs(site: String?, search: String?, limit: Int, next: String?) async throws -> PaginatedResponse<AccessPoint>
    func fetchAPDetail(serial: String) async throws -> AccessPoint
    func fetchAPRadios(serial: String) async throws -> [Radio]
    func fetchAPClients(serial: String, limit: Int, next: String?) async throws -> PaginatedResponse<CentralClient>

    // Switches
    func fetchSwitches(site: String?, search: String?, limit: Int, next: String?) async throws -> PaginatedResponse<CentralSwitch>
    func fetchSwitchDetail(serial: String) async throws -> CentralSwitch
    func fetchSwitchInterfaces(serial: String) async throws -> [SwitchInterface]
    func fetchSwitchVLANs(serial: String) async throws -> [VLAN]

    // Clients
    func fetchClients(site: String?, search: String?, limit: Int, next: String?) async throws -> PaginatedResponse<CentralClient>
    func fetchClientDetail(macAddress: String) async throws -> CentralClient

    // Alerts
    func fetchAlerts(limit: Int, next: String?) async throws -> PaginatedResponse<CentralAlert>
    func clearAlert(alertId: String) async throws

    // Actions
    func rebootAP(serial: String) async throws
    func blinkAPLED(serial: String) async throws
    func disconnectAllClientsFromAP(serial: String) async throws

    // Settings
    func testConnection() async throws
    func updateBaseURL(_ url: URL)

    // Search
    func searchDevices(query: String) async throws -> [SearchResult]
}
