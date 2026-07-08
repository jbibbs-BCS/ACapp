@preconcurrency import Foundation

struct AccessPoint: Codable, Identifiable, Equatable, Hashable {
    let serial: String
    let name: String
    let model: String
    let status: DeviceStatus
    let ipAddress: String?
    let macAddress: String
    let firmware: String?
    let uptime: Int?            // stored in seconds
    let siteName: String?
    let clientCount: Int?
    let wlans: [WLAN]?

    var id: String { serial }

    /// WLANs whose status is ENABLED (detail endpoint only; empty otherwise).
    var enabledWLANs: [WLAN] { wlans?.filter(\.isEnabled) ?? [] }

    init(serial: String, name: String, model: String, status: DeviceStatus,
         ipAddress: String?, macAddress: String, firmware: String?,
         uptime: Int?, site: String?, clientCount: Int?, wlans: [WLAN]? = nil) {
        self.serial      = serial
        self.name        = name
        self.model       = model
        self.status      = status
        self.ipAddress   = ipAddress
        self.macAddress  = macAddress
        self.firmware    = firmware
        self.uptime      = uptime
        self.siteName    = site
        self.clientCount = clientCount
        self.wlans       = wlans
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case serial      = "serialNumber"
        case name        = "deviceName"
        case model
        case status
        case ipAddress   = "ipv4"
        case macAddress
        case firmware    = "firmwareVersion"
        case uptimeMs    = "uptimeInMillis"
        case siteName
        case clientCount
        case wlans
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Detail endpoint uses "id"; list endpoint has both "serialNumber" and "id"
        if let s = try? c.decode(String.self, forKey: .serial) {
            serial = s
        } else {
            serial = try c.decode(String.self, forKey: .id)
        }
        name = (try? c.decode(String.self, forKey: .name)) ?? serial
        model       = (try? c.decode(String.self,     forKey: .model)) ?? ""
        status      = (try? c.decode(DeviceStatus.self, forKey: .status)) ?? .unknown
        ipAddress   = try? c.decode(String.self,      forKey: .ipAddress)
        macAddress  = (try? c.decode(String.self,     forKey: .macAddress)) ?? ""
        firmware    = try? c.decode(String.self,      forKey: .firmware)
        let ms      = try? c.decode(Int.self,         forKey: .uptimeMs)
        uptime      = ms.map { $0 / 1000 }
        siteName    = try? c.decode(String.self,      forKey: .siteName)
        clientCount = try? c.decode(Int.self,         forKey: .clientCount)
        wlans       = try? c.decode([WLAN].self,      forKey: .wlans)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(serial,  forKey: .serial)
        try c.encode(name,    forKey: .name)
        try c.encode(model,   forKey: .model)
        try c.encode(status,  forKey: .status)
    }
}
