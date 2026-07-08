import Foundation

struct Site: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let healthPct: Int      // % of health groups rated "Good" (0–100)
    let deviceCount: Int    // total devices at site
    let clientCount: Int    // total connected clients
    let alertCount: Int     // total active alerts
    let upDeviceCount: Int  // good + fair devices (from devices.health.groups)

    var healthLevel: HealthLevel {
        switch healthPct {
        case 80...100: return .good
        case 50...79:  return .warning
        default:       return .critical
        }
    }

    var goodDeviceCount: Int { Int((Double(deviceCount) * Double(healthPct) / 100).rounded()) }

    // Explicit init for tests and previews (API decoding uses init(from:) below)
    init(id: String, name: String, healthPct: Int,
         deviceCount: Int, clientCount: Int, alertCount: Int = 0,
         upDeviceCount: Int? = nil) {
        self.id = id; self.name = name; self.healthPct = healthPct
        self.deviceCount = deviceCount; self.clientCount = clientCount
        self.alertCount = alertCount
        self.upDeviceCount = upDeviceCount ?? deviceCount
    }
}

extension Site {
    private struct HealthGroup: Decodable {
        let name: String
        let value: Int
    }
    private struct HealthContainer: Decodable {
        let groups: [HealthGroup]
    }
    private struct CountContainer: Decodable {
        let count: Int
    }
    // devices/clients carry a nested health whose group `value`s are COUNTS
    // (unlike the top-level `health`, whose values are percentages).
    private struct DeviceHealthContainer: Decodable {
        let count: Int
        let health: HealthContainer?
    }
    private struct AlertsContainer: Decodable {
        let totalCount: Int
    }

    enum CodingKeys: String, CodingKey {
        case id, health, devices, clients, alerts
        case name = "siteName"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id   = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        let hlth = try c.decode(HealthContainer.self, forKey: .health)
        healthPct    = hlth.groups.first(where: { $0.name == "Good" })?.value ?? 0
        let devicesObj = try? c.decode(DeviceHealthContainer.self, forKey: .devices)
        deviceCount  = devicesObj?.count ?? 0
        // devices.health group values are device counts; "up" = Good + Fair.
        let deviceGroups = devicesObj?.health?.groups ?? []
        func deviceHealthCount(_ groupName: String) -> Int {
            deviceGroups.first(where: { $0.name == groupName })?.value ?? 0
        }
        upDeviceCount = deviceHealthCount("Good") + deviceHealthCount("Fair")
        clientCount  = (try? c.decode(CountContainer.self, forKey: .clients))?.count ?? 0
        alertCount   = (try? c.decode(AlertsContainer.self, forKey: .alerts))?.totalCount ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,   forKey: .id)
        try c.encode(name, forKey: .name)
    }
}
