import Foundation

enum APIError: Error, Equatable {
    case unauthorized
    case forbidden
    case rateLimited
    case serverError(Int)
    case networkError
    case decodingError
    case sessionExpired
    case unknown(String)

    var userMessage: String {
        switch self {
        case .unauthorized:
            return "Authentication failed — verify your Client ID and Secret in Settings."
        case .sessionExpired:
            return "Session expired — please re-authenticate in Settings."
        case .forbidden:
            return "Your account doesn't have permission to view this."
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        case .serverError(let code):
            return "Server error (\(code)). Please try again."
        case .networkError:
            return "No network connection."
        case .decodingError:
            return "Unexpected response format."
        case .unknown(let message):
            return "An unexpected error occurred: \(message)"
        }
    }
}
