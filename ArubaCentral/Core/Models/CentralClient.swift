@preconcurrency import Foundation

struct CentralClient: Codable, Identifiable, Equatable, Hashable {
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

    /// Memberwise init using `site:` label for the site name (mirrors `AccessPoint` init style).
    init(macAddress: String, name: String?, ipAddress: String?,
         connectionType: ClientConnectionType, associatedDeviceSerial: String?,
         site: String?, ssid: String?, vlan: Int?, port: String?,
         signalStrength: Int?, txDataRate: Double?, rxDataRate: Double?,
         connectedAt: Date?) {
        self.macAddress             = macAddress
        self.name                   = name
        self.ipAddress              = ipAddress
        self.connectionType         = connectionType
        self.associatedDeviceSerial = associatedDeviceSerial
        self.siteName               = site
        self.ssid                   = ssid
        self.vlan                   = vlan
        self.port                   = port
        self.signalStrength         = signalStrength
        self.txDataRate             = txDataRate
        self.rxDataRate             = rxDataRate
        self.connectedAt            = connectedAt
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        macAddress             = try c.decode(String.self,             forKey: .macAddress)
        name                   = try c.decodeIfPresent(String.self,    forKey: .name)
        ipAddress              = try c.decodeIfPresent(String.self,    forKey: .ipAddress)
        connectionType         = try c.decode(ClientConnectionType.self, forKey: .connectionType)
        associatedDeviceSerial = try c.decodeIfPresent(String.self,    forKey: .associatedDeviceSerial)
        siteName               = try c.decodeIfPresent(String.self,    forKey: .siteName)
        ssid                   = try c.decodeIfPresent(String.self,    forKey: .ssid)
        vlan                   = try c.decodeIfPresent(Int.self,       forKey: .vlan)
        port                   = try c.decodeIfPresent(String.self,    forKey: .port)
        signalStrength         = try c.decodeIfPresent(Int.self,       forKey: .signalStrength)
        txDataRate             = try c.decodeIfPresent(Double.self,    forKey: .txDataRate)
        rxDataRate             = try c.decodeIfPresent(Double.self,    forKey: .rxDataRate)
        connectedAt            = try c.decodeIfPresent(Date.self,      forKey: .connectedAt)
    }

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
