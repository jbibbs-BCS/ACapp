struct SwitchInterface: Codable, Identifiable, Equatable {
    let portId: String
    let status: PortStatus
    let speed: String?
    let vlan: Int?
    let connectedDevice: String?
    let txBytes: Int?
    let rxBytes: Int?

    var id: String { portId }

    enum CodingKeys: String, CodingKey {
        case portId          = "port_id"
        case status          = "port_status"
        case speed
        case vlan
        case connectedDevice = "connected_device"
        case txBytes         = "tx_bytes"
        case rxBytes         = "rx_bytes"
    }
}
