import Foundation
import UserNotifications

@MainActor
final class PrayerNotifications: ObservableObject {
    static let shared = PrayerNotifications()

    @Published var enabled = false
    @Published var fajr = true
    @Published var dhuhr = true
    @Published var asr = true
    @Published var maghrib = true
    @Published var isha = true
    @Published var preMinutes = 10
    @Published var authStatus = "Not requested"

    /// One gentle daily ping tied to Today’s Reminder (not spammy).
    @Published var dailyReminder = false
    @Published var dailyHour = 9
    @Published var dailyMinute = 0

    private let key = "beummati.prayerNotify.v1"
    private let dailyID = "beummati.daily.reminder"

    init() {
        let d = UserDefaults.standard
        enabled = d.bool(forKey: key + ".on")
        fajr = d.object(forKey: key + ".fajr") as? Bool ?? true
        dhuhr = d.object(forKey: key + ".dhuhr") as? Bool ?? true
        asr = d.object(forKey: key + ".asr") as? Bool ?? true
        maghrib = d.object(forKey: key + ".maghrib") as? Bool ?? true
        isha = d.object(forKey: key + ".isha") as? Bool ?? true
        preMinutes = d.object(forKey: key + ".pre") as? Int ?? 10
        dailyReminder = d.bool(forKey: key + ".dailyOn")
        dailyHour = d.object(forKey: key + ".dailyHour") as? Int ?? 9
        dailyMinute = d.object(forKey: key + ".dailyMinute") as? Int ?? 0
        refreshAuth()
    }

    private func persist() {
        let d = UserDefaults.standard
        d.set(enabled, forKey: key + ".on")
        d.set(fajr, forKey: key + ".fajr")
        d.set(dhuhr, forKey: key + ".dhuhr")
        d.set(asr, forKey: key + ".asr")
        d.set(maghrib, forKey: key + ".maghrib")
        d.set(isha, forKey: key + ".isha")
        d.set(preMinutes, forKey: key + ".pre")
        d.set(dailyReminder, forKey: key + ".dailyOn")
        d.set(dailyHour, forKey: key + ".dailyHour")
        d.set(dailyMinute, forKey: key + ".dailyMinute")
    }

    func refreshAuth() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    self.authStatus = "Allowed"
                case .denied:
                    self.authStatus = "Denied — enable in Settings"
                default:
                    self.authStatus = "Not requested"
                }
            }
        }
    }

    func requestAndEnable() async {
        do {
            let ok = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            enabled = ok
            persist()
            refreshAuth()
        } catch {
            authStatus = error.localizedDescription
        }
    }

    func setEnabled(_ on: Bool) async {
        if on {
            await requestAndEnable()
        } else {
            enabled = false
            persist()
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            scheduleDailyReminderOnly()
        }
    }

    func setDailyReminder(_ on: Bool) async {
        if on {
            let ok = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            dailyReminder = ok == true
            refreshAuth()
        } else {
            dailyReminder = false
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [dailyID, "nur.daily.reminder"])
        }
        persist()
        scheduleDailyReminderOnly()
    }

    func saveToggles() {
        persist()
    }

    /// Schedule today’s salah (+ optional pre-adhan). Call whenever prayer day refreshes.
    func reschedule(day: PrayerDay?) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        if enabled, let day {
            let pairs: [(String, String, Bool)] = [
                ("Fajr", day.fajr, fajr),
                ("Dhuhr", day.dhuhr, dhuhr),
                ("Asr", day.asr, asr),
                ("Maghrib", day.maghrib, maghrib),
                ("Isha", day.isha, isha)
            ]
            let cal = Calendar.current
            let now = Date()
            for (name, time, on) in pairs where on {
                guard let fire = Self.parseToday(time: time, calendar: cal) else { continue }
                if fire > now {
                    schedule(id: "beummati.prayer.\(name.lowercased())", title: "\(name) time", body: "It’s time for \(name).", at: fire, repeats: false)
                }
                if preMinutes > 0 {
                    let pre = fire.addingTimeInterval(TimeInterval(-preMinutes * 60))
                    if pre > now {
                        schedule(
                            id: "beummati.prayer.pre.\(name.lowercased())",
                            title: "\(name) in \(preMinutes) min",
                            body: "Prepare for \(name).",
                            at: pre,
                            repeats: false
                        )
                    }
                }
            }
        }
        scheduleDailyReminderOnly()
    }

    private func scheduleDailyReminderOnly() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [dailyID, "nur.daily.reminder"])
        guard dailyReminder else { return }

        let d = UserDefaults.standard
        let title = d.string(forKey: "beummati.widget.title").flatMap { $0.isEmpty ? nil : $0 } ?? "Today’s reminder"
        let ref = d.string(forKey: "beummati.widget.ref") ?? ""
        let english = d.string(forKey: "beummati.widget.english") ?? ""
        let body: String
        if !english.isEmpty {
            let snip = english.count > 120 ? String(english.prefix(117)) + "…" : english
            body = ref.isEmpty ? snip : "\(ref) — \(snip)"
        } else if !ref.isEmpty {
            body = "Open Be Ummati for \(ref)"
        } else {
            body = "A short reminder is waiting in Be Ummati."
        }

        var comps = DateComponents()
        comps.hour = dailyHour
        comps.minute = dailyMinute
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let seriesID = d.string(forKey: "beummati.seriesNotify.seriesID"),
           let chapterID = d.string(forKey: "beummati.seriesNotify.chapterID"),
           !seriesID.isEmpty, !chapterID.isEmpty {
            content.userInfo = [
                "deepLink": "series",
                "seriesID": seriesID,
                "chapterID": chapterID
            ]
        }
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let req = UNNotificationRequest(identifier: dailyID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    private func schedule(id: String, title: String, body: String, at date: Date, repeats: Bool) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: repeats)
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    static func parseToday(time: String, calendar: Calendar = .current) -> Date? {
        let parts = time.split(separator: ":")
        guard parts.count >= 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        var comps = calendar.dateComponents([.year, .month, .day], from: Date())
        comps.hour = h
        comps.minute = m
        comps.second = 0
        return calendar.date(from: comps)
    }
}
