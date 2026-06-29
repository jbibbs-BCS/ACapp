@preconcurrency import Foundation

struct AccessPoint: Codable, Identifiable, Equatable, Hashable {
    let serial: String
    let name: String
    let model: String
    let status: DeviceStatus
    let ipAddress: String?
    let macAddress: String
    let firmware: String?
    let uptime: Int?
    let siteName: String?
    let clientCount: Int?

    var id: String { serial }

    /// Memberwise init using `site` label for the site name (mirrors `CentralSwitch` init style).
    init(serial: String, name: String, model: String, status: DeviceStatus,
         ipAddress: String?, macAddress: String, firmware: String?,
         uptime: Int?, site: String?, clientCount: Int?) {
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
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        serial      = try c.decode(String.self,       forKey: .serial)
        name        = try c.decode(String.self,       forKey: .name)
        model       = try c.decode(String.self,       forKey: .model)
        status      = try c.decode(DeviceStatus.self, forKey: .status)
        ipAddress   = try c.decodeIfPresent(String.self, forKey: .ipAddress)
        macAddress  = try c.decode(String.self,       forKey: .macAddress)
        firmware    = try c.decodeIfPresent(String.self, forKey: .firmware)
        uptime      = try c.decodeIfPresent(Int.self,    forKey: .uptime)
        siteName    = try c.decodeIfPresent(String.self, forKey: .siteName)
        clientCount = try c.decodeIfPresent(Int.self,    forKey: .clientCount)
    }

    enum CodingKeys: String, CodingKey {
        case serial
        case name
        case model
        case status
        case ipAddress   = "ip_address"
        case macAddress  = "mac_address"
        case firmware
        case uptime
        case siteName    = "site_name"
        case clientCount = "client_count"
    }
}
