import Foundation

struct CentralClient: Codable, Identifiable, Equatable {
    let macAddress: String
    let name: String?
    let ipAddress: String?
    let connectionType: ClientConnectionType
    let associatedDeviceSerial: String?
    let siteName: String?
    let ssid: String?
    let vlan: Int?
    let port: String?
    let signalStrength: Int?
    let txDataRate: Double?
    let rxDataRate: Double?
    let connectedAt: Date?

    var id: String { macAddress }

    enum CodingKeys: String, CodingKey {
        case macAddress            = "mac_address"
        case name
        case ipAddress             = "ip_address"
        case connectionType        = "client_type"
        case associatedDeviceSerial = "associated_device"
        case siteName              = "site_name"
        case ssid
        case vlan
        case port
        case signalStrength        = "signal_strength"
        case txDataRate            = "tx_data_rate"
        case rxDataRate            = "rx_data_rate"
        case connectedAt           = "connected_at"
    }
}
