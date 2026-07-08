@preconcurrency import Foundation

struct PaginatedResponse<T: Codable>: Codable {
    let items: [T]
    let total: Int?
    let next: String?

    var hasMore: Bool { next != nil && !(next ?? "").isEmpty }
}
