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

    private var fullContent: some View {
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
    }

    // MARK: - Mini (pinned) layout

    /// Attribution for the mini view: same source / notice requirements as the full footer,
    /// in a shorter form.
    private static let miniAttribution: AttributedString =
        attribution + AttributedString(" Not a substitute for official alerts.")

    private static let miniWidth: CGFloat = 280
    private var miniContent: some View {
        let items = filtered
        return VStack(alignment: .leading, spacing: 0) {
            miniHeader(count: items.count)

            if effectiveCoordinate == nil {
                miniNote("No location set. Unpin to open Settings.")
            } else if items.isEmpty {
                miniNote("No incidents within \(Int(settings.radiusKm)) km")
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(items.prefix(3), id: \.incident.id) { item in
                        miniRow(item)
                    }
                    if items.count > 3 {
                        Text("+\(items.count - 3) more, unpin to see all")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.top, 2)
                    }
                }
                .padding(.vertical, 4)
            }

            miniFooter
        }
        .frame(width: Self.miniWidth)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func miniHeader(count: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: hasNearbyIncident ? "exclamationmark.triangle.fill" : (effectiveCoordinate == nil ? "location.slash" : "shield"))
                .font(.system(size: 12))
            Text(hasNearbyIncident ? "\(count) nearby" : (effectiveCoordinate == nil ? "No location" : "All clear"))
                .font(.system(size: 12, weight: .semibold))
            Spacer(minLength: 0)
            if fetcher.isFetching {
                ProgressView().controlSize(.mini)
            }
            Button {
                Task { await fetcher.fetchOnce() }
            } label: {
                Image(systemName: "arrow.clockwise").font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .help("Refresh now")

            Toggle(isOn: $settings.keepOnTop) {
                Image(systemName: "pin.fill").font(.system(size: 11))
            }
            .toggleStyle(.button)
            .buttonStyle(.borderless)
            .help("Unpin: back to the full window")
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .frame(height: 28)
        .foregroundStyle(hasNearbyIncident ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        .background(hasNearbyIncident ? AnyShapeStyle(Color.red) : AnyShapeStyle(.bar))
        .animation(.easeInOut(duration: 0.3), value: hasNearbyIncident)
    }

    @ViewBuilder
    private func miniRow(_ item: FilteredIncident) -> some View {
        let row = HStack(spacing: 6) {
            Text(item.incident.kind.emoji)
                .font(.system(size: 12))
            Text(item.incident.displayTitle)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 4)
            if let distance = item.distanceKm {
                Text("\(Int(distance.rounded())) km")
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .contentShape(Rectangle())

        if let url = item.incident.detailURL {
            Button {
                NSWorkspace.shared.open(url)
            } label: {
                row
            }
            .buttonStyle(.plain)
            .help("\(item.incident.displayLocation) · open on emergency.vic.gov.au")
        } else {
            row
        }
    }

    private func miniNote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
    }

    private var miniFooter: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let error = fetcher.errorMessage {
                Text(error).foregroundStyle(.red)
            }
            if let updated = fetcher.lastUpdated {
                Text("Updated \(updated.formatted(.dateTime.day().month(.abbreviated).hour().minute().second()))")
            } else {
                Text("Waiting for first update…")
            }
            Text(Self.miniAttribution)
        }
        .font(.system(size: 9))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.bar)
    }

    var body: some View {
        Group {
            // Pinning ("keep on top") collapses the window into a compact mini view.
            if settings.keepOnTop {
                miniContent
            } else {
                fullContent
            }
        }
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
