@preconcurrency import Foundation

struct CentralAlert: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let severity: AlertSeverity
    let description: String?
    let deviceSerial: String?
    let siteName: String?
    let createdAt: Date
    let isCleared: Bool

    enum CodingKeys: String, CodingKey {
        case id          = "alert_id"
        case name        = "alert_name"
        case severity
        case description = "alert_description"
        case deviceSerial = "device_serial"
        case siteName    = "site_name"
        case createdAt   = "created_at"
        case isCleared   = "is_cleared"
    }
}
