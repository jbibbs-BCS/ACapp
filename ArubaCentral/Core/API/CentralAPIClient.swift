@preconcurrency import Foundation
import Combine

@MainActor
final class CentralAPIClient: ObservableObject, CentralAPIClientProtocol {
    private let authManager: AuthTokenManager
    private let session: URLSession
    private let decoder: JSONDecoder

    @Published var baseURL: URL

    init(authManager: AuthTokenManager,
         session: URLSession = .shared,
         baseURL: URL? = nil) {
        self.authManager = authManager
        self.session = session
        self.baseURL = baseURL ?? CentralRegion.defaultRegion.baseURL
        self.decoder = {
            let d = JSONDecoder()
            d.dateDecodingStrategy = .secondsSince1970
            return d
        }()
    }

    // MARK: - Settings

    func updateBaseURL(_ url: URL) {
        baseURL = url
    }

    // MARK: - Private helpers

    // Uses string concatenation rather than appendingPathComponent so that
    // multi-segment paths like /network-monitoring/v1/aps are not percent-encoded.
    private func buildRequest(path: String, queryItems: [URLQueryItem] = []) async throws -> URLRequest {
        let base = baseURL.absoluteString.hasSuffix("/")
            ? String(baseURL.absoluteString.dropLast())
            : baseURL.absoluteString
        let normalizedPath = path.hasPrefix("/") ? path : "/" + path
        var components = URLComponents(string: base + normalizedPath)!
        if !queryItems.isEmpty { components.queryItems = queryItems }
        var request = URLRequest(url: components.url!)
        do {
            let token = try await authManager.validToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } catch is KeychainError {
            throw APIError.unauthorized
        }
        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.networkError }

            switch http.statusCode {
            case 200...299:
                do { return try decoder.decode(T.self, from: data) }
                catch { throw APIError.decodingError }
            case 401:
                return try await retryAfterRefresh(request)
            case 403: throw APIError.forbidden
            case 429: throw APIError.rateLimited
            default:  throw APIError.serverError(http.statusCode)
            }
        } catch let error as APIError {
            throw error
        } catch is KeychainError {
            throw APIError.unauthorized
        } catch {
            throw APIError.networkError
        }
    }

    private func retryAfterRefresh<T: Decodable>(_ original: URLRequest) async throws -> T {
        try await authManager.fetchNewToken()
        let newToken = try await authManager.validToken()
        var retried = original
        retried.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: retried)
        guard let http = response as? HTTPURLResponse else { throw APIError.networkError }
        guard (200...299).contains(http.statusCode) else { throw APIError.sessionExpired }

        do { return try decoder.decode(T.self, from: data) }
        catch { throw APIError.decodingError }
    }

    private func performVoid(_ request: URLRequest) async throws {
        let _: EmptyResponse = try await perform(request)
    }

    private func postRequest(path: String, body: some Encodable) async throws -> URLRequest {
        var request = try await buildRequest(path: path)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    // MARK: - Private API response wrappers
    // The New Central API wraps list results in resource-specific keys.
    // These types handle the wire format; callers receive PaginatedResponse<T>.

    private struct SiteHealthListResponse: Decodable {
        let sites: [Site]
        let total: Int?
        let next: String?
    }

    private struct APListResponse: Decodable {
        let aps: [AccessPoint]
        let total: Int?
        let next: String?
    }

    private struct SwitchListResponse: Decodable {
        let switches: [CentralSwitch]
        let total: Int?
        let next: String?
    }

    private struct ClientListResponse: Decodable {
        let clients: [CentralClient]
        let total: Int?
        let next: String?
    }

    private struct AlertListResponse: Decodable {
        let alerts: [CentralAlert]
        let total: Int?
        let next: String?
    }

    private struct RadioListResponse: Decodable {
        let radios: [Radio]
        let total: Int?
        let next: String?
    }

    // MARK: - Sites

    func fetchSiteHealth() async throws -> [Site] {
        let request = try await buildRequest(path: "/network-monitoring/v1/sites-health")
        let response: SiteHealthListResponse = try await perform(request)
        return response.sites
    }

    // MARK: - APs

    func fetchAPs(site: String? = nil, search: String? = nil,
                  limit: Int = 100, next: String? = nil) async throws -> PaginatedResponse<AccessPoint> {
        var queryItems: [URLQueryItem] = [.init(name: "limit", value: "\(limit)")]
        if let next { queryItems.append(.init(name: "next", value: next)) }
        var filters: [String] = []
        if let site   { filters.append("siteName eq '\(site)'") }
        if let search { filters.append("contains(deviceName, '\(search)')") }
        if !filters.isEmpty { queryItems.append(.init(name: "filter", value: filters.joined(separator: " and "))) }
        let request = try await buildRequest(path: "/network-monitoring/v1/aps", queryItems: queryItems)
        let response: APListResponse = try await perform(request)
        return PaginatedResponse(items: response.aps, total: response.total, next: response.next)
    }

    func fetchAPDetail(serial: String) async throws -> AccessPoint {
        let request = try await buildRequest(path: "/network-monitoring/v1/aps/\(serial)")
        return try await perform(request)
    }

    func fetchAPRadios(serial: String) async throws -> [Radio] {
        let request = try await buildRequest(path: "/network-monitoring/v1/aps/\(serial)/radios")
        let response: RadioListResponse = try await perform(request)
        return response.radios
    }

    func fetchAPClients(serial: String, limit: Int = 100, next: String? = nil) async throws -> PaginatedResponse<CentralClient> {
        var queryItems: [URLQueryItem] = [
            .init(name: "limit",  value: "\(limit)"),
            .init(name: "filter", value: "associatedDevice eq '\(serial)'")
        ]
        if let next { queryItems.append(.init(name: "next", value: next)) }
        let request = try await buildRequest(path: "/network-monitoring/v1/clients", queryItems: queryItems)
        let response: ClientListResponse = try await perform(request)
        return PaginatedResponse(items: response.clients, total: response.total, next: response.next)
    }

    // MARK: - Switches

    func fetchSwitches(site: String? = nil, search: String? = nil,
                       limit: Int = 100, next: String? = nil) async throws -> PaginatedResponse<CentralSwitch> {
        var queryItems: [URLQueryItem] = [.init(name: "limit", value: "\(limit)")]
        if let next { queryItems.append(.init(name: "next", value: next)) }
        var filters: [String] = []
        if let site   { filters.append("siteName eq '\(site)'") }
        if let search { filters.append("contains(deviceName, '\(search)')") }
        if !filters.isEmpty { queryItems.append(.init(name: "filter", value: filters.joined(separator: " and "))) }
        let request = try await buildRequest(path: "/network-monitoring/v1/switches", queryItems: queryItems)
        let response: SwitchListResponse = try await perform(request)
        return PaginatedResponse(items: response.switches, total: response.total, next: response.next)
    }

    func fetchSwitchDetail(serial: String) async throws -> CentralSwitch {
        let request = try await buildRequest(path: "/network-monitoring/v1/switches/\(serial)")
        return try await perform(request)
    }

    func fetchSwitchInterfaces(serial: String) async throws -> [SwitchInterface] {
        let request = try await buildRequest(path: "/network-monitoring/v1/switches/\(serial)/interfaces")
        return try await perform(request)
    }

    func fetchSwitchVLANs(serial: String) async throws -> [VLAN] {
        let request = try await buildRequest(path: "/network-monitoring/v1/switches/\(serial)/vlans")
        return try await perform(request)
    }

    // MARK: - Clients

    func fetchClients(site: String? = nil, search: String? = nil,
                      limit: Int = 100, next: String? = nil) async throws -> PaginatedResponse<CentralClient> {
        var queryItems: [URLQueryItem] = [.init(name: "limit", value: "\(limit)")]
        if let next { queryItems.append(.init(name: "next", value: next)) }
        var filters: [String] = []
        if let site   { filters.append("siteName eq '\(site)'") }
        if let search { filters.append("contains(name, '\(search)')") }
        if !filters.isEmpty { queryItems.append(.init(name: "filter", value: filters.joined(separator: " and "))) }
        let request = try await buildRequest(path: "/network-monitoring/v1/clients", queryItems: queryItems)
        let response: ClientListResponse = try await perform(request)
        return PaginatedResponse(items: response.clients, total: response.total, next: response.next)
    }

    func fetchClientDetail(macAddress: String) async throws -> CentralClient {
        let request = try await buildRequest(path: "/network-monitoring/v1/clients/\(macAddress)")
        return try await perform(request)
    }

    // MARK: - Alerts

    func fetchAlerts(limit: Int = 100, next: String? = nil) async throws -> PaginatedResponse<CentralAlert> {
        var queryItems: [URLQueryItem] = [.init(name: "limit", value: "\(limit)")]
        if let next { queryItems.append(.init(name: "next", value: next)) }
        let request = try await buildRequest(path: "/network-notifications/v1/alerts", queryItems: queryItems)
        let response: AlertListResponse = try await perform(request)
        return PaginatedResponse(items: response.alerts, total: response.total, next: response.next)
    }

    func clearAlert(alertId: String) async throws {
        let request = try await postRequest(path: "/network-notifications/v1/alerts/clear",
                                            body: ClearAlertsBody(alertKeys: [alertId]))
        try await performVoid(request)
    }

    // MARK: - Actions
    // Reboot is confirmed at /network-troubleshooting/v1alpha1/.
    // Locate and disconnect-clients follow the same prefix by pattern;
    // verify against a live environment if they return 404.

    func rebootAP(serial: String) async throws {
        let request = try await postRequest(path: "/network-troubleshooting/v1alpha1/aps/\(serial)/reboot",
                                            body: EmptyBody())
        try await performVoid(request)
    }

    func blinkAPLED(serial: String) async throws {
        let request = try await postRequest(path: "/network-troubleshooting/v1alpha1/aps/\(serial)/locate",
                                            body: EmptyBody())
        try await performVoid(request)
    }

    func disconnectAllClientsFromAP(serial: String) async throws {
        let request = try await postRequest(path: "/network-troubleshooting/v1alpha1/aps/\(serial)/disconnect-clients",
                                            body: EmptyBody())
        try await performVoid(request)
    }

    // MARK: - Connection test
    // Performs a raw HTTP check against a known endpoint so a decodingError
    // in the response body never masks a successful connection.

    func testConnection() async throws {
        let request = try await buildRequest(path: "/network-monitoring/v1/sites-health",
                                             queryItems: [.init(name: "limit", value: "1")])
        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.networkError }
            switch http.statusCode {
            case 200...299: return
            case 401: throw APIError.unauthorized
            case 403: throw APIError.forbidden
            case 429: throw APIError.rateLimited
            default:  throw APIError.serverError(http.statusCode)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError
        }
    }

    // MARK: - Search

    func searchDevices(query: String) async throws -> [SearchResult] {
        async let apsPage      = fetchAPs(site: nil, search: query, limit: 50, next: nil)
        async let switchesPage = fetchSwitches(site: nil, search: query, limit: 50, next: nil)
        async let clientsPage  = fetchClients(site: nil, search: query, limit: 50, next: nil)
        let (aps, switches, clients) = try await (apsPage, switchesPage, clientsPage)
        return aps.items.map { .ap($0) }
             + switches.items.map { .switch_($0) }
             + clients.items.map { .client($0) }
    }
}

private struct EmptyResponse: Codable {}
private struct EmptyBody: Encodable {}
private struct ClearAlertsBody: Encodable {
    let alertKeys: [String]
}
