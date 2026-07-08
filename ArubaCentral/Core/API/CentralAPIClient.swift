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
        // Defense-in-depth (N-2): only accept a base URL from the region allowlist, so no
        // attacker-influenced value could ever aim the client (and its Bearer token) elsewhere.
        guard CentralRegion.all.contains(where: { $0.baseURL == url }) else { return }
        baseURL = url
    }

    // MARK: - Private helpers

    // Interpolated path segments (serials, etc.) must be percent-encoded via `pathSegment`
    // at the call site so they can't smuggle path/query separators (A-2). The `path` passed
    // here is treated as already-safe literal structure plus pre-encoded segments.
    private static let pathSegmentAllowed = CharacterSet(charactersIn:
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    // Hard cap on search pagination (A-4): 50 pages × 100 = 5,000 items. Prevents a hostile
    // or looping `next` cursor from driving an unbounded fetch / memory-exhaustion DoS.
    private static let maxSearchPages = 50

    /// Percent-encode one variable path segment; reject empty. (A-2)
    private func pathSegment(_ raw: String) throws -> String {
        guard let enc = raw.addingPercentEncoding(withAllowedCharacters: Self.pathSegmentAllowed),
              !enc.isEmpty else { throw APIError.invalidRequest }
        return enc
    }

    /// OData string-literal escaping: a single quote is doubled. (A-3)
    private func odataEscaped(_ s: String) -> String {
        s.replacingOccurrences(of: "'", with: "''")
    }

    private func buildRequest(path: String, queryItems: [URLQueryItem] = []) async throws -> URLRequest {
        let base = baseURL.absoluteString.hasSuffix("/")
            ? String(baseURL.absoluteString.dropLast())
            : baseURL.absoluteString
        let normalizedPath = path.hasPrefix("/") ? path : "/" + path
        // Guarded construction (A-1): throw rather than trap on a malformed URL.
        guard var components = URLComponents(string: base + normalizedPath) else {
            throw APIError.invalidRequest
        }
        if !queryItems.isEmpty { components.queryItems = queryItems }
        guard let url = components.url else { throw APIError.invalidRequest }
        var request = URLRequest(url: url)
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
        let items: [Site]
        let next: String?
    }

    private struct APListResponse: Decodable {
        let items: [AccessPoint]
        let next: String?
    }

    private struct SwitchListResponse: Decodable {
        let items: [CentralSwitch]
        let next: String?
    }

    private struct ClientListResponse: Decodable {
        let items: [CentralClient]
        let total: Int?
        let next: String?
    }

    private struct AlertListResponse: Decodable {
        let items: [CentralAlert]
        let next: String?
    }

    private struct RadioListResponse: Decodable {
        let items: [Radio]
    }

    private struct SwitchInterfaceListResponse: Decodable {
        let items: [SwitchInterface]

        private enum CodingKeys: String, CodingKey { case items, interfaces }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            items = (try? c.decode([SwitchInterface].self, forKey: .items))
                 ?? (try? c.decode([SwitchInterface].self, forKey: .interfaces))
                 ?? []
        }
    }

    private struct VLANListResponse: Decodable {
        let items: [VLAN]

        private enum CodingKeys: String, CodingKey { case items, vlans }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            items = (try? c.decode([VLAN].self, forKey: .items))
                 ?? (try? c.decode([VLAN].self, forKey: .vlans))
                 ?? []
        }
    }

    private struct StackMemberListResponse: Decodable {
        let members: [StackMember]

        private enum CodingKeys: String, CodingKey { case members, items }

        init(from decoder: Decoder) throws {
            let c   = try decoder.container(keyedBy: CodingKeys.self)
            members = (try? c.decode([StackMember].self, forKey: .members))
                   ?? (try? c.decode([StackMember].self, forKey: .items))
                   ?? []
        }
    }

    // MARK: - Sites

    func fetchSiteHealth() async throws -> [Site] {
        let request = try await buildRequest(path: "/network-monitoring/v1/sites-health")
        let response: SiteHealthListResponse = try await perform(request)
        return response.items
    }

    // MARK: - APs

    func fetchAPs(site: String? = nil, search: String? = nil,
                  limit: Int = 100, next: String? = nil) async throws -> PaginatedResponse<AccessPoint> {
        var queryItems: [URLQueryItem] = [.init(name: "limit", value: "\(limit)")]
        if let next { queryItems.append(.init(name: "next", value: next)) }
        var filters: [String] = []
        if let site { filters.append("siteName eq '\(odataEscaped(site))'") }
        if !filters.isEmpty { queryItems.append(.init(name: "filter", value: filters.joined(separator: " and "))) }
        let request = try await buildRequest(path: "/network-monitoring/v1/aps", queryItems: queryItems)
        let response: APListResponse = try await perform(request)
        return PaginatedResponse(items: response.items, total: nil, next: response.next)
    }

    func fetchAPDetail(serial: String) async throws -> AccessPoint {
        let request = try await buildRequest(path: "/network-monitoring/v1/aps/\(try pathSegment(serial))")
        return try await perform(request)
    }

    func fetchAPRadios(serial: String) async throws -> [Radio] {
        let request = try await buildRequest(path: "/network-monitoring/v1/aps/\(try pathSegment(serial))/radios")
        let response: RadioListResponse = try await perform(request)
        return response.items
    }

    func fetchAPClients(serial: String, limit: Int = 100, next: String? = nil) async throws -> PaginatedResponse<CentralClient> {
        // The clients endpoint has no per-device filter. Fetch up to 5 pages
        // sequentially and match client-side on connectedDeviceSerial.
        var all: [CentralClient] = []
        var cursor: String? = nil
        for _ in 1...5 {
            var qi: [URLQueryItem] = [.init(name: "limit", value: "\(limit)")]
            if let cursor { qi.append(.init(name: "next", value: cursor)) }
            let response: ClientListResponse = try await perform(
                try await buildRequest(path: "/network-monitoring/v1/clients", queryItems: qi)
            )
            all.append(contentsOf: response.items)
            cursor = response.next
            if cursor == nil { break }
        }
        let filtered = all.filter { $0.associatedDeviceSerial == serial }
        return PaginatedResponse(items: filtered, total: filtered.count, next: nil)
    }

    // MARK: - Switches

    func fetchSwitches(site: String? = nil, search: String? = nil,
                       limit: Int = 100, next: String? = nil) async throws -> PaginatedResponse<CentralSwitch> {
        var queryItems: [URLQueryItem] = [.init(name: "limit", value: "\(limit)")]
        if let next { queryItems.append(.init(name: "next", value: next)) }
        var filters: [String] = []
        if let site { filters.append("siteName eq '\(odataEscaped(site))'") }
        if !filters.isEmpty { queryItems.append(.init(name: "filter", value: filters.joined(separator: " and "))) }
        let request = try await buildRequest(path: "/network-monitoring/v1/switches", queryItems: queryItems)
        let response: SwitchListResponse = try await perform(request)
        return PaginatedResponse(items: response.items, total: nil, next: response.next)
    }

    func fetchSwitchDetail(serial: String) async throws -> CentralSwitch {
        let request = try await buildRequest(path: "/network-monitoring/v1/switches/\(try pathSegment(serial))")
        return try await perform(request)
    }

    func fetchSwitchInterfaces(serial: String) async throws -> [SwitchInterface] {
        let request = try await buildRequest(path: "/network-monitoring/v1/switches/\(try pathSegment(serial))/interfaces")
        let response: SwitchInterfaceListResponse = try await perform(request)
        return response.items
    }

    func fetchSwitchVLANs(serial: String) async throws -> [VLAN] {
        let request = try await buildRequest(path: "/network-monitoring/v1/switches/\(try pathSegment(serial))/vlans")
        let response: VLANListResponse = try await perform(request)
        return response.items
    }

    func fetchStackMembers(serial: String) async throws -> [StackMember] {
        let request = try await buildRequest(path: "/network-monitoring/v1/stack/\(try pathSegment(serial))/members")
        let response: StackMemberListResponse = try await perform(request)
        return response.members
    }

    // MARK: - Clients

    func fetchClients(site: String? = nil, search: String? = nil,
                      limit: Int = 100, next: String? = nil) async throws -> PaginatedResponse<CentralClient> {
        var queryItems: [URLQueryItem] = [.init(name: "limit", value: "\(limit)")]
        if let next { queryItems.append(.init(name: "next", value: next)) }
        let request = try await buildRequest(path: "/network-monitoring/v1/clients", queryItems: queryItems)
        let response: ClientListResponse = try await perform(request)
        var items = response.items
        if let site   { items = items.filter { $0.siteName == site } }
        if let search { items = items.filter { ($0.name ?? "").localizedCaseInsensitiveContains(search) } }
        return PaginatedResponse(items: items, total: items.count, next: response.next)
    }

    // MARK: - Alerts

    func fetchAlerts(limit: Int = 100, next: String? = nil) async throws -> PaginatedResponse<CentralAlert> {
        var queryItems: [URLQueryItem] = [.init(name: "limit", value: "\(limit)")]
        if let next { queryItems.append(.init(name: "next", value: next)) }
        let request = try await buildRequest(path: "/network-notifications/v1/alerts", queryItems: queryItems)
        let response: AlertListResponse = try await perform(request)
        return PaginatedResponse(items: response.items, total: nil, next: response.next)
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
        let request = try await postRequest(path: "/network-troubleshooting/v1alpha1/aps/\(try pathSegment(serial))/reboot",
                                            body: EmptyBody())
        try await performVoid(request)
    }

    func blinkAPLED(serial: String) async throws {
        let request = try await postRequest(path: "/network-troubleshooting/v1alpha1/aps/\(try pathSegment(serial))/locate",
                                            body: EmptyBody())
        try await performVoid(request)
    }

    func disconnectAllClientsFromAP(serial: String) async throws {
        let request = try await postRequest(path: "/network-troubleshooting/v1alpha1/aps/\(try pathSegment(serial))/disconnect-clients",
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
        let q = query.lowercased()
        async let apsFetch      = fetchAllPages_APs()
        async let switchesFetch = fetchAllPages_Switches()
        async let clientsFetch  = fetchAllPages_Clients()
        let (aps, switches, clients) = try await (apsFetch, switchesFetch, clientsFetch)
        return aps.filter {
                    $0.name.lowercased().contains(q) ||
                    ($0.ipAddress ?? "").contains(q) ||
                    $0.macAddress.lowercased().contains(q)
               }.map { .ap($0) }
             + switches.filter {
                    $0.name.lowercased().contains(q) ||
                    ($0.ipAddress ?? "").contains(q) ||
                    ($0.macAddress ?? "").lowercased().contains(q)
               }.map { .switch_($0) }
             + clients.filter {
                    ($0.name ?? "").lowercased().contains(q) ||
                    ($0.ipAddress ?? "").contains(q) ||
                    $0.macAddress.lowercased().contains(q)
               }.map { .client($0) }
    }

    private func fetchAllPages_APs() async throws -> [AccessPoint] {
        var all: [AccessPoint] = []
        var cursor: String? = nil
        var pages = 0
        repeat {
            let page = try await fetchAPs(site: nil, search: nil, limit: 100, next: cursor)
            all.append(contentsOf: page.items)
            cursor = page.next
            pages += 1
        } while cursor != nil && pages < Self.maxSearchPages
        return all
    }

    private func fetchAllPages_Switches() async throws -> [CentralSwitch] {
        var all: [CentralSwitch] = []
        var cursor: String? = nil
        var pages = 0
        repeat {
            let page = try await fetchSwitches(site: nil, search: nil, limit: 100, next: cursor)
            all.append(contentsOf: page.items)
            cursor = page.next
            pages += 1
        } while cursor != nil && pages < Self.maxSearchPages
        return all
    }

    private func fetchAllPages_Clients() async throws -> [CentralClient] {
        var all: [CentralClient] = []
        var cursor: String? = nil
        var pages = 0
        repeat {
            let page = try await fetchClients(site: nil, search: nil, limit: 100, next: cursor)
            all.append(contentsOf: page.items)
            cursor = page.next
            pages += 1
        } while cursor != nil && pages < Self.maxSearchPages
        return all
    }
}

private struct EmptyResponse: Codable {}
private struct EmptyBody: Encodable {}
private struct ClearAlertsBody: Encodable {
    let alertKeys: [String]
}
