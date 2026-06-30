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

    // MARK: - Private helpers

    private func buildRequest(path: String, queryItems: [URLQueryItem] = []) async throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path),
                                       resolvingAgainstBaseURL: false)!
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

    private func postRequest(path: String, body: Encodable) async throws -> URLRequest {
        var request = try await buildRequest(path: path)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    // MARK: - Sites

    func fetchSiteHealth() async throws -> [Site] {
        let request = try await buildRequest(path: "/sitesv1")
        return try await perform(request)
    }

    // MARK: - APs

    func fetchAPs(site: String? = nil, search: String? = nil,
                  limit: Int = 100, offset: Int = 0) async throws -> PaginatedResponse<AccessPoint> {
        var items: [URLQueryItem] = [
            .init(name: "limit",  value: "\(limit)"),
            .init(name: "offset", value: "\(offset)")
        ]
        if let site   { items.append(.init(name: "site_name", value: site)) }
        if let search { items.append(.init(name: "search",    value: search)) }
        let request = try await buildRequest(path: "/accesspointsv1", queryItems: items)
        return try await perform(request)
    }

    func fetchAPDetail(serial: String) async throws -> AccessPoint {
        let request = try await buildRequest(path: "/accesspointsv1/\(serial)")
        return try await perform(request)
    }

    func fetchAPRadios(serial: String) async throws -> [Radio] {
        let request = try await buildRequest(path: "/accesspointradiolistv1",
                                             queryItems: [.init(name: "serial", value: serial)])
        return try await perform(request)
    }

    func fetchAPClients(serial: String, limit: Int = 100, offset: Int = 0) async throws -> PaginatedResponse<CentralClient> {
        let request = try await buildRequest(path: "/clientsv1", queryItems: [
            .init(name: "associated_device", value: serial),
            .init(name: "limit",             value: "\(limit)"),
            .init(name: "offset",            value: "\(offset)")
        ])
        return try await perform(request)
    }

    // MARK: - Switches

    func fetchSwitches(site: String? = nil, search: String? = nil,
                       limit: Int = 100, offset: Int = 0) async throws -> PaginatedResponse<CentralSwitch> {
        var items: [URLQueryItem] = [
            .init(name: "limit",  value: "\(limit)"),
            .init(name: "offset", value: "\(offset)")
        ]
        if let site   { items.append(.init(name: "site_name", value: site)) }
        if let search { items.append(.init(name: "search",    value: search)) }
        let request = try await buildRequest(path: "/switchesv1", queryItems: items)
        return try await perform(request)
    }

    func fetchSwitchDetail(serial: String) async throws -> CentralSwitch {
        let request = try await buildRequest(path: "/switchesv1/\(serial)")
        return try await perform(request)
    }

    func fetchSwitchInterfaces(serial: String) async throws -> [SwitchInterface] {
        let request = try await buildRequest(path: "/listinterfacesv1",
                                             queryItems: [.init(name: "serial", value: serial)])
        return try await perform(request)
    }

    func fetchSwitchVLANs(serial: String) async throws -> [VLAN] {
        let request = try await buildRequest(path: "/listvlansv1",
                                             queryItems: [.init(name: "serial", value: serial)])
        return try await perform(request)
    }

    // MARK: - Clients

    func fetchClients(site: String? = nil, search: String? = nil,
                      limit: Int = 100, offset: Int = 0) async throws -> PaginatedResponse<CentralClient> {
        var items: [URLQueryItem] = [
            .init(name: "limit",  value: "\(limit)"),
            .init(name: "offset", value: "\(offset)")
        ]
        if let site   { items.append(.init(name: "site_name", value: site)) }
        if let search { items.append(.init(name: "search",    value: search)) }
        let request = try await buildRequest(path: "/clientsv1", queryItems: items)
        return try await perform(request)
    }

    func fetchClientDetail(macAddress: String) async throws -> CentralClient {
        let mac = macAddress.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? macAddress
        let request = try await buildRequest(path: "/clientsv1/\(mac)")
        return try await perform(request)
    }

    // MARK: - Alerts

    func fetchAlerts(limit: Int = 100, offset: Int = 0) async throws -> PaginatedResponse<CentralAlert> {
        let request = try await buildRequest(path: "/getalertlistv1", queryItems: [
            .init(name: "limit",  value: "\(limit)"),
            .init(name: "offset", value: "\(offset)")
        ])
        return try await perform(request)
    }

    func clearAlert(alertId: String) async throws {
        let request = try await postRequest(path: "/clearalerts",
                                            body: ["alert_id": alertId])
        try await performVoid(request)
    }

    // MARK: - Actions

    func rebootAP(serial: String) async throws {
        let request = try await postRequest(path: "/rebootapv1", body: ["serial": serial])
        try await performVoid(request)
    }

    func blinkAPLED(serial: String) async throws {
        let request = try await postRequest(path: "/accesspointsv1/\(serial)/action/led_flash", body: EmptyBody())
        try await performVoid(request)
    }

    func disconnectAllClientsFromAP(serial: String) async throws {
        let request = try await postRequest(path: "/accesspointsv1/\(serial)/action/disconnect_clients", body: EmptyBody())
        try await performVoid(request)
    }

    // OPEN ITEM: bounce port endpoint not confirmed in New Central MRT docs
    // func bounceSwitchPort(serial: String, port: String) async throws { ... }

    // OPEN ITEM: disconnect individual client endpoint not confirmed in New Central MRT docs
    // func disconnectClient(mac: String) async throws { ... }

    // MARK: - Settings

    func testConnection() async throws {
        let _ = try await fetchSiteHealth()
    }

    // MARK: - Search

    func searchDevices(query: String) async throws -> [SearchResult] {
        async let apsPage      = fetchAPs(site: nil, search: query, limit: 50, offset: 0)
        async let switchesPage = fetchSwitches(site: nil, search: query, limit: 50, offset: 0)
        async let clientsPage  = fetchClients(site: nil, search: query, limit: 50, offset: 0)
        let (aps, switches, clients) = try await (apsPage, switchesPage, clientsPage)
        return aps.items.map { .ap($0) }
             + switches.items.map { .switch_($0) }
             + clients.items.map { .client($0) }
    }
}

private struct EmptyResponse: Codable {}
private struct EmptyBody: Encodable {}
