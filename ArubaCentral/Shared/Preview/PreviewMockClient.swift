import Foundation

#if DEBUG
final class PreviewMockClient: CentralAPIClientProtocol {

    // MARK: - Sites

    func fetchSiteHealth() async throws -> [Site] {
        [
            Site(id: "s1", name: "HQ Campus",     healthPct: 95, deviceCount: 28, clientCount: 310, alertCount: 0),
            Site(id: "s2", name: "Branch Office",  healthPct: 62, deviceCount: 10, clientCount: 47,  alertCount: 2),
            Site(id: "s3", name: "Warehouse",      healthPct: 15, deviceCount: 5,  clientCount: 12,  alertCount: 5),
        ]
    }

    // MARK: - APs

    func fetchAPs(site: String?, search: String?, limit: Int, next: String?) async throws -> PaginatedResponse<AccessPoint> {
        let aps = [
            AccessPoint(serial: "AP001", name: "AP-Lobby",    model: "AP-515",  status: .up,
                        ipAddress: "10.0.1.10", macAddress: "AA:BB:CC:DD:EE:01",
                        firmware: "10.4.1.0", uptime: 864000, site: site ?? "HQ Campus", clientCount: 24),
            AccessPoint(serial: "AP002", name: "AP-Conf-A",   model: "AP-535",  status: .up,
                        ipAddress: "10.0.1.11", macAddress: "AA:BB:CC:DD:EE:02",
                        firmware: "10.4.1.0", uptime: 432000, site: site ?? "HQ Campus", clientCount: 12),
            AccessPoint(serial: "AP003", name: "AP-Cafeteria", model: "AP-615", status: .down,
                        ipAddress: nil,         macAddress: "AA:BB:CC:DD:EE:03",
                        firmware: "10.3.0.0", uptime: nil,    site: site ?? "HQ Campus", clientCount: 0),
            AccessPoint(serial: "AP004", name: "AP-Parking",  model: "AP-505H", status: .up,
                        ipAddress: "10.0.1.13", macAddress: "AA:BB:CC:DD:EE:04",
                        firmware: "10.4.1.0", uptime: 172800, site: site ?? "HQ Campus", clientCount: 4),
        ]
        return PaginatedResponse(items: aps, total: aps.count, next: nil)
    }

    func fetchAPDetail(serial: String) async throws -> AccessPoint {
        AccessPoint(serial: serial, name: "AP-Lobby", model: "AP-515", status: .up,
                    ipAddress: "10.0.1.10", macAddress: "AA:BB:CC:DD:EE:01",
                    firmware: "10.4.1.0-dev", uptime: 864000, site: "HQ Campus", clientCount: 24)
    }

    func fetchAPRadios(serial: String) async throws -> [Radio] {
        [
            Radio(index: 0, band: "2.4 GHz", channel: 6,   ssid: "ArubaCorp",   clientCount: 8,  throughput: 12.5),
            Radio(index: 1, band: "5 GHz",   channel: 153, ssid: "ArubaCorp5G", clientCount: 16, throughput: 87.3),
            Radio(index: 2, band: "6 GHz",   channel: 37,  ssid: nil,           clientCount: 0,  throughput: 0.0),
        ]
    }

    func fetchAPClients(serial: String, limit: Int, next: String?) async throws -> PaginatedResponse<CentralClient> {
        PaginatedResponse(items: [], total: 0, next: nil)
    }

    // MARK: - Switches

    func fetchSwitches(site: String?, search: String?, limit: Int, next: String?) async throws -> PaginatedResponse<CentralSwitch> {
        let switches = [
            CentralSwitch(serial: "SW001", name: "SW-Core-1", model: "CX 6300M 24-port",
                          status: .up, ipAddress: "10.0.0.1", macAddress: "BB:CC:DD:EE:FF:01",
                          firmware: "10.10.1040", uptime: 2592000, site: site ?? "HQ Campus", stackId: nil),
            CentralSwitch(serial: "SW002", name: "SW-Dist-1",  model: "CX 6200F 48-port",
                          status: .up, ipAddress: "10.0.0.2", macAddress: "BB:CC:DD:EE:FF:02",
                          firmware: "10.10.1040", uptime: 1296000, site: site ?? "HQ Campus", stackId: nil),
        ]
        return PaginatedResponse(items: switches, total: switches.count, next: nil)
    }

    func fetchSwitchDetail(serial: String) async throws -> CentralSwitch {
        CentralSwitch(serial: serial, name: "SW-Core-1", model: "CX 6300M 24-port",
                      status: .up, ipAddress: "10.0.0.1", macAddress: "BB:CC:DD:EE:FF:01",
                      firmware: "10.10.1040", uptime: 2592000, site: "HQ Campus", stackId: nil)
    }

    func fetchSwitchInterfaces(serial: String) async throws -> [SwitchInterface] {
        (1...24).map { i in
            let status: PortStatus = i == 5 ? .down : (i == 9 || i == 17 ? .disabled : .up)
            return SwitchInterface(
                portId: "1/1/\(i)",
                status: status,
                speed: status == .up ? 1_000_000_000 : nil,
                vlan: 10,
                connectedDevice: status == .up ? "host-\(i).corp" : nil,
                txBytes: status == .up ? i * 1_024_000 : nil,
                rxBytes: status == .up ? i * 512_000 : nil
            )
        }
    }

    func fetchSwitchVLANs(serial: String) async throws -> [VLAN] { [] }

    func fetchStackMembers(serial: String) async throws -> [StackMember] { [] }

    // MARK: - Clients

    func fetchClients(site: String?, search: String?, limit: Int, next: String?) async throws -> PaginatedResponse<CentralClient> {
        PaginatedResponse(items: [], total: 0, next: nil)
    }

    // MARK: - Alerts

    func fetchAlerts(limit: Int, next: String?) async throws -> PaginatedResponse<CentralAlert> {
        let now = Date()
        let alerts: [CentralAlert] = [
            CentralAlert(id: "a1", name: "AP Down",
                         severity: .critical,
                         description: "AP-Cafeteria (AP003) is unreachable on the network.",
                         deviceSerial: "AP003", siteName: "HQ Campus",
                         createdAt: now.addingTimeInterval(-3600), isCleared: false),
            CentralAlert(id: "a2", name: "High Client Load",
                         severity: .major,
                         description: "AP-Lobby client count exceeded threshold (24 > 20).",
                         deviceSerial: "AP001", siteName: "HQ Campus",
                         createdAt: now.addingTimeInterval(-7200), isCleared: false),
            CentralAlert(id: "a3", name: "Firmware Mismatch",
                         severity: .minor,
                         description: "AP-Cafeteria firmware is behind by one major version.",
                         deviceSerial: "AP003", siteName: "HQ Campus",
                         createdAt: now.addingTimeInterval(-86400), isCleared: false),
            CentralAlert(id: "a4", name: "Config Backup",
                         severity: .info,
                         description: "Automated config backup completed successfully.",
                         deviceSerial: "SW001", siteName: "HQ Campus",
                         createdAt: now.addingTimeInterval(-172800), isCleared: true),
            CentralAlert(id: "a5", name: "Link Down",
                         severity: .major,
                         description: "Uplink port on SW-Dist-1 went down briefly.",
                         deviceSerial: "SW002", siteName: "Branch Office",
                         createdAt: now.addingTimeInterval(-10800), isCleared: true),
        ]
        return PaginatedResponse(items: alerts, total: alerts.count, next: nil)
    }

    // MARK: - Actions

    func clearAlert(alertId: String) async throws {}
    func rebootAP(serial: String) async throws {}
    func blinkAPLED(serial: String) async throws {}
    func disconnectAllClientsFromAP(serial: String) async throws {}
    func testConnection() async throws {}
    func updateBaseURL(_ url: URL) {}
    func searchDevices(query: String) async throws -> [SearchResult] { [] }
}
#endif
