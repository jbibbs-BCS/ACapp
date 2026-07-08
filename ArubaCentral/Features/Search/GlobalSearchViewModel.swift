import Foundation
import Combine

@MainActor
final class GlobalSearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var results: LoadState<[SearchResult]> = .idle
    @Published private(set) var isSearching: Bool = false

    private let apiClient: CentralAPIClientProtocol
    private var searchTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []

    init(apiClient: CentralAPIClientProtocol) {
        self.apiClient = apiClient
        setupDebounce()
    }

    private func setupDebounce() {
        $query
            .removeDuplicates()
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] q in
                self?.handleQueryChange(q)
            }
            .store(in: &cancellables)
    }

    private func handleQueryChange(_ q: String) {
        searchTask?.cancel()
        guard q.count >= 2 else {
            results = .idle
            isSearching = false
            return
        }
        searchTask = Task {
            await performSearch(query: q)
        }
    }

    private func performSearch(query: String) async {
        isSearching = true
        results = .loading
        do {
            let found = try await apiClient.searchDevices(query: query)
            guard !Task.isCancelled else { return }
            results = .loaded(found)
        } catch {
            guard !Task.isCancelled else { return }
            results = .error(error as? APIError ?? .unknown(error.localizedDescription))
        }
        isSearching = false
    }
}
