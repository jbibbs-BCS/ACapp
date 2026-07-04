import XCTest
@testable import ArubaCentral

final class ModelDecodingTests: XCTestCase {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()

    // MARK: - Site

    func testSiteDecoding() throws {
        let json = """
        {
            "id": "abc123",
            "siteName": "HQ Campus",
            "health": {"groups": [{"name":"Poor","value":0},{"name":"Fair","value":8},{"name":"Good","value":92}]},
            "devices": {"count": 28},
            "clients": {"count": 310},
            "alerts": {"totalCount": 2, "groups": []}
        }
        """.data(using: .utf8)!
        let site = try decoder.decode(Site.self, from: json)
        XCTAssertEqual(site.id, "abc123")
        XCTAssertEqual(site.name, "HQ Campus")
        XCTAssertEqual(site.healthPct, 92)
        XCTAssertEqual(site.deviceCount, 28)
        XCTAssertEqual(site.clientCount, 310)
        XCTAssertEqual(site.alertCount, 2)
    }

    func testSiteUpDeviceCountSumsGoodAndFairDeviceCounts() throws {
        // devices.health group values are device COUNTS (not %): Good 62 + Fair 1 = 63.
        let json = """
        {
            "id": "167988450776",
            "siteName": "Altruria Elementary",
            "health": {"groups": [{"name":"Poor","value":0},{"name":"Fair","value":0},{"name":"Good","value":100}]},
            "devices": {
                "count": 63,
                "health": {"groups": [{"name":"Poor","value":0},{"name":"Fair","value":1},{"name":"Good","value":62}]}
            },
            "clients": {"count": 178},
            "alerts": {"totalCount": 1}
        }
        """.data(using: .utf8)!
        let site = try decoder.decode(Site.self, from: json)
        XCTAssertEqual(site.deviceCount, 63)
        XCTAssertEqual(site.upDeviceCount, 63)   // Good 62 + Fair 1
        XCTAssertEqual(site.healthPct, 100)      // top-level health stays a percentage
    }

    func testSiteHealthLevelGood() throws {
        let site = try decoder.decode(Site.self, from: siteJSON(goodPct: 85))
        XCTAssertEqual(site.healthLevel, .good)
    }

    func testSiteHealthLevelWarning() throws {
        let site = try decoder.decode(Site.self, from: siteJSON(goodPct: 65))
        XCTAssertEqual(site.healthLevel, .warning)
    }

    func testSiteHealthLevelCritical() throws {
        let site = try decoder.decode(Site.self, from: siteJSON(goodPct: 30))
        XCTAssertEqual(site.healthLevel, .critical)
    }

    // MARK: - AccessPoint

    func testAccessPointDecoding() throws {
        let json = """
        {
            "serialNumber": "SN001",
            "deviceName": "AP-Lobby",
            "model": "AP-635",
            "status": "ONLINE",
            "ipv4": "10.0.1.5",
            "macAddress": "aa:bb:cc:dd:ee:ff",
            "firmwareVersion": "10.4.0.0",
            "uptimeInMillis": 86400000,
            "siteName": "HQ Campus",
            "clientCount": 12
        }
        """.data(using: .utf8)!
        let ap = try decoder.decode(AccessPoint.self, from: json)
        XCTAssertEqual(ap.serial, "SN001")
        XCTAssertEqual(ap.name, "AP-Lobby")
        XCTAssertEqual(ap.status, .up)
        XCTAssertEqual(ap.id, "SN001")
        XCTAssertEqual(ap.ipAddress, "10.0.1.5")   // now from ipv4, not publicIpv4
        XCTAssertEqual(ap.clientCount, 12)
        XCTAssertEqual(ap.uptime, 86400)    // ms → seconds
    }

    func testAccessPointWLANsDecodeAndFilterEnabled() throws {
        let json = """
        {
            "serialNumber": "AP00000001",
            "deviceName": "ap_1",
            "model": "AP-275",
            "status": "ONLINE",
            "macAddress": "11:22:33:44:55:66",
            "wlans": [
                { "wlanName": "wlan1", "band": "5 GHz", "status": "ENABLED",  "vlan": "11" },
                { "wlanName": "wlan2", "band": "2.4 GHz", "status": "DISABLED", "vlan": "12" }
            ]
        }
        """.data(using: .utf8)!
        let ap = try decoder.decode(AccessPoint.self, from: json)
        XCTAssertEqual(ap.wlans?.count, 2)
        // enabledWLANs keeps only ENABLED entries
        XCTAssertEqual(ap.enabledWLANs.count, 1)
        let wlan = try XCTUnwrap(ap.enabledWLANs.first)
        XCTAssertEqual(wlan.wlanName, "wlan1")
        XCTAssertEqual(wlan.band, "5 GHz")
        XCTAssertEqual(wlan.vlan, "11")
        XCTAssertTrue(wlan.isEnabled)
    }

    func testAccessPointOptionalFieldsMissing() throws {
        let json = """
        {
            "id": "SN002",
            "deviceName": "AP-Down",
            "model": "AP-515",
            "status": "OFFLINE",
            "macAddress": "aa:bb:cc:dd:ee:ff"
        }
        """.data(using: .utf8)!
        let ap = try decoder.decode(AccessPoint.self, from: json)
        XCTAssertNil(ap.ipAddress)
        XCTAssertNil(ap.clientCount)
        XCTAssertEqual(ap.status, .down)
    }

    // MARK: - CentralSwitch

    func testSwitchDecoding() throws {
        let json = """
        {
            "serialNumber": "SW001",
            "deviceName": "Core-Switch-1",
            "model": "6300M",
            "status": "Online",
            "ipv4": "10.0.0.1",
            "macAddress": "11:22:33:44:55:66",
            "firmwareVersion": "10.13.1010",
            "uptimeInMillis": 604800000,
            "siteName": "HQ Campus"
        }
        """.data(using: .utf8)!
        let sw = try decoder.decode(CentralSwitch.self, from: json)
        XCTAssertEqual(sw.serial, "SW001")
        XCTAssertEqual(sw.id, "SW001")
        XCTAssertEqual(sw.status, .up)
        XCTAssertEqual(sw.name, "Core-Switch-1")
        XCTAssertEqual(sw.model, "6300M")
        XCTAssertEqual(sw.ipAddress, "10.0.0.1")
        XCTAssertEqual(sw.siteName, "HQ Campus")
        XCTAssertEqual(sw.uptime, 604800)   // ms → seconds
    }

    func testStackedSwitchDecoding() throws {
        // Real /switches payload for a stacked member.
        let json = """
        {
            "serialNumber": "CN35HKZ1YX",
            "deviceName": "Aruba-VSF-2930F",
            "model": "AS-2930F",
            "status": "OFFLINE",
            "stackId": "090064e8-818ee000",
            "stackMemberId": 2,
            "switchRole": "Conductor",
            "deployment": "Stack"
        }
        """.data(using: .utf8)!
        let sw = try decoder.decode(CentralSwitch.self, from: json)
        XCTAssertEqual(sw.status, .down)          // "OFFLINE" → .down
        XCTAssertEqual(sw.stackId, "090064e8-818ee000")
        XCTAssertEqual(sw.stackMemberId, 2)
        XCTAssertEqual(sw.switchRole, "Conductor")
        XCTAssertEqual(sw.deployment, "Stack")
        XCTAssertTrue(sw.isStacked)
        XCTAssertTrue(sw.isConductor)
    }

    // MARK: - CentralClient

    func testWirelessClientDecoding() throws {
        let json = """
        {
            "macAddress": "aa:11:bb:22:cc:33",
            "clientName": "MacBook-Josh",
            "ipv4": "10.0.1.100",
            "clientConnectionType": "Wireless",
            "connectedDeviceSerial": "SN001",
            "siteName": "HQ Campus",
            "wlanName": "Corp-WiFi",
            "snr": 28,
            "role": "wireless",
            "clientManufacturer": "Samsung",
            "clientFunction": "Mobile",
            "clientVendor": "Android",
            "clientOperatingSystem": "Android",
            "clientTags": "tag1",
            "clientCategory": "Smart Device",
            "wirelessBand": "5GHZ",
            "wirelessChannel": 52,
            "connectedAt": "2026-06-30T15:56:07.460Z"
        }
        """.data(using: .utf8)!
        let client = try decoder.decode(CentralClient.self, from: json)
        XCTAssertEqual(client.macAddress, "aa:11:bb:22:cc:33")
        XCTAssertEqual(client.connectionType, .wireless)
        XCTAssertEqual(client.ssid, "Corp-WiFi")
        XCTAssertEqual(client.signalStrength, 28)
        XCTAssertEqual(client.role, "wireless")
        XCTAssertEqual(client.clientManufacturer, "Samsung")
        XCTAssertEqual(client.clientFunction, "Mobile")
        XCTAssertEqual(client.clientVendor, "Android")
        XCTAssertEqual(client.clientOperatingSystem, "Android")
        XCTAssertEqual(client.clientTags, "tag1")
        XCTAssertEqual(client.clientCategory, "Smart Device")
        XCTAssertEqual(client.wirelessBand, "5GHZ")
        XCTAssertEqual(client.wirelessChannel, 52)
        XCTAssertNotNil(client.connectedAt)
    }

    func testWiredClientDecoding() throws {
        let json = """
        {
            "macAddress": "dd:44:ee:55:ff:66",
            "clientName": "Printer-Floor2",
            "ipv4": "10.0.2.50",
            "clientConnectionType": "Wired",
            "connectedDeviceSerial": "SW001",
            "siteName": "HQ Campus",
            "vlanId": "20",
            "port": "1/1/4",
            "connectedAt": "2026-06-30T16:00:00.000Z"
        }
        """.data(using: .utf8)!
        let client = try decoder.decode(CentralClient.self, from: json)
        XCTAssertEqual(client.connectionType, .wired)
        XCTAssertEqual(client.vlan, 20)
        XCTAssertEqual(client.port, "1/1/4")
        XCTAssertNil(client.ssid)
    }

    // MARK: - CentralAlert

    func testAlertDecoding() throws {
        let json = """
        {
            "id": "22071893000:47765082406",
            "name": "Insufficient PoE Received",
            "severity": "Critical",
            "summary": "AP LUHR000001 did not receive the requested PoE power.",
            "category": "System",
            "deviceType": "Access Point",
            "priority": "Very High",
            "status": "Cleared",
            "clearedReason": null,
            "createdAt": "2025-12-10T07:04:33.352Z",
            "updatedAt": "2025-12-10T08:37:02.475Z"
        }
        """.data(using: .utf8)!
        let alert = try decoder.decode(CentralAlert.self, from: json)
        XCTAssertEqual(alert.id, "22071893000:47765082406")
        XCTAssertEqual(alert.severity, .critical)
        XCTAssertEqual(alert.description, "AP LUHR000001 did not receive the requested PoE power.")
        XCTAssertEqual(alert.category, "System")
        XCTAssertEqual(alert.deviceType, "Access Point")
        XCTAssertEqual(alert.priority, "Very High")
        XCTAssertEqual(alert.status, "Cleared")
        XCTAssertTrue(alert.isCleared)   // derived from status == "Cleared"
        XCTAssertNotNil(alert.updatedAt)
        // createdAt parsed from ISO 8601, not defaulted to now
        XCTAssertEqual(alert.createdAt.timeIntervalSince1970, 1765350273.352, accuracy: 1.0)
    }

    func testAlertActiveStatusIsNotCleared() throws {
        let json = """
        {
            "id": "a2",
            "name": "USB Device Removed from AP",
            "severity": "Minor",
            "summary": "A USB device was removed.",
            "status": "Active",
            "createdAt": "2025-12-10T08:31:36.710Z",
            "updatedAt": ""
        }
        """.data(using: .utf8)!
        let alert = try decoder.decode(CentralAlert.self, from: json)
        XCTAssertEqual(alert.severity, .minor)
        XCTAssertFalse(alert.isCleared)
        XCTAssertNil(alert.updatedAt)   // empty string → nil
    }

    func testAlertSeverityOrdering() {
        XCTAssertLessThan(AlertSeverity.critical, AlertSeverity.major)
        XCTAssertLessThan(AlertSeverity.major, AlertSeverity.minor)
        XCTAssertLessThan(AlertSeverity.minor, AlertSeverity.info)
    }

    // MARK: - Radio

    func testRadioDecoding() throws {
        let json = """
        {
            "radioNumber": 0,
            "band": "5GHz",
            "channel": "36",
            "clientCount": 8,
            "throughput": 245.5
        }
        """.data(using: .utf8)!
        let radio = try decoder.decode(Radio.self, from: json)
        XCTAssertEqual(radio.band, "5GHz")
        XCTAssertEqual(radio.channel, 36)
        XCTAssertEqual(radio.clientCount, 8)
    }

    // MARK: - SwitchInterface

    func testSwitchInterfaceDecoding() throws {
        let json = """
        {
            "id": "1/1/1",
            "name": "GigabitEthernet1/0/1",
            "description": "Uplink to Core Switch",
            "operStatus": "Up",
            "speed": 1000000000,
            "nativeVlan": 10,
            "allowedVlanIds": [10, 20],
            "neighbour": "CoreSwitch",
            "neighbourRole": "Core Switch"
        }
        """.data(using: .utf8)!
        let iface = try decoder.decode(SwitchInterface.self, from: json)
        XCTAssertEqual(iface.portId, "1/1/1")
        XCTAssertEqual(iface.status, .up)
        XCTAssertEqual(iface.speed, 1_000_000_000)
        XCTAssertEqual(iface.neighbour, "CoreSwitch")
        XCTAssertEqual(iface.neighbourRole, "Core Switch")
        XCTAssertEqual(iface.allowedVlanIds, [10, 20])
        XCTAssertEqual(iface.description, "Uplink to Core Switch")
    }

    // MARK: - VLAN

    func testVLANDecoding() throws {
        let json = """
        {
            "id": "10",
            "name": "Corp",
            "taggedPorts": ["1/1/1", "1/1/2"],
            "untaggedPorts": null
        }
        """.data(using: .utf8)!
        let vlan = try decoder.decode(VLAN.self, from: json)
        XCTAssertEqual(vlan.vlanId, 10)
        XCTAssertEqual(vlan.name, "Corp")
        XCTAssertEqual(vlan.taggedPorts.count, 2)
        XCTAssertEqual(vlan.untaggedPorts.count, 0)
    }

    // MARK: - Helpers

    private func siteJSON(goodPct: Int) -> Data {
        """
        {
            "id": "s1",
            "siteName": "Test",
            "health": {"groups": [{"name":"Poor","value":0},{"name":"Fair","value":\(100 - goodPct)},{"name":"Good","value":\(goodPct)}]},
            "devices": {"count": 1},
            "clients": {"count": 1},
            "alerts": {"totalCount": 0, "groups": []}
        }
        """.data(using: .utf8)!
    }
}
