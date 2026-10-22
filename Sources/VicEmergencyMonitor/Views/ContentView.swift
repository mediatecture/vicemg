import SwiftUI
import CoreLocation
import AppKit

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var fetcher: IncidentFetcher

    @StateObject private var alertManager = NearbyAlertManager()
    @State private var showSettings = false

    private var effectiveCoordinate: CLLocationCoordinate2D? {
        if settings.useDeviceLocation {
            return locationManager.currentLocation
        }
        return CLLocationCoordinate2D(latitude: settings.manualLatitude, longitude: settings.manualLongitude)
    }

    struct FilteredIncident {
        let incident: Incident
        let distanceKm: Double?
    }

    private var hasNearbyIncident: Bool {
        effectiveCoordinate != nil && !filtered.isEmpty
    }

    private var filtered: [FilteredIncident] {
        let origin = effectiveCoordinate.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        let items: [FilteredIncident] = fetcher.incidents.compactMap { incident in
            guard !settings.enabledCategories.isEmpty ? settings.enabledCategories.contains(incident.category1 ?? "") : true else {
                return nil
            }
            guard let origin else { return FilteredIncident(incident: incident, distanceKm: nil) }
            let coord = incident.coordinate
            let distanceKm = origin.distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude)) / 1000
            guard distanceKm <= settings.radiusKm else { return nil }
            return FilteredIncident(incident: incident, distanceKm: distanceKm)
        }
        return items.sorted { lhs, rhs in
            if lhs.incident.severity != rhs.incident.severity {
                return lhs.incident.severity > rhs.incident.severity
            }
            return (lhs.distanceKm ?? .greatestFiniteMagnitude) < (rhs.distanceKm ?? .greatestFiniteMagnitude)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if effectiveCoordinate == nil {
                noLocationPrompt
            } else if filtered.isEmpty {
                emptyState
            } else {
                List(filtered, id: \.incident.id) { item in
                    if let url = item.incident.detailURL {
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            IncidentRow(incident: item.incident, distanceKm: item.distanceKm)
                        }
                        .buttonStyle(.plain)
                        .help("Open on emergency.vic.gov.au")
                    } else {
                        IncidentRow(incident: item.incident, distanceKm: item.distanceKm)
                    }
                }
                .listStyle(.inset)
            }

            footer
        }
        .frame(minWidth: 380, minHeight: 460)
        .border(Color.red, width: hasNearbyIncident ? 4 : 0)
        .background(WindowAccessor(keepOnTop: settings.keepOnTop))
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(locationManager)
                .environmentObject(fetcher)
        }
        .task {
            NotificationManager.shared.configure()
            fetcher.start()
            if settings.useDeviceLocation {
                locationManager.detectLocation()
            }
        }
        .onChange(of: fetcher.lastUpdated) { _ in
            alertManager.evaluate(filtered, origin: effectiveCoordinate, settings: settings)
        }
        .onChange(of: settings.radiusKm) { _ in
            alertManager.evaluate(filtered, origin: effectiveCoordinate, settings: settings)
        }
        .onChange(of: settings.enabledCategories) { _ in
            alertManager.evaluate(filtered, origin: effectiveCoordinate, settings: settings)
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: hasNearbyIncident ? "exclamationmark.triangle.fill" : "shield")
            Text(hasNearbyIncident ? "Incident within \(Int(settings.radiusKm)) km" : "VicEmergency Monitor")
                .font(.headline)
            Spacer()
            if fetcher.isFetching {
                ProgressView().controlSize(.small)
            }
            Button {
                Task { await fetcher.fetchOnce() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh now")

            Toggle(isOn: $settings.keepOnTop) {
                Image(systemName: settings.keepOnTop ? "pin.fill" : "pin")
            }
            .toggleStyle(.button)
            .buttonStyle(.borderless)
            .help("Keep window on top")

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
        }
        .padding(10)
        .foregroundStyle(hasNearbyIncident ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        .background(hasNearbyIncident ? AnyShapeStyle(Color.red) : AnyShapeStyle(.bar))
        .animation(.easeInOut(duration: 0.3), value: hasNearbyIncident)
    }

    private var noLocationPrompt: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "location.slash")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No location set")
                .font(.subheadline.weight(.semibold))
            Text("Open Settings to use your Mac's location or enter one manually.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
            Button("Open Settings") { showSettings = true }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "checkmark.shield")
                .font(.system(size: 28))
                .foregroundStyle(.green)
            Text("No incidents within \(Int(settings.radiusKm)) km")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Attribution required by Emergency Management Victoria's emergency data notice:
    /// name the source, link the notice, and show when the feed was last updated.
    /// https://www.emv.vic.gov.au/responsibilities/victorias-warning-system/emergency-data
    private static let attribution: AttributedString = {
        let markdown = "Data: State of Victoria, Australia, under [CC BY 3.0 AU](https://creativecommons.org/licenses/by/3.0/au/). [Emergency data notice](https://www.emv.vic.gov.au/responsibilities/victorias-warning-system/emergency-data)"
        return (try? AttributedString(markdown: markdown)) ?? AttributedString("Data: State of Victoria, Australia")
    }()

    private var footer: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let error = fetcher.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
            }
            if let updated = fetcher.lastUpdated {
                Text("Last updated from feed: \(updated.formatted(date: .abbreviated, time: .standard))")
            } else {
                Text("Waiting for first update from feed…")
            }
            Text(Self.attribution)
            Text("Use more than one source in an emergency; this app is not a substitute for official VicEmergency alerts. Click an item to open it on VicEmergency.")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.bar)
    }
}
