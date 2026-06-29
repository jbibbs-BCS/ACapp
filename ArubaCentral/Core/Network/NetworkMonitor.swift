import Foundation
import Network
import Combine

@MainActor
final class NetworkMonitor: ObservableObject {
    @Published private(set) var isConnected: Bool = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.aruba.central.networkmonitor")

    private var offlineTask: Task<Void, Never>?

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let satisfied = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.offlineTask?.cancel()
                if satisfied {
                    self.isConnected = true
                } else {
                    // NWPathMonitor gives false negatives in some simulator/macOS combinations.
                    // Verify with a real HTTP round-trip before showing the offline banner.
                    self.offlineTask = Task { [weak self] in
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        guard !Task.isCancelled, let self else { return }
                        let reachable = await Self.checkReachability()
                        if !reachable { self.isConnected = false }
                    }
                }
            }
        }
        monitor.start(queue: queue)
    }

    private static func checkReachability() async -> Bool {
        guard let url = URL(string: "https://captive.apple.com/hotspot-detect.html") else { return true }
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.httpMethod = "HEAD"
        return (try? await URLSession.shared.data(for: request)) != nil
    }

    deinit {
        monitor.cancel()
    }
}
