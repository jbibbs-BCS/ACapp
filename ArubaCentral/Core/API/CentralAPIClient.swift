import Foundation
import Combine

@MainActor
final class CentralAPIClient: ObservableObject, CentralAPIClientProtocol {
    private let authManager: AuthTokenManager
    private let session: URLSession
    private let decoder: JSONDecoder

    @Published var baseURL: URL

    init(authManager: AuthTokenManager,
         session: URLSession = .shared,
         baseURL: URL = CentralRegion.defaultRegion.baseURL) {
        self.authManager = authManager
        self.session = session
        self.baseURL = baseURL
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
        let token = try await authManager.validToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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
        let request = try await buildRequest(path: "/getsitehealthv1")
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
        let request = try await buildRequest(path: "/accesspointdetailsv1",
                                             queryItems: [.init(name: "serial", value: serial)])
        return try await perform(request)
    }

    func fetchAPRadios(serial: String) async throws -> [Radio] {
        let request = try await buildRequest(path: "/accesspointradiolistv1",
                                             queryItems: [.init(name: "serial", value: serial)])
        return try await perform(request)
    }

    func fetchAPClients(serial: String, limit: Int = 100, offset: Int = 0) async throws -> PaginatedResponse<CentralClient> {
        let request = try await buildRequest(path: "/listunifiedclients", queryItems: [
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
        let request = try await buildRequest(path: "/switchv1",
                                             queryItems: [.init(name: "serial", value: serial)])
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
        let request = try await buildRequest(path: "/listunifiedclients", queryItems: items)
        return try await perform(request)
    }

    func fetchClientDetail(macAddress: String) async throws -> CentralClient {
        let request = try await buildRequest(path: "/getclientdetails",
                                             queryItems: [.init(name: "mac_address", value: macAddress)])
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
        let request = try await postRequest(path: "/locateapv1", body: ["serial": serial])
        try await performVoid(request)
    }

    func disconnectAllClientsFromAP(serial: String) async throws {
        let request = try await postRequest(path: "/disconnectallusersapv1", body: ["serial": serial])
        try await performVoid(request)
    }

    // MARK: - Settings

    func testConnection() async throws {
        let _ = try await fetchSiteHealth()
    }
}

private struct EmptyResponse: Codable {}
