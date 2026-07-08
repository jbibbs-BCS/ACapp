@preconcurrency import Foundation

private nonisolated(unsafe) let _clientISOFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

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
    let role: String?
    let clientManufacturer: String?
    let clientFunction: String?
    let clientVendor: String?
    let clientOperatingSystem: String?
    let clientTags: String?
    let clientCategory: String?
    let wirelessBand: String?
    let wirelessChannel: Int?

    var id: String { macAddress }

    init(macAddress: String, name: String?, ipAddress: String?,
         connectionType: ClientConnectionType, associatedDeviceSerial: String?,
         site: String?, ssid: String?, vlan: Int?, port: String?,
         signalStrength: Int?, txDataRate: Double?, rxDataRate: Double?,
         connectedAt: Date?, role: String? = nil,
         clientManufacturer: String? = nil, clientFunction: String? = nil,
         clientVendor: String? = nil, clientOperatingSystem: String? = nil,
         clientTags: String? = nil, clientCategory: String? = nil,
         wirelessBand: String? = nil, wirelessChannel: Int? = nil) {
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
        self.role                   = role
        self.clientManufacturer     = clientManufacturer
        self.clientFunction         = clientFunction
        self.clientVendor           = clientVendor
        self.clientOperatingSystem  = clientOperatingSystem
        self.clientTags             = clientTags
        self.clientCategory         = clientCategory
        self.wirelessBand           = wirelessBand
        self.wirelessChannel        = wirelessChannel
    }

    private enum CodingKeys: String, CodingKey {
        case macAddress
        case name                   = "clientName"
        case ipAddress              = "ipv4"
        case connectionType         = "clientConnectionType"
        case associatedDeviceSerial = "connectedDeviceSerial"
        case siteName
        case ssid                   = "wlanName"
        case vlan                   = "vlanId"
        case port
        case signalStrength         = "snr"
        case txDataRate
        case rxDataRate
        case connectedAt
        case role
        case clientManufacturer
        case clientFunction
        case clientVendor
        case clientOperatingSystem
        case clientTags
        case clientCategory
        case wirelessBand
        case wirelessChannel
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        macAddress             = (try? c.decode(String.self, forKey: .macAddress)) ?? ""
        name                   = try? c.decode(String.self, forKey: .name)
        ipAddress              = try? c.decode(String.self, forKey: .ipAddress)
        connectionType         = (try? c.decode(ClientConnectionType.self, forKey: .connectionType)) ?? .wireless
        associatedDeviceSerial = try? c.decode(String.self, forKey: .associatedDeviceSerial)
        siteName               = try? c.decode(String.self, forKey: .siteName)
        ssid                   = try? c.decode(String.self, forKey: .ssid)
        // vlanId arrives as a String like "11"
        if let vlanStr = try? c.decode(String.self, forKey: .vlan) {
            vlan = Int(vlanStr)
        } else {
            vlan = try? c.decode(Int.self, forKey: .vlan)
        }
        port                   = try? c.decode(String.self, forKey: .port)
        signalStrength         = try? c.decode(Int.self, forKey: .signalStrength)
        txDataRate             = try? c.decode(Double.self, forKey: .txDataRate)
        rxDataRate             = try? c.decode(Double.self, forKey: .rxDataRate)
        // connectedAt is ISO 8601 e.g. "2026-06-30T15:56:07.460Z"
        if let iso = try? c.decode(String.self, forKey: .connectedAt) {
            connectedAt = _clientISOFormatter.date(from: iso)
        } else {
            connectedAt = nil
        }
        role                   = try? c.decode(String.self, forKey: .role)
        clientManufacturer     = try? c.decode(String.self, forKey: .clientManufacturer)
        clientFunction         = try? c.decode(String.self, forKey: .clientFunction)
        clientVendor           = try? c.decode(String.self, forKey: .clientVendor)
        clientOperatingSystem  = try? c.decode(String.self, forKey: .clientOperatingSystem)
        clientTags             = try? c.decode(String.self, forKey: .clientTags)
        clientCategory         = try? c.decode(String.self, forKey: .clientCategory)
        wirelessBand           = try? c.decode(String.self, forKey: .wirelessBand)
        wirelessChannel        = try? c.decode(Int.self,    forKey: .wirelessChannel)
    }
}
