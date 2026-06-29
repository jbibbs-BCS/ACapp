enum DeviceStatus: String, Codable, Equatable {
    case up = "Up"
    case down = "Down"
    case unknown = "Unknown"

    nonisolated init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = DeviceStatus(rawValue: raw) ?? .unknown
    }
}
