import Foundation

struct Site: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let healthScore: Int
    let apCount: Int
    let switchCount: Int
    let clientCount: Int

    var healthLevel: HealthLevel {
        switch healthScore {
        case 80...100: return .good
        case 50...79:  return .warning
        default:       return .critical
        }
    }

    enum CodingKeys: String, CodingKey {
        case id           = "site_id"
        case name         = "site_name"
        case healthScore  = "health_score"
        case apCount      = "ap_count"
        case switchCount  = "switch_count"
        case clientCount  = "client_count"
    }
}
