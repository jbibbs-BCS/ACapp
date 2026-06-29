import Foundation

// Named CentralSwitch to avoid collision with Swift's switch keyword
struct CentralSwitch: Codable, Identifiable, Equatable {
    let serial: String
    let name: String
    let model: String
    let status: DeviceStatus
    let ipAddress: String?
    let macAddress: String?
    let firmware: String?
    let uptime: Int?
    let siteName: String?
    let stackId: String?

    var id: String { serial }

    enum CodingKeys: String, CodingKey {
        case serial
        case name
        case model
        case status
        case ipAddress  = "ip_address"
        case macAddress = "mac_address"
        case firmware
        case uptime
        case siteName   = "site_name"
        case stackId    = "stack_id"
    }
}
