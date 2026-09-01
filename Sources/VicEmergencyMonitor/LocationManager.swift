import Foundation
import CoreLocation

/// Wraps CLLocationManager to provide the Mac's current location on demand,
/// using the system's built-in Location Services (not a manually-typed coordinate).
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var lastError: String?
    @Published var isLocating: Bool = false

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    /// Kicks off (or continues) the permission + one-shot location fetch flow.
    func detectLocation() {
        lastError = nil
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            isLocating = true
            manager.requestLocation()
        case .denied, .restricted:
            lastError = "Location access is denied. Enable it in System Settings > Privacy & Security > Location Services."
        @unknown default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            if self.isAuthorized {
                self.isLocating = true
                manager.requestLocation()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async {
            self.isLocating = false
            if let loc = locations.last {
                self.currentLocation = loc.coordinate
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isLocating = false
            self.lastError = error.localizedDescription
        }
    }
}
