import Foundation

struct AccessPoint: Codable, Identifiable, Equatable {
    let serial: String
    let name: String
    let model: String
    let status: DeviceStatus
    let ipAddress: String?
    let macAddress: String?
    let firmware: String?
    let uptime: Int?
    let site: String?
    let clientCount: Int?

    var id: String { serial }

    enum CodingKeys: String, CodingKey {
        case serial
        case name
        case model
        case status
        case ipAddress   = "ip_address"
        case macAddress  = "mac_address"
        case firmware
        case uptime
        case site        = "site_name"
        case clientCount = "client_count"
    }
}
