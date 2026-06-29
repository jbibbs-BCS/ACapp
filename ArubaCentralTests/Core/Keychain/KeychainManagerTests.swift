import XCTest
@testable import ArubaCentral

final class KeychainManagerTests: XCTestCase {
    private var sut: KeychainManager!

    override func setUp() {
        super.setUp()
        sut = KeychainManager.shared
        sut.clearAll()
    }

    override func tearDown() {
        sut.clearAll()
        super.tearDown()
    }

    func test_clientID_nilBeforeSave() {
        XCTAssertNil(sut.clientID())
    }

    func test_clientID_roundTrip() {
        sut.saveClientID("my-client-id")
        XCTAssertEqual(sut.clientID(), "my-client-id")
    }

    func test_clientSecret_roundTrip() {
        sut.saveClientSecret("super-secret-value")
        XCTAssertEqual(sut.clientSecret(), "super-secret-value")
    }

    func test_region_roundTrip() {
        sut.saveRegion("us1")
        XCTAssertEqual(sut.region(), "us1")
    }

    func test_region_nilBeforeSave() {
        XCTAssertNil(sut.region())
    }

    func test_clearAll_removesAllCredentials() {
        sut.saveClientID("id")
        sut.saveClientSecret("secret")
        sut.saveRegion("eu1")
        sut.clearAll()
        XCTAssertNil(sut.clientID())
        XCTAssertNil(sut.clientSecret())
        XCTAssertNil(sut.region())
    }

    func test_overwrite_updatesValue() {
        sut.saveClientID("first")
        sut.saveClientID("second")
        XCTAssertEqual(sut.clientID(), "second")
    }

    func test_keysAreIndependent() {
        sut.saveClientID("id-value")
        sut.saveClientSecret("secret-value")
        sut.saveRegion("us1")
        XCTAssertEqual(sut.clientID(), "id-value")
        XCTAssertEqual(sut.clientSecret(), "secret-value")
        XCTAssertEqual(sut.region(), "us1")
    }
}
