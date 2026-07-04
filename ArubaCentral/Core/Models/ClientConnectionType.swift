enum ClientConnectionType: String, Codable, Equatable {
    case wireless = "WIRELESS"
    case wired = "WIRED"

    nonisolated init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ClientConnectionType(rawValue: raw.uppercased()) ?? .wireless
    }
}
