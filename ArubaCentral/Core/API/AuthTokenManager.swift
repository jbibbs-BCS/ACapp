import Foundation
import Combine

@MainActor
final class AuthTokenManager: ObservableObject {
    private let keychain = KeychainManager.shared
    private let tokenURL = URL(string: "https://sso.common.cloud.hpe.com/as/token.oauth2")!
    private let session: URLSession
    private let refreshBuffer: TimeInterval = 60

    @Published private(set) var isAuthenticated = false

    init(session: URLSession = .shared) {
        self.session = session
        isAuthenticated = (try? keychain.retrieve(for: .accessToken)) != nil
    }

    func validToken() async throws -> String {
        if let token = try? keychain.retrieve(for: .accessToken),
           let expiryString = try? keychain.retrieve(for: .tokenExpiry),
           let expiry = Double(expiryString),
           Date().timeIntervalSince1970 < expiry - refreshBuffer {
            return token
        }
        return try await fetchNewToken()
    }

    @discardableResult
    func fetchNewToken() async throws -> String {
        let clientId     = try keychain.retrieve(for: .clientId)
        let clientSecret = try keychain.retrieve(for: .clientSecret)

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "grant_type",    value: "client_credentials"),
            URLQueryItem(name: "client_id",     value: clientId),
            URLQueryItem(name: "client_secret", value: clientSecret)
        ]
        let body = components.percentEncodedQuery ?? ""
        request.httpBody = body.data(using: .utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.networkError }
        guard http.statusCode == 200 else { throw APIError.unauthorized }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        let expiry = Date().timeIntervalSince1970 + Double(tokenResponse.expiresIn)

        try keychain.save(tokenResponse.accessToken, for: .accessToken)
        try keychain.save(String(expiry), for: .tokenExpiry)

        isAuthenticated = true
        return tokenResponse.accessToken
    }

    func clearCredentials() {
        KeychainManager.Key.allCases.forEach { keychain.delete(for: $0) }
        isAuthenticated = false
    }
}

private struct TokenResponse: Codable {
    let accessToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn   = "expires_in"
    }
}
