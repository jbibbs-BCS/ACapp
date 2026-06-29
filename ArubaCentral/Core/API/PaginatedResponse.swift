struct PaginatedResponse<T: Codable>: Codable {
    let items: [T]
    let total: Int
    let offset: Int
    let limit: Int

    var hasMore: Bool { total > offset + items.count }
}
