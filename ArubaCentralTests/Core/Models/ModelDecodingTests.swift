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
            "site_id": "abc123",
            "site_name": "HQ Campus",
            "health_score": 92,
            "ap_count": 24,
            "switch_count": 4,
            "client_count": 310
        }
        """.data(using: .utf8)!
        let site = try decoder.decode(Site.self, from: json)
        XCTAssertEqual(site.id, "abc123")
        XCTAssertEqual(site.name, "HQ Campus")
        XCTAssertEqual(site.healthScore, 92)
        XCTAssertEqual(site.apCount, 24)
        XCTAssertEqual(site.switchCount, 4)
        XCTAssertEqual(site.clientCount, 310)
    }

    func testSiteHealthLevelGood() throws {
        let site = try decoder.decode(Site.self, from: siteJSON(score: 85))
        XCTAssertEqual(site.healthLevel, .good)
    }

    func testSiteHealthLevelWarning() throws {
        let site = try decoder.decode(Site.self, from: siteJSON(score: 65))
        XCTAssertEqual(site.healthLevel, .warning)
    }

    func testSiteHealthLevelCritical() throws {
        let site = try decoder.decode(Site.self, from: siteJSON(score: 30))
        XCTAssertEqual(site.healthLevel, .critical)
    }

    // MARK: - AccessPoint

    func testAccessPointDecoding() throws {
        let json = """
        {
            "serial": "SN001",
            "name": "AP-Lobby",
            "model": "AP-635",
            "status": "Up",
            "ip_address": "10.0.1.5",
            "mac_address": "aa:bb:cc:dd:ee:ff",
            "firmware": "10.4.0.0",
            "uptime": 86400,
            "site_name": "HQ Campus",
            "client_count": 12
        }
        """.data(using: .utf8)!
        let ap = try decoder.decode(AccessPoint.self, from: json)
        XCTAssertEqual(ap.serial, "SN001")
        XCTAssertEqual(ap.name, "AP-Lobby")
        XCTAssertEqual(ap.status, .up)
        XCTAssertEqual(ap.id, "SN001")
        XCTAssertEqual(ap.clientCount, 12)
    }

    func testAccessPointOptionalFieldsMissing() throws {
        let json = """
        {
            "serial": "SN002",
            "name": "AP-Down",
            "model": "AP-515",
            "status": "Down",
            "mac_address": "aa:bb:cc:dd:ee:ff"
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
            "serial": "SW001",
            "name": "Core-Switch-1",
            "model": "6300M",
            "status": "Up",
            "ip_address": "10.0.0.1",
            "mac_address": "11:22:33:44:55:66",
            "firmware": "10.13.1010",
            "uptime": 604800,
            "site_name": "HQ Campus"
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
    }

    // MARK: - CentralClient

    func testWirelessClientDecoding() throws {
        let json = """
        {
            "mac_address": "aa:11:bb:22:cc:33",
            "name": "MacBook-Josh",
            "ip_address": "10.0.1.100",
            "client_type": "WIRELESS",
            "associated_device": "SN001",
            "site_name": "HQ Campus",
            "ssid": "Corp-WiFi",
            "signal_strength": -65,
            "connected_at": 1751000000
        }
        """.data(using: .utf8)!
        let client = try decoder.decode(CentralClient.self, from: json)
        XCTAssertEqual(client.macAddress, "aa:11:bb:22:cc:33")
        XCTAssertEqual(client.connectionType, .wireless)
        XCTAssertEqual(client.ssid, "Corp-WiFi")
        XCTAssertEqual(client.signalStrength, -65)
        XCTAssertNotNil(client.connectedAt)
    }

    func testWiredClientDecoding() throws {
        let json = """
        {
            "mac_address": "dd:44:ee:55:ff:66",
            "name": "Printer-Floor2",
            "ip_address": "10.0.2.50",
            "client_type": "WIRED",
            "associated_device": "SW001",
            "site_name": "HQ Campus",
            "vlan": 20,
            "port": "1/1/4",
            "connected_at": 1751000000
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
            "alert_id": "ALT001",
            "alert_name": "AP Down",
            "severity": "Critical",
            "alert_description": "AP-Lobby is unreachable",
            "device_serial": "SN001",
            "site_name": "HQ Campus",
            "created_at": 1751000000,
            "is_cleared": false
        }
        """.data(using: .utf8)!
        let alert = try decoder.decode(CentralAlert.self, from: json)
        XCTAssertEqual(alert.id, "ALT001")
        XCTAssertEqual(alert.severity, .critical)
        XCTAssertFalse(alert.isCleared)
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
            "radio_index": 0,
            "band": "5GHz",
            "channel": 36,
            "ssid": "Corp-WiFi",
            "client_count": 8,
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
            "port_id": "1/1/1",
            "port_status": "Up",
            "speed": "1G",
            "vlan": 10,
            "connected_device": "MacBook-Josh",
            "tx_bytes": 1000000,
            "rx_bytes": 500000
        }
        """.data(using: .utf8)!
        let iface = try decoder.decode(SwitchInterface.self, from: json)
        XCTAssertEqual(iface.portId, "1/1/1")
        XCTAssertEqual(iface.status, .up)
        XCTAssertEqual(iface.speed, "1G")
    }

    // MARK: - VLAN

    func testVLANDecoding() throws {
        let json = """
        {
            "vlan_id": 10,
            "vlan_name": "Corp",
            "tagged_ports": ["1/1/1", "1/1/2"],
            "untagged_ports": ["1/1/3"]
        }
        """.data(using: .utf8)!
        let vlan = try decoder.decode(VLAN.self, from: json)
        XCTAssertEqual(vlan.vlanId, 10)
        XCTAssertEqual(vlan.name, "Corp")
        XCTAssertEqual(vlan.taggedPorts.count, 2)
    }

    // MARK: - Helpers

    private func siteJSON(score: Int) -> Data {
        """
        {
            "site_id": "s1",
            "site_name": "Test",
            "health_score": \(score),
            "ap_count": 1,
            "switch_count": 1,
            "client_count": 1
        }
        """.data(using: .utf8)!
    }
}
