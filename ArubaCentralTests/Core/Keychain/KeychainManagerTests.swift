import XCTest
@testable import ArubaCentral

final class KeychainManagerTests: XCTestCase {

    var sut: KeychainManager!

    override func setUp() {
        super.setUp()
        sut = KeychainManager()
        // Clean up any leftover test data
        KeychainManager.Key.allCases.forEach { sut.delete(for: $0) }
    }

    override func tearDown() {
        KeychainManager.Key.allCases.forEach { sut.delete(for: $0) }
        sut = nil
        super.tearDown()
    }

    func testSaveAndRetrieveClientId() throws {
        try sut.save("my-client-id", for: .clientId)
        let retrieved = try sut.retrieve(for: .clientId)
        XCTAssertEqual(retrieved, "my-client-id")
    }

    func testSaveAndRetrieveClientSecret() throws {
        try sut.save("super-secret-value", for: .clientSecret)
        let retrieved = try sut.retrieve(for: .clientSecret)
        XCTAssertEqual(retrieved, "super-secret-value")
    }

    func testOverwriteExistingValue() throws {
        try sut.save("first-value", for: .clientId)
        try sut.save("second-value", for: .clientId)
        let retrieved = try sut.retrieve(for: .clientId)
        XCTAssertEqual(retrieved, "second-value")
    }

    func testRetrieveNonExistentKeyThrows() {
        XCTAssertThrowsError(try sut.retrieve(for: .accessToken)) { error in
            XCTAssertEqual(error as? KeychainError, .notFound)
        }
    }

    func testDeleteRemovesValue() throws {
        try sut.save("to-be-deleted", for: .clientId)
        sut.delete(for: .clientId)
        XCTAssertThrowsError(try sut.retrieve(for: .clientId))
    }

    func testDeleteNonExistentKeyDoesNotThrow() {
        // Should not crash or throw
        sut.delete(for: .tokenExpiry)
    }

    func testSaveEmptyString() throws {
        try sut.save("", for: .clientId)
        let retrieved = try sut.retrieve(for: .clientId)
        XCTAssertEqual(retrieved, "")
    }

    func testSaveSpecialCharacters() throws {
        let special = "abc!@#$%^&*()_+-=[]{}|;':\",./<>?"
        try sut.save(special, for: .clientSecret)
        let retrieved = try sut.retrieve(for: .clientSecret)
        XCTAssertEqual(retrieved, special)
    }

    func testAllKeysIndependent() throws {
        try sut.save("id-value", for: .clientId)
        try sut.save("secret-value", for: .clientSecret)
        try sut.save("token-value", for: .accessToken)
        try sut.save("12345.678", for: .tokenExpiry)

        XCTAssertEqual(try sut.retrieve(for: .clientId), "id-value")
        XCTAssertEqual(try sut.retrieve(for: .clientSecret), "secret-value")
        XCTAssertEqual(try sut.retrieve(for: .accessToken), "token-value")
        XCTAssertEqual(try sut.retrieve(for: .tokenExpiry), "12345.678")
    }
}
