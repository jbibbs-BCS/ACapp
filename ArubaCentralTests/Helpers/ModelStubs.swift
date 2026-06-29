import Foundation
@testable import ArubaCentral

extension AccessPoint {
    static func stub(
        serial: String = "CNX001",
        name: String = "TestAP"
    ) -> AccessPoint {
        AccessPoint(
            serial: serial,
            name: name,
            model: "AP-515",
            status: .up,
            ipAddress: "10.0.0.1",
            macAddress: "aa:bb:cc:dd:ee:ff",
            firmware: "10.7.0.0",
            uptime: 86400,
            site: "HQ",
            clientCount: 5
        )
    }
}
