import Foundation
import CoreLocation

struct PendingLocation: Equatable {
    let name: String
    let latitude: Double
    let longitude: Double
}

@Observable @MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    var pendingLocation: PendingLocation?
    var isLocating = false
    var errorMessage: String?

    private var _manager: CLLocationManager?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    private var manager: CLLocationManager {
        if let m = _manager { return m }
        let m = CLLocationManager()
        m.desiredAccuracy = kCLLocationAccuracyHundredMeters
        m.delegate = self
        _manager = m
        return m
    }

    func attachLocation() async {
        isLocating = true
        errorMessage = nil

        do {
            // Request permission if needed
            let status = manager.authorizationStatus
            if status == .notDetermined {
                manager.requestWhenInUseAuthorization()
                // Wait briefly for the user to respond
                try await Task.sleep(for: .milliseconds(500))
            }

            let currentStatus = manager.authorizationStatus
            guard currentStatus == .authorizedWhenInUse || currentStatus == .authorizedAlways else {
                errorMessage = "Location access not authorized"
                isLocating = false
                return
            }

            // Get location via delegate callback
            let location = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CLLocation, Error>) in
                self.locationContinuation = continuation
                self.manager.requestLocation()
            }

            // Reverse geocode
            let geocoder = CLGeocoder()
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            let placemark = placemarks.first

            let name: String
            if let pName = placemark?.name, let subLocality = placemark?.subLocality {
                name = "\(pName), \(subLocality)"
            } else if let pName = placemark?.name, let locality = placemark?.locality {
                name = "\(pName), \(locality)"
            } else if let locality = placemark?.locality {
                name = locality
            } else {
                name = String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
            }

            pendingLocation = PendingLocation(
                name: name,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLocating = false
    }

    func clearPending() {
        pendingLocation = nil
    }

    func consumePending() -> PendingLocation? {
        let loc = pendingLocation
        pendingLocation = nil
        return loc
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            locationContinuation?.resume(returning: location)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationContinuation?.resume(throwing: error)
            locationContinuation = nil
        }
    }
}
