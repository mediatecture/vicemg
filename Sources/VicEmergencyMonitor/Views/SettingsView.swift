import SwiftUI
import AppKit
import CoreLocation

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var fetcher: IncidentFetcher
    @Environment(\.dismiss) private var dismiss

    /// Category list built from whatever the live feed currently contains —
    /// includes both incident hazard types (Fire, Tree Down, ...) and the
    /// official warning levels (Advice, Watch and Act, Emergency Warning).
    private var categories: [String] {
        let known = Set(fetcher.incidents.compactMap { $0.category1 })
        let priority = ["Emergency Warning", "Watch and Act", "Advice"]
        let ordered = priority.filter { known.contains($0) }
        let rest = known.subtracting(priority).sorted()
        return ordered + rest
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.title3.weight(.semibold))

            GroupBox("Location") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Use this Mac's current location", isOn: $settings.useDeviceLocation)
                        .onChange(of: settings.useDeviceLocation) { useDevice in
                            if useDevice { locationManager.detectLocation() }
                        }

                    if settings.useDeviceLocation {
                        HStack {
                            statusText
                            Spacer()
                            Button {
                                locationManager.detectLocation()
                            } label: {
                                if locationManager.isLocating {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Text("Detect Now")
                                }
                            }
                            .disabled(locationManager.isLocating)
                        }

                        if locationManager.isDenied {
                            Button("Open Location Services Settings…") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .font(.caption)
                        }
                        if let error = locationManager.lastError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Label (e.g. Home)", text: $settings.manualLocationLabel)
                            HStack {
                                TextField("Latitude", value: $settings.manualLatitude, format: .number)
                                TextField("Longitude", value: $settings.manualLongitude, format: .number)
                            }
                            Text("Tip: right-click a spot in Apple/Google Maps to copy its coordinates.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(8)
            }

            GroupBox("Alert radius") {
                VStack(alignment: .leading) {
                    HStack {
                        Slider(value: $settings.radiusKm, in: 5...200, step: 5)
                        Text("\(Int(settings.radiusKm)) km")
                            .frame(width: 56, alignment: .trailing)
                            .monospacedDigit()
                    }
                }
                .padding(8)
            }

            GroupBox("Refresh interval") {
                Picker("", selection: $settings.refreshIntervalSeconds) {
                    Text("30 seconds").tag(30.0)
                    Text("1 minute").tag(60.0)
                    Text("2 minutes").tag(120.0)
                    Text("5 minutes").tag(300.0)
                }
                .pickerStyle(.segmented)
                .padding(8)
            }

            GroupBox("Alarm") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Play alarm sound when a new incident appears nearby", isOn: $settings.alarmEnabled)
                    Toggle("Only for official warnings and active fires", isOn: $settings.alarmOnlyForSevere)
                        .disabled(!settings.alarmEnabled)
                    HStack {
                        Button("Test alarm") { AlarmPlayer.shared.play() }
                        Button("Stop") { AlarmPlayer.shared.stop() }
                    }
                }
                .padding(8)
            }

            GroupBox("Notifications") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button("Send test notification") { sendTestNotification() }
                            .disabled(fetcher.incidents.isEmpty)
                        Button("Open Notification Settings…") { NotificationManager.shared.openSystemNotificationSettings() }
                    }
                    Text("Not seeing banners? In System Settings › Notifications › VicEmergency Monitor, turn off \"Summarise notifications\" (macOS otherwise holds alerts for a later digest). Also check that no Focus mode is on, and that notifications aren't set to Off while mirroring or sharing the display.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
            }

            GroupBox("Categories") {
                VStack(alignment: .leading, spacing: 4) {
                    if categories.isEmpty {
                        Text("Loading categories from the live feed…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(categories, id: \.self) { category in
                            Toggle(category, isOn: binding(for: category))
                        }
                    }
                    Text("All types shown when none are selected.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    /// Sends a real-looking notification for the nearest current incident, so the
    /// map thumbnail and icon can be previewed on demand.
    private func sendTestNotification() {
        let origin: CLLocationCoordinate2D? = settings.useDeviceLocation
            ? locationManager.currentLocation
            : CLLocationCoordinate2D(latitude: settings.manualLatitude, longitude: settings.manualLongitude)

        func distanceKm(_ incident: Incident) -> Double? {
            guard let origin else { return nil }
            return CLLocation(latitude: origin.latitude, longitude: origin.longitude)
                .distance(from: CLLocation(latitude: incident.coordinate.latitude, longitude: incident.coordinate.longitude)) / 1000
        }

        let nearest = fetcher.incidents.min { (distanceKm($0) ?? .greatestFiniteMagnitude) < (distanceKm($1) ?? .greatestFiniteMagnitude) }
        guard let incident = nearest else { return }
        NotificationManager.shared.notify(incident: incident, distanceKm: distanceKm(incident), origin: origin, unique: true)
    }

    private var statusText: some View {
        Group {
            if let loc = locationManager.currentLocation {
                Text(String(format: "%.3f, %.3f", loc.latitude, loc.longitude))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(statusDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusDescription: String {
        switch locationManager.authorizationStatus {
        case .notDetermined: return "Location not yet requested"
        case .denied: return "Location access denied"
        case .restricted: return "Location access restricted"
        default: return "Waiting for location…"
        }
    }

    private func binding(for category: String) -> Binding<Bool> {
        Binding(
            get: { settings.enabledCategories.isEmpty || settings.enabledCategories.contains(category) },
            set: { isOn in
                var set = settings.enabledCategories
                if set.isEmpty {
                    // Expand "all" into the explicit set minus this one.
                    set = Set(categories)
                }
                if isOn {
                    set.insert(category)
                } else {
                    set.remove(category)
                }
                if set == Set(categories) { set = [] }
                settings.enabledCategories = set
            }
        )
    }
}
