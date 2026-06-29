import Foundation
@testable import ArubaCentral

final class MockCentralAPIClient: CentralAPIClientProtocol {

    // MARK: - Configurable responses
    var sitesResult:         Result<[Site], APIError>                            = .success([])
    var apsResult:           Result<PaginatedResponse<AccessPoint>, APIError>    = .success(.empty())
    var apDetailResult:      Result<AccessPoint, APIError>                       = .failure(.networkError)
    var radiosResult:        Result<[Radio], APIError>                           = .success([])
    var apClientsResult:     Result<PaginatedResponse<CentralClient>, APIError>  = .success(.empty())
    var switchesResult:      Result<PaginatedResponse<CentralSwitch>, APIError>  = .success(.empty())
    var switchDetailResult:  Result<CentralSwitch, APIError>                     = .failure(.networkError)
    var interfacesResult:    Result<[SwitchInterface], APIError>                 = .success([])
    var vlansResult:         Result<[VLAN], APIError>                            = .success([])
    var clientsResult:       Result<PaginatedResponse<CentralClient>, APIError>  = .success(.empty())
    var clientDetailResult:  Result<CentralClient, APIError>                     = .failure(.networkError)
    var alertsResult:        Result<PaginatedResponse<CentralAlert>, APIError>   = .success(.empty())
    var clearAlertError:     APIError?                                           = nil
    var rebootError:         APIError?                                           = nil
    var blinkError:          APIError?                                           = nil
    var disconnectError:     APIError?                                           = nil
    var testConnectionError: APIError?                                           = nil

    // MARK: - Call tracking
    var fetchSitesCallCount      = 0
    var fetchAPsCallCount        = 0
    var rebootCallCount          = 0
    var blinkCallCount           = 0
    var clearAlertCallCount      = 0
    var disconnectCallCount      = 0
    var lastSearchQuery: String? = nil
    var lastSiteFilter: String?  = nil

    // MARK: - Protocol conformance

    func fetchSiteHealth() async throws -> [Site] {
        fetchSitesCallCount += 1
        return try sitesResult.get()
    }

    func fetchAPs(site: String?, search: String?, limit: Int, offset: Int) async throws -> PaginatedResponse<AccessPoint> {
        fetchAPsCallCount += 1
        lastSiteFilter  = site
        lastSearchQuery = search
        return try apsResult.get()
    }

    func fetchAPDetail(serial: String) async throws -> AccessPoint {
        return try apDetailResult.get()
    }

    func fetchAPRadios(serial: String) async throws -> [Radio] {
        return try radiosResult.get()
    }

    func fetchAPClients(serial: String, limit: Int, offset: Int) async throws -> PaginatedResponse<CentralClient> {
        return try apClientsResult.get()
    }

    func fetchSwitches(site: String?, search: String?, limit: Int, offset: Int) async throws -> PaginatedResponse<CentralSwitch> {
        lastSiteFilter  = site
        lastSearchQuery = search
        return try switchesResult.get()
    }

    func fetchSwitchDetail(serial: String) async throws -> CentralSwitch {
        return try switchDetailResult.get()
    }

    func fetchSwitchInterfaces(serial: String) async throws -> [SwitchInterface] {
        return try interfacesResult.get()
    }

    func fetchSwitchVLANs(serial: String) async throws -> [VLAN] {
        return try vlansResult.get()
    }

    func fetchClients(site: String?, search: String?, limit: Int, offset: Int) async throws -> PaginatedResponse<CentralClient> {
        lastSiteFilter  = site
        lastSearchQuery = search
        return try clientsResult.get()
    }

    func fetchClientDetail(macAddress: String) async throws -> CentralClient {
        return try clientDetailResult.get()
    }

    func fetchAlerts(limit: Int, offset: Int) async throws -> PaginatedResponse<CentralAlert> {
        return try alertsResult.get()
    }

    func clearAlert(alertId: String) async throws {
        clearAlertCallCount += 1
        if let error = clearAlertError { throw error }
    }

    func rebootAP(serial: String) async throws {
        rebootCallCount += 1
        if let error = rebootError { throw error }
    }

    func blinkAPLED(serial: String) async throws {
        blinkCallCount += 1
        if let error = blinkError { throw error }
    }

    func disconnectAllClientsFromAP(serial: String) async throws {
        disconnectCallCount += 1
        if let error = disconnectError { throw error }
    }

    func testConnection() async throws {
        if let error = testConnectionError { throw error }
    }
}

// MARK: - Convenience

extension PaginatedResponse {
    static func empty() -> PaginatedResponse<T> {
        PaginatedResponse(items: [], total: 0, offset: 0, limit: 100)
    }

    static func of(_ items: [T]) -> PaginatedResponse<T> {
        PaginatedResponse(items: items, total: items.count, offset: 0, limit: 100)
    }
}
