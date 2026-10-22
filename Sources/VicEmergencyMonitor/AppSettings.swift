import Foundation

/// Persisted user configuration, backed by UserDefaults.
final class AppSettings: ObservableObject {
    @Published var useDeviceLocation: Bool { didSet { save() } }
    @Published var manualLatitude: Double { didSet { save() } }
    @Published var manualLongitude: Double { didSet { save() } }
    @Published var manualLocationLabel: String { didSet { save() } }
    @Published var radiusKm: Double { didSet { save() } }
    @Published var refreshIntervalSeconds: Double { didSet { save() } }
    /// Empty set means "show all categories".
    @Published var enabledCategories: Set<String> { didSet { save() } }
    @Published var keepOnTop: Bool { didSet { save() } }
    @Published var alarmEnabled: Bool { didSet { save() } }
    /// When true, the siren only sounds for official warnings and active fires;
    /// other new nearby incidents get a normal notification sound instead.
    @Published var alarmOnlyForSevere: Bool { didSet { save() } }
    /// Emergency types (`Incident.Kind` raw values) the user has silenced. Stored as the
    /// muted set so a type added later defaults to making sound.
    @Published var mutedSoundKinds: Set<String> { didSet { save() } }

    private let defaults = UserDefaults.standard

    init() {
        let d = UserDefaults.standard
        useDeviceLocation = (d.object(forKey: "useDeviceLocation") as? Bool) ?? true
        manualLatitude = (d.object(forKey: "manualLatitude") as? Double) ?? -37.8136
        manualLongitude = (d.object(forKey: "manualLongitude") as? Double) ?? 144.9631
        manualLocationLabel = (d.string(forKey: "manualLocationLabel")) ?? "Melbourne CBD"
        radiusKm = (d.object(forKey: "radiusKm") as? Double) ?? 25
        refreshIntervalSeconds = (d.object(forKey: "refreshIntervalSeconds") as? Double) ?? 60
        enabledCategories = Set((d.array(forKey: "enabledCategories") as? [String]) ?? [])
        keepOnTop = (d.object(forKey: "keepOnTop") as? Bool) ?? false
        alarmEnabled = (d.object(forKey: "alarmEnabled") as? Bool) ?? true
        alarmOnlyForSevere = (d.object(forKey: "alarmOnlyForSevere") as? Bool) ?? true
        mutedSoundKinds = Set((d.array(forKey: "mutedSoundKinds") as? [String]) ?? [])
    }

    func isSoundEnabled(for kind: Incident.Kind) -> Bool {
        !mutedSoundKinds.contains(kind.rawValue)
    }

    func setSound(_ enabled: Bool, for kind: Incident.Kind) {
        if enabled {
            mutedSoundKinds.remove(kind.rawValue)
        } else {
            mutedSoundKinds.insert(kind.rawValue)
        }
    }

    private func save() {
        defaults.set(useDeviceLocation, forKey: "useDeviceLocation")
        defaults.set(manualLatitude, forKey: "manualLatitude")
        defaults.set(manualLongitude, forKey: "manualLongitude")
        defaults.set(manualLocationLabel, forKey: "manualLocationLabel")
        defaults.set(radiusKm, forKey: "radiusKm")
        defaults.set(refreshIntervalSeconds, forKey: "refreshIntervalSeconds")
        defaults.set(Array(enabledCategories), forKey: "enabledCategories")
        defaults.set(keepOnTop, forKey: "keepOnTop")
        defaults.set(alarmEnabled, forKey: "alarmEnabled")
        defaults.set(alarmOnlyForSevere, forKey: "alarmOnlyForSevere")
        defaults.set(Array(mutedSoundKinds), forKey: "mutedSoundKinds")
    }
}
