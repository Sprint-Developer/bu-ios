import Foundation
import CoreLocation
import Combine

@MainActor
final class PrayerService: NSObject, ObservableObject, CLLocationManagerDelegate {
    /// One instance app-wide — a second one would spin up a second CLLocationManager
    /// and re-prompt / re-fetch every time Settings opened.
    static let shared = PrayerService()

    @Published var day: PrayerDay?
    @Published var status = "Locating…"
    @Published var cityLabel = ""
    @Published var latitude: Double = 25.2048
    @Published var longitude: Double = 55.2708
    /// True when times come from the Dubai fallback rather than the device location.
    @Published var usingFallbackLocation = false

    static let fallbackLatitude = 25.2048
    static let fallbackLongitude = 55.2708

    private let manager = CLLocationManager()
    private var asked = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        if let data = UserDefaults.standard.data(forKey: "beummati.prayer.day.cache"),
           let cached = try? JSONDecoder().decode(PrayerDay.self, from: data) {
            day = cached
            status = "Cached times"
        }
    }

    func refresh() {
        let auth = manager.authorizationStatus
        switch auth {
        case .notDetermined:
            status = "Allow location for prayer times"
            manager.requestWhenInUseAuthorization()
            // Don't leave Home blank while the prompt is unanswered.
            if day == nil { useFallbackLocation() }
        case .authorizedAlways, .authorizedWhenInUse:
            status = "Updating prayer times…"
            manager.requestLocation()
        default:
            status = "Location off — using Dubai"
            useFallbackLocation()
        }
    }

    /// Load Dubai times — used when location is denied, fails, or is still unanswered.
    func useFallbackLocation() {
        usingFallbackLocation = true
        cityLabel = "Dubai"
        Task { await load(lat: Self.fallbackLatitude, lon: Self.fallbackLongitude) }
    }

    /// Next upcoming prayer name + time for Today glance / widgets.
    func nextPrayer() -> (name: String, time: String)? {
        if let next = nextPrayerFire() { return (next.name, next.time) }
        guard let day else { return nil }
        return ("Fajr", day.fajr)
    }

    /// Next prayer with the exact moment it lands, rolling to tomorrow's Fajr once Isha has passed.
    /// Home needs the date (not just the string) or the countdown pins at 0m all evening.
    func nextPrayerFire() -> (name: String, time: String, fire: Date)? {
        guard let day else { return nil }
        let pairs = [("Fajr", day.fajr), ("Dhuhr", day.dhuhr), ("Asr", day.asr), ("Maghrib", day.maghrib), ("Isha", day.isha)]
        let now = Date()
        for (name, time) in pairs {
            if let fire = PrayerNotifications.parseToday(time: time), fire > now {
                return (name, time, fire)
            }
        }
        guard let fajrToday = PrayerNotifications.parseToday(time: day.fajr),
              let fajrTomorrow = Calendar.current.date(byAdding: .day, value: 1, to: fajrToday)
        else { return nil }
        return ("Fajr", day.fajr, fajrTomorrow)
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.refresh() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.usingFallbackLocation = false
            self.latitude = loc.coordinate.latitude
            self.longitude = loc.coordinate.longitude
            self.cityLabel = String(format: "%.2f, %.2f", loc.coordinate.latitude, loc.coordinate.longitude)
            await self.load(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.status = "Location failed — Dubai times"
            self.useFallbackLocation()
        }
    }

    private func load(lat: Double, lon: Double) async {
        latitude = lat
        longitude = lon
        let url = URL(string: "https://api.aladhan.com/v1/timings?latitude=\(lat)&longitude=\(lon)&method=4")!
        do {
            var req = URLRequest(url: url)
            req.setValue(AppIdentity.userAgent, forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: req)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let dataObj = json?["data"] as? [String: Any],
                  let timings = dataObj["timings"] as? [String: String],
                  let date = dataObj["date"] as? [String: Any],
                  let hijri = date["hijri"] as? [String: Any],
                  let weekday = hijri["weekday"] as? [String: String],
                  let month = hijri["month"] as? [String: Any]
            else {
                status = "Could not parse times"
                return
            }
            let monthEn = month["en"] as? String ?? ""
            let dayNum = hijri["day"] as? String ?? ""
            let year = hijri["year"] as? String ?? ""
            let parsed = PrayerDay(
                fajr: clean(timings["Fajr"]),
                sunrise: clean(timings["Sunrise"]),
                dhuhr: clean(timings["Dhuhr"]),
                asr: clean(timings["Asr"]),
                maghrib: clean(timings["Maghrib"]),
                isha: clean(timings["Isha"]),
                hijriDate: "\(dayNum) \(monthEn) \(year)",
                hijriWeekday: weekday["en"] ?? "",
                gregorian: (date["readable"] as? String) ?? ""
            )
            day = parsed
            if let encoded = try? JSONEncoder().encode(parsed) {
                UserDefaults.standard.set(encoded, forKey: "beummati.prayer.day.cache")
            }
            if let next = nextPrayer() {
                WidgetSnapshot.writePrayer(parsed, nextName: next.name, nextTime: next.time)
            }
            PrayerNotifications.shared.reschedule(day: parsed)
            status = usingFallbackLocation ? "Dubai times — allow location for yours" : "Updated"
        } catch {
            if day != nil {
                status = "Offline — showing cached times"
                PrayerNotifications.shared.reschedule(day: day)
            } else {
                status = error.localizedDescription
            }
        }
    }

    private func clean(_ s: String?) -> String {
        (s ?? "—").components(separatedBy: " ").first ?? "—"
    }
}
