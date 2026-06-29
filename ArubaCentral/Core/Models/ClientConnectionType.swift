enum ClientConnectionType: String, Codable, Equatable {
    case wireless = "WIRELESS"
    case wired = "WIRED"

    nonisolated init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let value = ClientConnectionType(rawValue: raw) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unknown connection type: \(raw)")
            )
        }
        self = value
    }
}
