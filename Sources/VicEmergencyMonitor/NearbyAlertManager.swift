import Foundation
import CoreLocation

/// Tracks which nearby incidents we've already notified about, so a notification
/// (and alarm) only fires the first time an incident enters range — not on every poll.
@MainActor
final class NearbyAlertManager: ObservableObject {
    private var notifiedIncidentIDs: Set<String> = []
    private var hasSeeded = false

    func evaluate(_ nearby: [ContentView.FilteredIncident], origin: CLLocationCoordinate2D?, settings: AppSettings) {
        let currentIDs = Set(nearby.map { $0.incident.id })

        guard hasSeeded else {
            // Don't fire a notification storm for incidents already in range on first load.
            notifiedIncidentIDs = currentIDs
            hasSeeded = true
            return
        }

        let newIDs = currentIDs.subtracting(notifiedIncidentIDs)
        var soundAlarm = false
        for item in nearby where newIDs.contains(item.incident.id) {
            let incident = item.incident
            let isSevere = incident.isOfficialWarning || incident.severity >= .high
            // Types the user has muted get no sound at all: no siren and no chime.
            let soundAllowed = settings.isSoundEnabled(for: incident.kind)
            let alarm = soundAllowed && settings.alarmEnabled && (!settings.alarmOnlyForSevere || isSevere)
            soundAlarm = soundAlarm || alarm
            // The siren replaces the default notification chime rather than stacking on it.
            NotificationManager.shared.notify(incident: incident, distanceKm: item.distanceKm, origin: origin, playSound: soundAllowed && !alarm)
        }
        if soundAlarm {
            AlarmPlayer.shared.play()
        }
        notifiedIncidentIDs.formUnion(currentIDs)
    }
}
