@preconcurrency import Foundation

private nonisolated(unsafe) let _alertISOFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

struct CentralAlert: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let severity: AlertSeverity
    let description: String?      // API key "summary"
    let category: String?
    let deviceType: String?
    let priority: String?
    let status: String?          // "Active" / "Cleared" / "Deferred"
    let clearedReason: String?
    let deviceSerial: String?    // not present in list API; retained for compatibility
    let siteName: String?        // not present in list API; retained for compatibility
    let createdAt: Date
    let updatedAt: Date?
    var isCleared: Bool          // derived from `status == "Cleared"`

    // Explicit init for tests and previews
    init(id: String, name: String, severity: AlertSeverity,
         description: String? = nil, deviceSerial: String? = nil,
         siteName: String? = nil, createdAt: Date = Date(), isCleared: Bool = false,
         category: String? = nil, deviceType: String? = nil, priority: String? = nil,
         status: String? = nil, clearedReason: String? = nil, updatedAt: Date? = nil) {
        self.id = id; self.name = name; self.severity = severity
        self.description = description; self.deviceSerial = deviceSerial
        self.siteName = siteName; self.createdAt = createdAt; self.isCleared = isCleared
        self.category = category; self.deviceType = deviceType; self.priority = priority
        self.status = status; self.clearedReason = clearedReason; self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, severity, category, deviceType, priority, status
        case description  = "summary"
        case clearedReason
        case deviceSerial = "device_serial"
        case siteName     = "site_name"
        case createdAt
        case updatedAt
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(String.self, forKey: .id)
        name          = try c.decode(String.self, forKey: .name)
        severity      = (try? c.decode(AlertSeverity.self, forKey: .severity)) ?? .info
        description   = try? c.decode(String.self, forKey: .description)
        category      = try? c.decode(String.self, forKey: .category)
        deviceType    = try? c.decode(String.self, forKey: .deviceType)
        priority      = try? c.decode(String.self, forKey: .priority)
        let stateStr  = try? c.decode(String.self, forKey: .status)
        status        = stateStr
        clearedReason = try? c.decode(String.self, forKey: .clearedReason)
        deviceSerial  = try? c.decode(String.self, forKey: .deviceSerial)
        siteName      = try? c.decode(String.self, forKey: .siteName)

        // createdAt is ISO 8601 e.g. "2025-12-10T07:04:33.352Z"; tolerate epoch seconds too.
        if let iso = try? c.decode(String.self, forKey: .createdAt),
           let date = _alertISOFormatter.date(from: iso) {
            createdAt = date
        } else {
            createdAt = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
        }
        // updatedAt may be an empty string when the alert has never been updated.
        if let iso = try? c.decode(String.self, forKey: .updatedAt), !iso.isEmpty {
            updatedAt = _alertISOFormatter.date(from: iso)
        } else {
            updatedAt = nil
        }

        isCleared = (stateStr?.caseInsensitiveCompare("Cleared") == .orderedSame)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(severity, forKey: .severity)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(category, forKey: .category)
        try c.encodeIfPresent(deviceType, forKey: .deviceType)
        try c.encodeIfPresent(priority, forKey: .priority)
        try c.encodeIfPresent(status, forKey: .status)
        try c.encodeIfPresent(clearedReason, forKey: .clearedReason)
        try c.encodeIfPresent(deviceSerial, forKey: .deviceSerial)
        try c.encodeIfPresent(siteName, forKey: .siteName)
        try c.encode(_alertISOFormatter.string(from: createdAt), forKey: .createdAt)
        if let updatedAt { try c.encode(_alertISOFormatter.string(from: updatedAt), forKey: .updatedAt) }
    }
}
