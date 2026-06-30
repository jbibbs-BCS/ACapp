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
        #if targetEnvironment(simulator) || os(macOS)
        return  // NWPathMonitor unreliable on simulator; macOS sandbox blocks probes
        #endif

        monitor.pathUpdateHandler = { [weak self] path in
            let satisfied = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.offlineTask?.cancel()
                if satisfied {
                    self.isConnected = true
                } else {
                    // Verify with TCP probes before showing the banner.
                    // Raw TCP bypasses app-layer blocks that affect URLSession.
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

    // TCP probes to known IPs — no DNS needed, harder to block than HTTP.
    private static func checkReachability() async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            for (host, port) in [("1.1.1.1", 53), ("8.8.8.8", 53), ("17.253.144.10", 443)] {
                group.addTask { await tcpProbe(host: host, port: UInt16(port)) }
            }
            for await result in group {
                if result { return true }
            }
            return false
        }
    }

    private static func tcpProbe(host: String, port: UInt16) async -> Bool {
        await withCheckedContinuation { continuation in
            let conn = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: port)!,
                using: .tcp
            )
            let q = DispatchQueue(label: "com.aruba.central.probe.\(host)")
            var done = false
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard !done else { return }
                    done = true
                    conn.cancel()
                    continuation.resume(returning: true)
                case .failed, .cancelled:
                    guard !done else { return }
                    done = true
                    continuation.resume(returning: false)
                default:
                    break
                }
            }
            conn.start(queue: q)
            q.asyncAfter(deadline: .now() + 5) {
                guard !done else { return }
                done = true
                conn.cancel()
                continuation.resume(returning: false)
            }
        }
    }

    deinit { monitor.cancel() }
}
