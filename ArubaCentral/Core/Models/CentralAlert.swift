import Foundation

struct CentralAlert: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let severity: AlertSeverity
    let description: String?
    let deviceSerial: String?
    let site: String?
    let timestamp: Date
    let isCleared: Bool

    enum CodingKeys: String, CodingKey {
        case id          = "alert_id"
        case name        = "alert_name"
        case severity
        case description = "alert_description"
        case deviceSerial = "device_serial"
        case site        = "site_name"
        case timestamp   = "created_at"
        case isCleared   = "is_cleared"
    }
}
