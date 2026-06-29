import Foundation
import BackgroundTasks
import UserNotifications

final class AlertBackgroundRefresh {
    static let taskIdentifier = "com.aruba.central.alertrefresh"
    nonisolated(unsafe) static var shared: AlertBackgroundRefresh?

    private let apiClient: CentralAPIClientProtocol

    init(apiClient: CentralAPIClientProtocol) {
        self.apiClient = apiClient
    }

    static func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            AlertBackgroundRefresh.handle(task: refreshTask)
        }
    }

    static func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(task: BGAppRefreshTask) {
        scheduleNext()
        guard let refresher = AlertBackgroundRefresh.shared else {
            task.setTaskCompleted(success: false)
            return
        }
        let prefs = NotificationPreferences.load()
        let workTask = Task {
            do {
                let alerts = try await refresher.fetchUnacknowledgedAlerts()
                let filtered = refresher.filter(alerts: alerts, by: prefs)
                await refresher.postLocalNotifications(for: filtered)
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
        task.expirationHandler = { workTask.cancel() }
    }

    func fetchUnacknowledgedAlerts() async throws -> [CentralAlert] {
        let page = try await apiClient.fetchAlerts(limit: 100, offset: 0)
        return page.items.filter { !$0.isCleared }
    }

    func filter(alerts: [CentralAlert], by prefs: NotificationPreferences) -> [CentralAlert] {
        alerts.filter { prefs.isEnabled(for: $0.severity) }
    }

    func postLocalNotifications(for alerts: [CentralAlert]) async {
        let center = UNUserNotificationCenter.current()
        for alert in alerts {
            let content = UNMutableNotificationContent()
            content.title = alert.name
            content.body  = alert.description ?? "\(alert.severity.rawValue) alert at \(alert.siteName ?? "unknown site")"
            content.sound = .default
            content.userInfo = ["alert_id": alert.id, "severity": alert.severity.rawValue]

            let request = UNNotificationRequest(
                identifier: "alert-\(alert.id)",
                content: content,
                trigger: nil
            )
            try? await center.add(request)
        }
    }
}
