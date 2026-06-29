@preconcurrency import Foundation

struct Radio: Codable, Identifiable, Equatable {
    let index: Int
    let band: String
    let channel: Int?
    let ssid: String?
    let clientCount: Int
    let throughput: Double?

    var id: Int { index }

    enum CodingKeys: String, CodingKey {
        case index       = "radio_index"
        case band
        case channel
        case ssid
        case clientCount = "client_count"
        case throughput
    }
}
