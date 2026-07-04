@preconcurrency import Foundation

// Named CentralSwitch to avoid collision with Swift's switch keyword
struct CentralSwitch: Codable, Identifiable, Equatable, Hashable {
    let serial: String
    let name: String
    let model: String
    let status: DeviceStatus
    let ipAddress: String?
    let macAddress: String?
    let firmware: String?
    let uptime: Int?            // stored in seconds
    let siteName: String?
    let stackId: String?
    let switchRole: String?    // e.g. "Conductor" — the stack master
    let deployment: String?    // e.g. "Stack" vs standalone
    let stackMemberId: Int?    // member position within the stack

    var id: String { serial }

    /// True when this switch is part of a stack.
    var isStacked: Bool { stackId != nil }

    /// True when this switch is the stack conductor/master.
    var isConductor: Bool { switchRole?.caseInsensitiveCompare("Conductor") == .orderedSame }

    init(serial: String, name: String, model: String, status: DeviceStatus,
         ipAddress: String?, macAddress: String?, firmware: String?,
         uptime: Int?, site: String?, stackId: String?,
         switchRole: String? = nil, deployment: String? = nil, stackMemberId: Int? = nil) {
        self.serial     = serial
        self.name       = name
        self.model      = model
        self.status     = status
        self.ipAddress  = ipAddress
        self.macAddress = macAddress
        self.firmware   = firmware
        self.uptime     = uptime
        self.siteName   = site
        self.stackId    = stackId
        self.switchRole    = switchRole
        self.deployment    = deployment
        self.stackMemberId = stackMemberId
    }

    private enum CodingKeys: String, CodingKey {
        case serial     = "serialNumber"
        case name       = "deviceName"
        case model
        case status
        case ipAddress  = "ipv4"
        case macAddress
        case firmware   = "firmwareVersion"
        case uptimeMs   = "uptimeInMillis"
        case siteName
        case stackId
        case switchRole
        case deployment
        case stackMemberId
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        serial     = try c.decode(String.self,        forKey: .serial)
        name       = try c.decode(String.self,        forKey: .name)
        model      = try c.decode(String.self,        forKey: .model)
        status     = (try? c.decode(DeviceStatus.self, forKey: .status)) ?? .unknown
        ipAddress  = try? c.decode(String.self,       forKey: .ipAddress)
        macAddress = try? c.decode(String.self,       forKey: .macAddress)
        firmware   = try? c.decode(String.self,       forKey: .firmware)
        let ms     = try? c.decode(Int.self,          forKey: .uptimeMs)
        uptime     = ms.map { $0 / 1000 }
        siteName   = try? c.decode(String.self,       forKey: .siteName)
        stackId    = try? c.decode(String.self,       forKey: .stackId)
        switchRole    = try? c.decode(String.self, forKey: .switchRole)
        deployment    = try? c.decode(String.self, forKey: .deployment)
        stackMemberId = try? c.decode(Int.self,    forKey: .stackMemberId)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(serial, forKey: .serial)
        try c.encode(name,   forKey: .name)
        try c.encode(model,  forKey: .model)
        try c.encode(status, forKey: .status)
    }
}
