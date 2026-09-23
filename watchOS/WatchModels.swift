import Foundation
import CoreLocation
import Combine

struct WatchReminder: Identifiable, Codable {
    var id: String { ref }
    let ref: String
    let title: String
    let arabic: String
    let english: String
}

struct WatchPrayerDay {
    let fajr: String
    let dhuhr: String
    let asr: String
    let maghrib: String
    let isha: String
    let hijri: String
}

@MainActor
final class WatchPrayerModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var day: WatchPrayerDay?
    @Published var status = "Locating…"
    @Published var reminder: WatchReminder?
    @Published var dhikr = 0

    private let manager = CLLocationManager()
    private var reminders: [WatchReminder] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        loadReminders()
        rotateReminder()
        if let data = UserDefaults.standard.data(forKey: "beummati.watch.prayer"),
           let cached = try? JSONDecoder().decode(CachedDay.self, from: data) {
            day = WatchPrayerDay(fajr: cached.fajr, dhuhr: cached.dhuhr, asr: cached.asr, maghrib: cached.maghrib, isha: cached.isha, hijri: cached.hijri)
            status = "Cached"
        }
        dhikr = UserDefaults.standard.integer(forKey: "beummati.watch.dhikr")
    }

    func refresh() {
        rotateReminder()
        let auth = manager.authorizationStatus
        switch auth {
        case .notDetermined:
            status = "Allow location"
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            status = "Updating…"
            manager.requestLocation()
        default:
            status = "Dubai times"
            Task { await load(lat: 25.2048, lon: 55.2708) }
        }
    }

    func rotateReminder() {
        reminder = reminders.randomElement()
    }

    func tapDhikr() {
        dhikr += 1
        UserDefaults.standard.set(dhikr, forKey: "beummati.watch.dhikr")
    }

    func resetDhikr() {
        dhikr = 0
        UserDefaults.standard.set(0, forKey: "beummati.watch.dhikr")
    }

    func nextPrayer() -> (name: String, time: String)? {
        guard let day else { return nil }
        let pairs = [("Fajr", day.fajr), ("Dhuhr", day.dhuhr), ("Asr", day.asr), ("Maghrib", day.maghrib), ("Isha", day.isha)]
        let now = Date()
        for (name, time) in pairs {
            if let fire = Self.parseToday(time), fire > now { return (name, time) }
        }
        return ("Fajr", day.fajr)
    }

    func countdown() -> String {
        guard let next = nextPrayer(), let fire = Self.parseToday(next.time) else { return "—" }
        let secs = max(0, Int(fire.timeIntervalSinceNow))
        let h = secs / 3600
        let m = (secs % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.refresh() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            await self.load(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.status = "Dubai times"
            await self.load(lat: 25.2048, lon: 55.2708)
        }
    }

    private func loadReminders() {
        if let url = Bundle.main.url(forResource: "WatchReminders", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let list = try? JSONDecoder().decode([WatchReminder].self, from: data) {
            reminders = list
        }
        if reminders.isEmpty {
            reminders = [
                WatchReminder(ref: "94:5", title: "With hardship, ease", arabic: "فَإِنَّ مَعَ ٱلْعُسْرِ يُسْرًا", english: "So truly where there is hardship there is also ease.")
            ]
        }
    }

    private func load(lat: Double, lon: Double) async {
        let url = URL(string: "https://api.aladhan.com/v1/timings?latitude=\(lat)&longitude=\(lon)&method=4")!
        do {
            var req = URLRequest(url: url)
            req.setValue("BeUmmatiWatch/1.0", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: req)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let dataObj = json?["data"] as? [String: Any],
                  let timings = dataObj["timings"] as? [String: String],
                  let date = dataObj["date"] as? [String: Any],
                  let hijri = date["hijri"] as? [String: Any],
                  let month = hijri["month"] as? [String: Any]
            else {
                status = "Parse error"
                return
            }
            let dayNum = hijri["day"] as? String ?? ""
            let monthEn = month["en"] as? String ?? ""
            let year = hijri["year"] as? String ?? ""
            let parsed = WatchPrayerDay(
                fajr: clean(timings["Fajr"]),
                dhuhr: clean(timings["Dhuhr"]),
                asr: clean(timings["Asr"]),
                maghrib: clean(timings["Maghrib"]),
                isha: clean(timings["Isha"]),
                hijri: "\(dayNum) \(monthEn) \(year)"
            )
            day = parsed
            let cached = CachedDay(fajr: parsed.fajr, dhuhr: parsed.dhuhr, asr: parsed.asr, maghrib: parsed.maghrib, isha: parsed.isha, hijri: parsed.hijri)
            if let encoded = try? JSONEncoder().encode(cached) {
                UserDefaults.standard.set(encoded, forKey: "beummati.watch.prayer")
            }
            status = "Updated"
        } catch {
            status = error.localizedDescription
        }
    }

    private func clean(_ s: String?) -> String {
        (s ?? "—").components(separatedBy: " ").first ?? "—"
    }

    static func parseToday(_ time: String) -> Date? {
        let parts = time.split(separator: ":")
        guard parts.count >= 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = h
        comps.minute = m
        comps.second = 0
        return Calendar.current.date(from: comps)
    }

    private struct CachedDay: Codable {
        let fajr, dhuhr, asr, maghrib, isha, hijri: String
    }
}
