import Foundation
import Combine

enum SalahName: String, CaseIterable, Codable, Identifiable {
    case fajr, dhuhr, asr, maghrib, isha
    var id: String { rawValue }
    var title: String {
        switch self {
        case .fajr: return "Fajr"
        case .dhuhr: return "Dhuhr"
        case .asr: return "Asr"
        case .maghrib: return "Maghrib"
        case .isha: return "Isha"
        }
    }
}

enum SalahStatus: String, Codable, CaseIterable {
    case none
    case prayed
    case missed
    case qada

    var label: String {
        switch self {
        case .none: return "—"
        case .prayed: return "Prayed"
        case .missed: return "Missed"
        case .qada: return "Made up"
        }
    }

    var symbol: String {
        switch self {
        case .none: return "circle"
        case .prayed: return "checkmark.circle.fill"
        case .missed: return "xmark.circle"
        case .qada: return "arrow.uturn.backward.circle.fill"
        }
    }
}

struct SalahDayLog: Codable, Equatable {
    var fajr: SalahStatus = .none
    var dhuhr: SalahStatus = .none
    var asr: SalahStatus = .none
    var maghrib: SalahStatus = .none
    var isha: SalahStatus = .none

    subscript(_ name: SalahName) -> SalahStatus {
        get {
            switch name {
            case .fajr: return fajr
            case .dhuhr: return dhuhr
            case .asr: return asr
            case .maghrib: return maghrib
            case .isha: return isha
            }
        }
        set {
            switch name {
            case .fajr: fajr = newValue
            case .dhuhr: dhuhr = newValue
            case .asr: asr = newValue
            case .maghrib: maghrib = newValue
            case .isha: isha = newValue
            }
        }
    }

    var prayedCount: Int {
        SalahName.allCases.filter { self[$0] == .prayed || self[$0] == .qada }.count
    }
}

@MainActor
final class SalahTracker: ObservableObject {
    @Published private(set) var logs: [String: SalahDayLog] = [:]
    private let key = "beummati.salahTracker.v1"

    init() { load() }

    static func dayKey(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    func log(for date: Date = Date()) -> SalahDayLog {
        logs[Self.dayKey(date)] ?? SalahDayLog()
    }

    func set(_ name: SalahName, status: SalahStatus, on date: Date = Date()) {
        let k = Self.dayKey(date)
        var day = logs[k] ?? SalahDayLog()
        day[name] = status
        logs[k] = day
        save()
    }

    func cycle(_ name: SalahName, on date: Date = Date()) {
        let cur = log(for: date)[name]
        let next: SalahStatus
        switch cur {
        case .none: next = .prayed
        case .prayed: next = .qada
        case .qada: next = .missed
        case .missed: next = .none
        }
        set(name, status: next, on: date)
    }

    /// Gentle streak: consecutive days with ≥1 prayer logged as prayed/qada (not guilt for perfect 5/5).
    var gentleStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var day = Date()
        for _ in 0..<365 {
            let log = log(for: day)
            if log.prayedCount >= 1 {
                streak += 1
                day = cal.date(byAdding: .day, value: -1, to: day) ?? day
            } else if Self.dayKey(day) == Self.dayKey(Date()) {
                // Today empty doesn't break yet
                day = cal.date(byAdding: .day, value: -1, to: day) ?? day
            } else {
                break
            }
        }
        return streak
    }

    func weekDays(endingOn end: Date = Date()) -> [(date: Date, log: SalahDayLog)] {
        let cal = Calendar.current
        return (0..<7).reversed().compactMap { offset -> (Date, SalahDayLog)? in
            guard let d = cal.date(byAdding: .day, value: -offset, to: end) else { return nil }
            return (d, log(for: d))
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: SalahDayLog].self, from: data) else { return }
        logs = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
