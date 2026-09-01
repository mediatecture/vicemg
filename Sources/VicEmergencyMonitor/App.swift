import SwiftUI

@main
struct VicEmergencyMonitorApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var locationManager = LocationManager()
    @StateObject private var fetcher: IncidentFetcher

    init() {
        let settings = AppSettings()
        _settings = StateObject(wrappedValue: settings)
        _fetcher = StateObject(wrappedValue: IncidentFetcher(settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(locationManager)
                .environmentObject(fetcher)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
