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
                    // NWPathMonitor has false negatives on simulator and some macOS configs.
                    // Wait 2 s, then verify with concurrent HTTP probes before showing the banner.
                    self.offlineTask = Task { [weak self] in
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        guard !Task.isCancelled, let self else { return }
                        let reachable = await Self.checkReachability()
                        guard !Task.isCancelled else { return }
                        if !reachable { self.isConnected = false }
                    }
                }
            }
        }
        monitor.start(queue: queue)
    }

    // Fires three HEAD requests concurrently; returns true as soon as any one succeeds.
    // Multiple endpoints handle corporate firewalls that may block specific domains.
    private static func checkReachability() async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            for urlString in [
                "https://www.apple.com",
                "https://www.google.com",
                "https://captive.apple.com/hotspot-detect.html"
            ] {
                group.addTask { await probe(urlString) }
            }
            for await result in group {
                if result { return true }
            }
            return false
        }
    }

    private static func probe(_ urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else { return false }
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.httpMethod = "HEAD"
        return (try? await URLSession.shared.data(for: request)) != nil
    }

    deinit { monitor.cancel() }
}
