import Foundation

struct SwitchInterface: Codable, Identifiable, Equatable {
    let portId: String
    let status: PortStatus
    let speed: Int?             // Mbps (per API)
    let vlan: Int?             // nativeVlan
    let neighbour: String?     // connected device name (LLDP neighbour)
    let neighbourRole: String?
    let allowedVlanIds: [Int]?
    let description: String?
    let txBytes: Int?
    let rxBytes: Int?

    var id: String { portId }

    private enum CodingKeys: String, CodingKey {
        case portId          = "id"
        case status          = "operStatus"
        case speed
        case vlan            = "nativeVlan"
        case neighbour
        case neighbourRole
        case allowedVlanIds
        case description
        case txBytes
        case rxBytes
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        portId          = (try? c.decode(String.self, forKey: .portId)) ?? UUID().uuidString
        status          = (try? c.decode(PortStatus.self, forKey: .status)) ?? .down
        speed           = try? c.decode(Int.self, forKey: .speed)
        vlan            = try? c.decode(Int.self, forKey: .vlan)
        let n           = (try? c.decode(String.self, forKey: .neighbour)) ?? ""
        neighbour       = n.isEmpty ? nil : n
        neighbourRole   = try? c.decode(String.self, forKey: .neighbourRole)
        allowedVlanIds  = try? c.decode([Int].self, forKey: .allowedVlanIds)
        let desc        = (try? c.decode(String.self, forKey: .description)) ?? ""
        description     = desc.isEmpty ? nil : desc
        txBytes         = try? c.decode(Int.self, forKey: .txBytes)
        rxBytes         = try? c.decode(Int.self, forKey: .rxBytes)
    }

    init(portId: String, status: PortStatus, speed: Int?, vlan: Int?,
         neighbour: String?, neighbourRole: String? = nil,
         allowedVlanIds: [Int]? = nil, description: String? = nil,
         txBytes: Int?, rxBytes: Int?) {
        self.portId = portId; self.status = status; self.speed = speed
        self.vlan = vlan; self.neighbour = neighbour
        self.neighbourRole = neighbourRole; self.allowedVlanIds = allowedVlanIds
        self.description = description
        self.txBytes = txBytes; self.rxBytes = rxBytes
    }
}
