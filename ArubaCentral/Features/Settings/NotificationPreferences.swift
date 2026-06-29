import Foundation

struct NotificationPreferences: Codable, Equatable {
    var critical: Bool = true
    var major:    Bool = true
    var minor:    Bool = false
    var info:     Bool = false

    static let defaultKey = "notificationPreferences"

    static func load() -> NotificationPreferences {
        guard let data = UserDefaults.standard.data(forKey: defaultKey),
              let prefs = try? JSONDecoder().decode(NotificationPreferences.self, from: data)
        else { return NotificationPreferences() }
        return prefs
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: NotificationPreferences.defaultKey)
    }

    func isEnabled(for severity: AlertSeverity) -> Bool {
        switch severity {
        case .critical: return critical
        case .major:    return major
        case .minor:    return minor
        case .info:     return info
        }
    }
}
