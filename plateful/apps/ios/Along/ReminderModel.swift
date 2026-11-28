import Foundation

/// Master switch for dose reminders. Legacy daily/weekly fields still decode so
/// older preference files open, then map onto the single dose-reminder toggle.
struct ReminderPreferences: Codable, Equatable {
    var enabled = false
    /// Legacy journal fields. Kept for decode compatibility only.
    var dailyEnabled = false
    var dailyHour = 9
    var dailyMinute = 0
    var weeklyEnabled = false
    var weeklyDay = 1
    var weeklyHour = 19
    var weeklyMinute = 0

    var isEnabled: Bool { enabled }
    var isValid: Bool {
        (0...23).contains(dailyHour) && (0...59).contains(dailyMinute)
            && (0...23).contains(weeklyHour) && (0...59).contains(weeklyMinute)
            && (1...7).contains(weeklyDay)
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dailyEnabled = try c.decodeIfPresent(Bool.self, forKey: .dailyEnabled) ?? false
        dailyHour = try c.decodeIfPresent(Int.self, forKey: .dailyHour) ?? 9
        dailyMinute = try c.decodeIfPresent(Int.self, forKey: .dailyMinute) ?? 0
        weeklyEnabled = try c.decodeIfPresent(Bool.self, forKey: .weeklyEnabled) ?? false
        weeklyDay = try c.decodeIfPresent(Int.self, forKey: .weeklyDay) ?? 1
        weeklyHour = try c.decodeIfPresent(Int.self, forKey: .weeklyHour) ?? 19
        weeklyMinute = try c.decodeIfPresent(Int.self, forKey: .weeklyMinute) ?? 0
        if let enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) {
            self.enabled = enabled
        } else {
            // Old files used daily/weekly toggles. Either one becomes the dose switch.
            self.enabled = dailyEnabled || weeklyEnabled
        }
    }

    enum CodingKeys: String, CodingKey {
        case enabled, dailyEnabled, dailyHour, dailyMinute, weeklyEnabled, weeklyDay, weeklyHour, weeklyMinute
    }

    static func suggestion(onboardingChoice: String? = nil, reflectionDay: Int? = nil) -> ReminderPreferences {
        var value = ReminderPreferences()
        if onboardingChoice == "Evening" { value.dailyHour = 19 }
        if let reflectionDay, (1...7).contains(reflectionDay) { value.weeklyDay = reflectionDay }
        // Setup asked for permission separately; the toggle stays off until Save.
        return value
    }
}

/// One peptide's reminder plan, without importing the full protocol model into
/// the isolated reminder test binary.
struct DoseReminderSource: Equatable {
    struct Time: Equatable {
        var hour: Int
        var minute: Int
        var minutes: Int { hour * 60 + minute }
    }

    enum Cadence: Equatable {
        case daily
        case weekdays(Set<Int>)
        case interval(days: Int, startKey: String)
    }

    var id: String
    var name: String
    var amountText: String?
    var cadence: Cadence
    var times: [Time]
    var answeredMinutes: [String: Set<Int>] = [:]
    var startKey: String? = nil
}

/// One tracked batch expiry. Fires a few one-shot reminders before the day —
/// tracking only, never dosing advice.
struct BatchExpiryReminderSource: Equatable {
    var id: String
    var name: String
    var expiryKey: String
}

struct ReminderSchedule: Equatable, Identifiable {
    var id: String
    var title: String
    var body: String
    var dateComponents: DateComponents
    var repeats: Bool

    init(id: String, title: String, body: String, weekday: Int? = nil, year: Int? = nil, month: Int? = nil, day: Int? = nil,
         hour: Int, minute: Int, repeats: Bool) {
        self.id = id
        self.title = title
        self.body = body
        self.repeats = repeats
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.weekday = weekday
        components.hour = hour
        components.minute = minute
        self.dateComponents = components
    }
}

/// Only identifiers issued for an owned journal may open a dose.
struct ReminderDestination: Equatable {
    let profile: String
    let peptideID: UUID
    let minutes: Int
    let dayKey: String

    init?(identifier: String, deliveredAt: Date, calendar: Calendar = .current) {
        guard identifier.hasPrefix(ReminderPlanner.idPrefix) else { return nil }
        let parts = identifier.dropFirst(ReminderPlanner.idPrefix.count).split(separator: ".")
        guard parts.count == 3 else { return nil }
        let owner = parts[0].split(separator: "_")
        guard owner.count == 2, let id = UUID(uuidString: String(owner[1])),
              let minutes = Int(parts[2]), (0..<1440).contains(minutes) else { return nil }
        self.profile = String(owner[0])
        self.peptideID = id
        self.minutes = minutes
        let components: DateComponents
        if parts[1].first == "i" {
            let fields = parts[1].dropFirst().split(separator: "-")
            guard fields.count == 3, let y = Int(fields[0]), let m = Int(fields[1]), let d = Int(fields[2]),
                  (1900...9999).contains(y), (1...12).contains(m), (1...31).contains(d) else { return nil }
            components = DateComponents(year: y, month: m, day: d)
        } else {
            guard parts[1] == "daily" || (1...7).contains(where: { parts[1] == "w\($0)" }) else { return nil }
            components = calendar.dateComponents([.year, .month, .day], from: deliveredAt)
        }
        guard let year = components.year, let month = components.month, let day = components.day else { return nil }
        dayKey = String(format: "%04d-%02d-%02d", year, month, day)
    }
}

enum ReminderPlanner {
    static let idPrefix = "along.reminder.dose."
    static let batchPrefix = "along.reminder.batch."
    static let legacyIDs = ["along.reminder.daily", "along.reminder.weekly"] + (1...7).map { "along.reminder.daily.\($0)" }
    /// Leave headroom under iOS's 64 pending-notification limit.
    static let maximumSchedules = 60
    /// How many upcoming interval doses to pre-schedule as one-shots.
    static let intervalHorizon = 14
    /// Lead times (in days before expiry) for batch reminders, morning local time.
    static let batchLeadDays = [7, 1, 0]
    static let batchHour = 9
    static let batchMinute = 0

    static func copy(for source: DoseReminderSource) -> (title: String, body: String) {
        let title = source.amountText.map { "\(source.name) · \($0)" } ?? source.name
        return (title, "Time for your dose, whenever you’re ready.")
    }

    static func copy(for batch: BatchExpiryReminderSource, daysBefore: Int) -> (title: String, body: String) {
        let title = "\(batch.name) · batch"
        let body: String
        switch daysBefore {
        case 0: body = "This batch is marked as expiring today."
        case 1: body = "This batch is marked as expiring tomorrow."
        default: body = "This batch is marked as expiring in \(daysBefore) days."
        }
        return (title, body)
    }

    static func schedules(for preferences: ReminderPreferences, sources: [DoseReminderSource] = [],
                          batchExpiries: [BatchExpiryReminderSource] = [],
                          now: Date = .now, calendar: Calendar = .current) -> [ReminderSchedule] {
        guard preferences.isEnabled, preferences.isValid else { return [] }
        var result: [ReminderSchedule] = []
        for source in sources {
            let copy = Self.copy(for: source)
            let today = calendar.startOfDay(for: now)
            let start = source.startKey.flatMap { date(for: $0, calendar: calendar) }
            let futureAnswer = source.answeredMinutes.contains { key, minutes in
                guard let day = date(for: key, calendar: calendar) else { return false }
                return minutes.contains { value in
                    calendar.date(bySettingHour: value / 60, minute: value % 60, second: 0, of: day).map { $0 > now } ?? false
                }
            }
            if start.map({ $0 > today }) == true || futureAnswer {
                let anchor: Date
                if case .interval(_, let key) = source.cadence {
                    guard let intervalStart = date(for: key, calendar: calendar) else { continue }
                    anchor = intervalStart
                } else { anchor = start ?? today }
                result += datedSchedules(for: source, from: anchor, now: now, calendar: calendar)
                continue
            }
            switch source.cadence {
            case .daily:
                for time in source.times where (0...23).contains(time.hour) && (0...59).contains(time.minute) {
                    result.append(ReminderSchedule(id: "\(idPrefix)\(source.id).daily.\(time.minutes)",
                                                   title: copy.title, body: copy.body,
                                                   hour: time.hour, minute: time.minute, repeats: true))
                }
            case .weekdays(let days):
                for weekday in days.sorted() where (1...7).contains(weekday) {
                    for time in source.times where (0...23).contains(time.hour) && (0...59).contains(time.minute) {
                        result.append(ReminderSchedule(id: "\(idPrefix)\(source.id).w\(weekday).\(time.minutes)",
                                                       title: copy.title, body: copy.body,
                                                       weekday: weekday, hour: time.hour, minute: time.minute, repeats: true))
                    }
                }
            case .interval(let days, let startKey):
                guard (2...30).contains(days), let start = date(for: startKey, calendar: calendar) else { continue }
                result += datedSchedules(for: source, from: start, now: now, calendar: calendar)
            }
        }
        result += batchSchedules(batchExpiries, now: now, calendar: calendar, room: .max)
        if result.count > maximumSchedules {
            var ordered: [(schedule: ReminderSchedule, date: Date)] = result.map { schedule in
                let next = schedule.repeats
                    ? calendar.nextDate(after: now, matching: schedule.dateComponents, matchingPolicy: .nextTime)
                    : calendar.date(from: schedule.dateComponents)
                return (schedule, next ?? .distantFuture)
            }
            ordered.sort { lhs, rhs in
                if lhs.date == rhs.date { return lhs.schedule.id < rhs.schedule.id }
                return lhs.date < rhs.date
            }
            return ordered.prefix(maximumSchedules).map { $0.schedule }
        }
        return result
    }

    private static func batchSchedules(_ batches: [BatchExpiryReminderSource], now: Date, calendar: Calendar, room: Int) -> [ReminderSchedule] {
        guard room > 0 else { return [] }
        var result: [ReminderSchedule] = []
        for batch in batches {
            guard let expiry = date(for: batch.expiryKey, calendar: calendar) else { continue }
            for lead in batchLeadDays {
                guard let fireDay = calendar.date(byAdding: .day, value: -lead, to: expiry),
                      let moment = calendar.date(bySettingHour: batchHour, minute: batchMinute, second: 0, of: fireDay),
                      moment > now else { continue }
                let parts = calendar.dateComponents([.year, .month, .day], from: moment)
                let copy = Self.copy(for: batch, daysBefore: lead)
                result.append(ReminderSchedule(id: "\(batchPrefix)\(batch.id).d\(lead)",
                                               title: copy.title, body: copy.body,
                                               year: parts.year, month: parts.month, day: parts.day,
                                               hour: batchHour, minute: batchMinute, repeats: false))
                if result.count >= room { return result }
            }
        }
        return result
    }

    /// A repeating calendar trigger has no start boundary. Queue dated occurrences
    /// until the app next opens, when an active daily or weekly rule can repeat.
    private static func datedSchedules(for source: DoseReminderSource, from start: Date,
                                       now: Date, calendar: Calendar) -> [ReminderSchedule] {
        let times = source.times.filter { (0...23).contains($0.hour) && (0...59).contains($0.minute) }
            .sorted { $0.minutes < $1.minutes }
        guard !times.isEmpty else { return [] }
        let today = calendar.startOfDay(for: now)
        let firstDay = max(start, today)
        let offset = calendar.dateComponents([.day], from: start, to: firstDay).day ?? 0
        let copy = Self.copy(for: source)
        var result: [ReminderSchedule] = []
        // Even the longest supported interval yields the full horizon here.
        for delta in 0...(30 * intervalHorizon) {
            guard let day = calendar.date(byAdding: .day, value: delta, to: firstDay) else { break }
            switch source.cadence {
            case .daily: break
            case .weekdays(let days):
                guard days.contains(calendar.component(.weekday, from: day)) else { continue }
            case .interval(let days, _):
                guard (2...30).contains(days), (offset + delta).isMultiple(of: days) else { continue }
            }
            for time in times {
                guard let moment = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day),
                      moment > now, calendar.isDate(moment, inSameDayAs: day) else { continue }
                let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: moment)
                guard let year = parts.year, let month = parts.month, let date = parts.day,
                      let hour = parts.hour, let minute = parts.minute else { continue }
                let key = String(format: "%04d-%02d-%02d", year, month, date)
                guard source.answeredMinutes[key]?.contains(time.minutes) != true else { continue }
                result.append(ReminderSchedule(id: "\(idPrefix)\(source.id).i\(year)-\(month)-\(date).\(time.minutes)",
                                               title: copy.title, body: copy.body, year: year, month: month,
                                               day: date, hour: hour, minute: minute, repeats: false))
                if result.count == intervalHorizon { return result }
            }
        }
        return result
    }

    private static func date(for key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]; components.month = parts[1]; components.day = parts[2]
        return calendar.date(from: components)
    }
}

enum ReminderPermission: Equatable {
    case notDetermined, denied, authorized, quiet
    var canSchedule: Bool { self == .authorized || self == .quiet }
}

struct ReminderSystemState: Equatable {
    var permission: ReminderPermission
    var pendingIDs: Set<String>
}

/// The system adapter is injected so verification never requests permission or
/// schedules a notification on the developer's machine or a simulator.
@MainActor protocol ReminderClient {
    func state() async -> ReminderSystemState
    func requestPermission() async throws -> Bool
    func replace(with schedules: [ReminderSchedule]) async throws
    func removeAllAlongReminders() async
}
