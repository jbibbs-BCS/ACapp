import XCTest
import Combine
@testable import ArubaCentral

@MainActor
final class GlobalSearchViewModelTests: XCTestCase {

    private var mockClient: MockCentralAPIClient!
    private var sut: GlobalSearchViewModel!
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        mockClient = MockCentralAPIClient()
        sut = GlobalSearchViewModel(apiClient: mockClient)
    }

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    // Query shorter than 2 chars must produce .idle immediately (no search fired)
    func test_shortQuery_staysIdle() async throws {
        sut.query = "a"
        try await Task.sleep(nanoseconds: 10_000_000)
        guard case .idle = sut.results else {
            XCTFail("Expected .idle for 1-character query, got \(sut.results)")
            return
        }
    }

    // Empty query clears results back to .idle
    func test_emptyQuery_clearsResults() async throws {
        mockClient.searchDevicesResult = .success([
            .ap(AccessPoint.stub())
        ])
        sut.query = "myAP"
        try await Task.sleep(nanoseconds: 600_000_000)
        sut.query = ""
        // Wait for debounce (400ms) + runloop pass to process the empty-query reset
        try await Task.sleep(nanoseconds: 500_000_000)
        guard case .idle = sut.results else {
            XCTFail("Expected .idle after clearing query, got \(sut.results)")
            return
        }
    }

    // Successful search yields .loaded with results
    func test_successfulSearch_yieldsLoadedResults() async throws {
        let ap = AccessPoint.stub(name: "TestAP")
        mockClient.searchDevicesResult = .success([.ap(ap)])

        sut.query = "TestAP"
        try await Task.sleep(nanoseconds: 600_000_000)

        guard case .loaded(let results) = sut.results else {
            XCTFail("Expected .loaded, got \(sut.results)")
            return
        }
        XCTAssertEqual(results.count, 1)
        if case .ap(let fetchedAP) = results[0] {
            XCTAssertEqual(fetchedAP.name, "TestAP")
        } else {
            XCTFail("Expected .ap case")
        }
    }

    // API error yields .error state
    func test_apiError_yieldsErrorState() async throws {
        mockClient.searchDevicesResult = .failure(APIError.unauthorized)
        sut.query = "broken"
        try await Task.sleep(nanoseconds: 600_000_000)

        guard case .error = sut.results else {
            XCTFail("Expected .error, got \(sut.results)")
            return
        }
    }

    // isSearching is true during fetch, false after
    func test_isSearching_togglesDuringFetch() async throws {
        mockClient.searchDevicesResult = .success([])
        mockClient.searchDevicesDelay = 0.3

        sut.query = "latency"
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertTrue(sut.isSearching)

        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertFalse(sut.isSearching)
    }
}
