import Foundation
import CoreLocation
import Combine

@MainActor
final class QiblaService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var heading: Double = 0
    @Published var qiblaBearing: Double = 0
    @Published var status = "Locating…"
    @Published var lat: Double?
    @Published var lon: Double?

    /// Relative angle to rotate the needle (0 = pointing up = toward Qibla when device faces that way).
    var needleRotation: Double {
        qiblaBearing - heading
    }

    private let manager = CLLocationManager()
    private let kaabaLat = 21.422487
    private let kaabaLon = 39.826206

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.headingFilter = 1
    }

    func start() {
        let auth = manager.authorizationStatus
        switch auth {
        case .notDetermined:
            status = "Allow location for Qibla"
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            status = "Point top of phone toward Qibla"
            manager.startUpdatingLocation()
            manager.startUpdatingHeading()
        default:
            status = "Location off — using Dubai"
            lat = 25.2048
            lon = 55.2708
            qiblaBearing = Self.bearing(fromLat: 25.2048, fromLon: 55.2708, toLat: kaabaLat, toLon: kaabaLon)
            manager.startUpdatingHeading()
        }
    }

    func stop() {
        manager.stopUpdatingHeading()
        manager.stopUpdatingLocation()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.start() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.lat = loc.coordinate.latitude
            self.lon = loc.coordinate.longitude
            self.qiblaBearing = Self.bearing(
                fromLat: loc.coordinate.latitude,
                fromLon: loc.coordinate.longitude,
                toLat: self.kaabaLat,
                toLon: self.kaabaLon
            )
            self.status = String(format: "Qibla · bearing %.0f°", self.qiblaBearing)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let h = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor in
            self.heading = h
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.status = "Location failed — Dubai Qibla"
            self.lat = 25.2048
            self.lon = 55.2708
            self.qiblaBearing = Self.bearing(fromLat: 25.2048, fromLon: 55.2708, toLat: self.kaabaLat, toLon: self.kaabaLon)
        }
    }

    static func bearing(fromLat: Double, fromLon: Double, toLat: Double, toLon: Double) -> Double {
        let φ1 = fromLat * .pi / 180
        let φ2 = toLat * .pi / 180
        let Δλ = (toLon - fromLon) * .pi / 180
        let y = sin(Δλ) * cos(φ2)
        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
        let θ = atan2(y, x) * 180 / .pi
        return (θ + 360).truncatingRemainder(dividingBy: 360)
    }
}
