import Foundation
import UserNotifications
import AppKit

/// Posts native macOS notification banners for incidents that newly enter range.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private override init() {
        super.init()
    }

    func configure() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error {
                print("Notification authorization error: \(error.localizedDescription)")
            }
        }
    }

    func notify(incident: Incident, distanceKm: Double?) {
        let content = UNMutableNotificationContent()
        let prefix = incident.isOfficialWarning ? "🚨" : "⚠️"
        content.title = "\(prefix) \(incident.severityLabel): \(incident.displayTitle)"
        var bodyParts = [incident.displayLocation]
        if let distanceKm {
            bodyParts.append(String(format: "%.0f km away", distanceKm))
        }
        if !incident.isOfficialWarning, let status = incident.status {
            bodyParts.append(status)
        }
        content.body = bodyParts.joined(separator: " — ")
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "incident-\(incident.id)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show the banner even while the app is already frontmost.
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        NSApp.activate(ignoringOtherApps: true)
        completionHandler()
    }
}
