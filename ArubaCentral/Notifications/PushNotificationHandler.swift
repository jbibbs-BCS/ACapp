import Foundation
import Combine
import UserNotifications
import UIKit

// Replace with actual relay endpoint before shipping (open item #3)
private let relayBaseURL = URL(string: "https://relay.example.com")!

@MainActor
final class PushNotificationHandler: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    @Published private(set) var deviceToken: String? = nil
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Registration

    func requestAuthorizationAndRegister() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                await UIApplication.shared.registerForRemoteNotifications()
            }
            authorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        } catch {
            // Authorization request failed — user can enable in Settings
        }
    }

    func didRegister(deviceToken token: Data) {
        let tokenString = token.map { String(format: "%02x", $0) }.joined()
        deviceToken = tokenString
        Task { await postTokenToRelay(token: tokenString) }
    }

    func didFailRegistration(error: Error) {
        // APNs registration failed — fallback polling handles alert delivery
    }

    // MARK: - Incoming notification handling

    func handleIncomingNotification(userInfo: [AnyHashable: Any]) {
        guard let alertId = alertId(from: userInfo) else { return }
        NotificationCenter.default.post(
            name: .didReceiveAlertNotification,
            object: nil,
            userInfo: ["alert_id": alertId]
        )
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in self.handleIncomingNotification(userInfo: userInfo) }
        completionHandler()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner even when app is foregrounded
        completionHandler([.banner, .badge, .sound])
    }

    // MARK: - Payload helpers (internal for testability)

    func alertId(from userInfo: [AnyHashable: Any]) -> String? {
        userInfo["alert_id"] as? String
    }

    func severity(from userInfo: [AnyHashable: Any]) -> AlertSeverity {
        guard let raw = userInfo["severity"] as? String,
              let severity = AlertSeverity(rawValue: raw) else { return .info }
        return severity
    }

    func shouldShow(severity: AlertSeverity, prefs: NotificationPreferences) -> Bool {
        prefs.isEnabled(for: severity)
    }

    // MARK: - Relay registration

    private func postTokenToRelay(token: String) async {
        let prefs = NotificationPreferences.load()
        let body: [String: Any] = [
            "device_token": token,
            "platform": "apns",
            "preferences": [
                "critical": prefs.critical,
                "major":    prefs.major,
                "minor":    prefs.minor,
                "info":     prefs.info
            ]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        var request = URLRequest(url: relayBaseURL.appendingPathComponent("/register"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        _ = try? await URLSession.shared.data(for: request)
        // Relay registration failure is silent — fallback polling covers missed alerts
    }
}
