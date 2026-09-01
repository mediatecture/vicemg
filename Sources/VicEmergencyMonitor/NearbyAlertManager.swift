import Foundation

/// Tracks which nearby incidents we've already notified about, so a notification
/// only fires the first time an incident enters range — not on every poll.
@MainActor
final class NearbyAlertManager: ObservableObject {
    private var notifiedIncidentIDs: Set<String> = []
    private var hasSeeded = false

    func evaluate(_ nearby: [ContentView.FilteredIncident]) {
        let currentIDs = Set(nearby.map { $0.incident.id })

        guard hasSeeded else {
            // Don't fire a notification storm for incidents already in range on first load.
            notifiedIncidentIDs = currentIDs
            hasSeeded = true
            return
        }

        let newIDs = currentIDs.subtracting(notifiedIncidentIDs)
        for item in nearby where newIDs.contains(item.incident.id) {
            NotificationManager.shared.notify(incident: item.incident, distanceKm: item.distanceKm)
        }
        notifiedIncidentIDs.formUnion(currentIDs)
    }
}
