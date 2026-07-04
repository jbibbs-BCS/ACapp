import Foundation
import Combine

@MainActor
final class AlertsViewModel: ObservableObject {
    @Published private(set) var alertsState: LoadState<[CentralAlert]> = .idle
    @Published var actionError: APIError? = nil

    private let client: CentralAPIClientProtocol
    private let pageSize = 100
    private var nextCursor: String? = nil
    private var hasMore  = false
    private var isLoadingMore = false

    var unacknowledgedCount: Int {
        guard case .loaded(let alerts) = alertsState else { return 0 }
        return alerts.filter { !$0.isCleared }.count
    }

    init(apiClient: CentralAPIClientProtocol) {
        self.client = apiClient
    }

    func load() async {
        alertsState = .loading
        nextCursor = nil
        await fetchAlerts(next: nil, appending: false)
    }

    func refresh() async {
        nextCursor = nil
        await fetchAlerts(next: nil, appending: false)
    }

    func loadNextPage() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        await fetchAlerts(next: nextCursor, appending: true)
    }

    func acknowledge(alertId: String) async {
        do {
            try await client.clearAlert(alertId: alertId)
            // Update locally — mark as cleared without a full refetch
            if case .loaded(let alerts) = alertsState {
                let updated = alerts.map { alert in
                    guard alert.id == alertId else { return alert }
                    return CentralAlert(id: alert.id, name: alert.name,
                                        severity: alert.severity,
                                        description: alert.description,
                                        deviceSerial: alert.deviceSerial,
                                        siteName: alert.siteName,
                                        createdAt: alert.createdAt,
                                        isCleared: true,
                                        category: alert.category,
                                        deviceType: alert.deviceType,
                                        priority: alert.priority,
                                        status: "Cleared",
                                        clearedReason: alert.clearedReason,
                                        updatedAt: alert.updatedAt)
                }
                alertsState = .loaded(updated)
            }
        } catch let error as APIError {
            actionError = error
        } catch {
            actionError = .networkError
        }
    }

    private func fetchAlerts(next: String?, appending: Bool) async {
        do {
            let page = try await client.fetchAlerts(limit: pageSize, next: next)
            self.nextCursor = page.next
            self.hasMore    = page.hasMore

            if appending, case .loaded(let existing) = alertsState {
                alertsState = .loaded(existing + page.items)
            } else {
                alertsState = .loaded(page.items)
            }
        } catch let error as APIError {
            if !appending { alertsState = .error(error) }
        } catch {
            if !appending { alertsState = .error(.networkError) }
        }
    }
}
