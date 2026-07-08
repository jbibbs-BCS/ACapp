enum DeviceStatus: String, Codable, Equatable {
    case up = "Up"
    case down = "Down"
    case unknown = "Unknown"

    nonisolated init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw.uppercased() {
        case "UP", "ONLINE":    self = .up
        case "DOWN", "OFFLINE": self = .down
        default:                self = DeviceStatus(rawValue: raw) ?? .unknown
        }
    }
}
