import XCTest
@testable import ArubaCentral

final class FoundationTypesTests: XCTestCase {

    // MARK: - APIError

    func testAPIErrorUserMessageUnauthorized() {
        XCTAssertFalse(APIError.unauthorized.userMessage.isEmpty)
    }

    func testAPIErrorUserMessageForbidden() {
        XCTAssertFalse(APIError.forbidden.userMessage.isEmpty)
    }

    func testAPIErrorUserMessageServerError() {
        let msg = APIError.serverError(500).userMessage
        XCTAssertTrue(msg.contains("500"))
    }

    func testAPIErrorEquality() {
        XCTAssertEqual(APIError.unauthorized, APIError.unauthorized)
        XCTAssertEqual(APIError.serverError(503), APIError.serverError(503))
        XCTAssertNotEqual(APIError.serverError(500), APIError.serverError(503))
    }

    // MARK: - LoadState

    func testLoadStateIsLoadingTrue() {
        let state: LoadState<String> = .loading
        XCTAssertTrue(state.isLoading)
    }

    func testLoadStateIsLoadingFalse() {
        let state: LoadState<String> = .loaded("hello")
        XCTAssertFalse(state.isLoading)
    }

    func testLoadStateValue() {
        let state: LoadState<Int> = .loaded(42)
        XCTAssertEqual(state.value, 42)
    }

    func testLoadStateValueNilWhenNotLoaded() {
        let state: LoadState<Int> = .loading
        XCTAssertNil(state.value)
    }

    func testLoadStateError() {
        let state: LoadState<Int> = .error(.forbidden)
        XCTAssertEqual(state.error, .forbidden)
    }

    func testLoadStateErrorNilWhenLoaded() {
        let state: LoadState<Int> = .loaded(1)
        XCTAssertNil(state.error)
    }

    // MARK: - PaginatedResponse

    func testPaginatedResponseDecoding() throws {
        let json = """
        {
            "items": [1, 2, 3],
            "total": 100,
            "next": "cursor123"
        }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(PaginatedResponse<Int>.self, from: json)
        XCTAssertEqual(response.items, [1, 2, 3])
        XCTAssertEqual(response.total, 100)
        XCTAssertEqual(response.next, "cursor123")
    }

    func testPaginatedResponseHasMore() throws {
        let json = """
        {"items": [], "total": 50, "next": null}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(PaginatedResponse<Int>.self, from: json)
        XCTAssertFalse(response.hasMore)
    }

    func testPaginatedResponseHasMoreTrue() throws {
        let json = """
        {"items": [], "total": 150, "next": "nextpage"}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(PaginatedResponse<Int>.self, from: json)
        XCTAssertTrue(response.hasMore)
    }
}
