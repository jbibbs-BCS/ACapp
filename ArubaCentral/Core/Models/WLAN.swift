import Foundation

/// A WLAN (SSID) advertised by an access point, from the AP detail `wlans` array.
struct WLAN: Codable, Equatable, Hashable, Identifiable {
    let wlanName: String      // shown as "SSID"
    let band: String?         // e.g. "5 GHz"
    let vlan: String?         // e.g. "11"
    let status: String?       // "ENABLED" / "DISABLED"

    // An SSID can appear on more than one band, so the id includes the band.
    var id: String { "\(wlanName)|\(band ?? "")" }

    var isEnabled: Bool { status?.caseInsensitiveCompare("ENABLED") == .orderedSame }

    private enum CodingKeys: String, CodingKey {
        case wlanName, band, vlan, status
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        wlanName = (try? c.decode(String.self, forKey: .wlanName)) ?? ""
        band     = try? c.decode(String.self, forKey: .band)
        vlan     = try? c.decode(String.self, forKey: .vlan)
        status   = try? c.decode(String.self, forKey: .status)
    }

    init(wlanName: String, band: String?, vlan: String?, status: String?) {
        self.wlanName = wlanName
        self.band     = band
        self.vlan     = vlan
        self.status   = status
    }
}
