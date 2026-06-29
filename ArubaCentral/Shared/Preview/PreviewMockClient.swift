import Foundation

#if DEBUG
final class PreviewMockClient: CentralAPIClientProtocol {
    func fetchSiteHealth() async throws -> [Site] {
        [
            Site(id: "s1", name: "HQ Campus",    healthScore: 95, apCount: 24, switchCount: 4, clientCount: 310),
            Site(id: "s2", name: "Branch Office", healthScore: 62, apCount: 8,  switchCount: 2, clientCount: 47),
            Site(id: "s3", name: "Warehouse",     healthScore: 15, apCount: 4,  switchCount: 1, clientCount: 12),
        ]
    }

    func fetchAPs(site: String?, search: String?, limit: Int, offset: Int) async throws -> PaginatedResponse<AccessPoint> {
        PaginatedResponse(items: [], total: 0, offset: 0, limit: 100)
    }
    func fetchAPDetail(serial: String) async throws -> AccessPoint { throw APIError.networkError }
    func fetchAPRadios(serial: String) async throws -> [Radio] { [] }
    func fetchAPClients(serial: String, limit: Int, offset: Int) async throws -> PaginatedResponse<CentralClient> {
        PaginatedResponse(items: [], total: 0, offset: 0, limit: 100)
    }
    func fetchSwitches(site: String?, search: String?, limit: Int, offset: Int) async throws -> PaginatedResponse<CentralSwitch> {
        PaginatedResponse(items: [], total: 0, offset: 0, limit: 100)
    }
    func fetchSwitchDetail(serial: String) async throws -> CentralSwitch { throw APIError.networkError }
    func fetchSwitchInterfaces(serial: String) async throws -> [SwitchInterface] { [] }
    func fetchSwitchVLANs(serial: String) async throws -> [VLAN] { [] }
    func fetchClients(site: String?, search: String?, limit: Int, offset: Int) async throws -> PaginatedResponse<CentralClient> {
        PaginatedResponse(items: [], total: 0, offset: 0, limit: 100)
    }
    func fetchClientDetail(macAddress: String) async throws -> CentralClient { throw APIError.networkError }
    func fetchAlerts(limit: Int, offset: Int) async throws -> PaginatedResponse<CentralAlert> {
        PaginatedResponse(items: [], total: 0, offset: 0, limit: 100)
    }
    func clearAlert(alertId: String) async throws {}
    func rebootAP(serial: String) async throws {}
    func blinkAPLED(serial: String) async throws {}
    func disconnectAllClientsFromAP(serial: String) async throws {}
    func testConnection() async throws {}
}
#endif
