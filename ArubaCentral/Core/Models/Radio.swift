@preconcurrency import Foundation

struct Radio: Codable, Identifiable, Equatable {
    let index: Int          // radioNumber from API
    let band: String
    let channel: Int?       // parsed from string like "153-"
    let ssid: String?
    let clientCount: Int
    let throughput: Double?

    var id: Int { index }

    private enum CodingKeys: String, CodingKey {
        case index       = "radioNumber"
        case band
        case channel
        case ssid
        case clientCount
        case throughput
    }

    init(index: Int, band: String, channel: Int?, ssid: String?,
         clientCount: Int, throughput: Double?) {
        self.index = index; self.band = band; self.channel = channel
        self.ssid = ssid; self.clientCount = clientCount; self.throughput = throughput
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        index       = (try? c.decode(Int.self, forKey: .index)) ?? 0
        band        = (try? c.decode(String.self, forKey: .band)) ?? ""
        clientCount = (try? c.decode(Int.self, forKey: .clientCount)) ?? 0
        ssid        = try? c.decode(String.self, forKey: .ssid)
        throughput  = try? c.decode(Double.self, forKey: .throughput)
        // channel arrives as "153-" or "6" — extract leading digits
        if let raw = try? c.decode(String.self, forKey: .channel) {
            channel = Int(raw.prefix(while: { $0.isNumber }))
        } else {
            channel = try? c.decode(Int.self, forKey: .channel)
        }
    }
}
