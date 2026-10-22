import Foundation
import UserNotifications
import AppKit
import CoreLocation
import UniformTypeIdentifiers

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

    /// Posts a notification with a map thumbnail and a type icon. The siren (if any)
    /// is played separately by the caller, so this never waits on the map download.
    /// `origin` is the user's location, shown as a blue dot on the map when in frame.
    func notify(incident: Incident, distanceKm: Double?, origin: CLLocationCoordinate2D?, playSound: Bool = true) {
        let content = UNMutableNotificationContent()
        let emoji = incident.kind.emoji
        if incident.isOfficialWarning {
            // displayTitle already leads with the warning level, e.g. "Advice — Stay Informed".
            content.title = "\(emoji) \(incident.displayTitle)"
        } else {
            content.title = "\(emoji) \(incident.severityLabel): \(incident.displayTitle)"
        }
        var bodyParts = [incident.displayLocation]
        if let distanceKm {
            bodyParts.append(String(format: "%.0f km away", distanceKm))
        }
        if !incident.isOfficialWarning, let status = incident.status {
            bodyParts.append(status)
        }
        content.body = bodyParts.joined(separator: " — ")
        content.sound = playSound ? .default : nil

        Task { @MainActor in
            if let imageURL = await NotificationImageRenderer.renderPNG(for: incident, origin: origin, distanceKm: distanceKm),
               let attachment = try? UNNotificationAttachment(
                   identifier: "map",
                   url: imageURL,
                   options: [UNNotificationAttachmentOptionsTypeHintKey: UTType.png.identifier]
               ) {
                content.attachments = [attachment]
            }

            let request = UNNotificationRequest(
                identifier: "incident-\(incident.id)",
                content: content,
                trigger: nil
            )
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                print("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show the banner even while the app is already frontmost. The sound option only
        // applies if the notification carries one, so alarm-only alerts stay silent here.
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
