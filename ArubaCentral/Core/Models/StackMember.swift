import Foundation

struct StackMember: Codable, Identifiable, Equatable {
    let serial: String
    let model: String?
    let status: DeviceStatus
    let role: String?

    var id: String { serial }

    private enum CodingKeys: String, CodingKey {
        case serial = "serialNumber"
        case model
        case status
        case role   = "memberRole"
    }

    nonisolated init(from decoder: Decoder) throws {
        let c  = try decoder.container(keyedBy: CodingKeys.self)
        serial = (try? c.decode(String.self,       forKey: .serial)) ?? UUID().uuidString
        model  = try? c.decode(String.self,        forKey: .model)
        status = (try? c.decode(DeviceStatus.self, forKey: .status)) ?? .unknown
        role   = try? c.decode(String.self,        forKey: .role)
    }

    init(serial: String, model: String?, status: DeviceStatus, role: String?) {
        self.serial = serial
        self.model  = model
        self.status = status
        self.role   = role
    }
}
