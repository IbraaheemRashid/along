import Foundation

/// A record belongs to a civil date, not to whichever timezone later displays
/// its timestamp. Keys are Gregorian and locale-independent; timestamps remain
/// unchanged for old files and precision-preserving archive round trips.
enum DayIdentity {
    private static let utc = TimeZone(secondsFromGMT: 0)!

    static func calendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    static func weekdays(in calendar: Calendar) -> [Int] {
        (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
    }

    static func monthGrid(containing date: Date, calendar: Calendar) -> [String] {
        guard let month = calendar.dateInterval(of: .month, for: date),
              let days = calendar.range(of: .day, in: .month, for: date),
              let leading = weekdays(in: calendar).firstIndex(of: calendar.component(.weekday, from: month.start))
        else { return [] }
        return (-leading..<days.count).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: month.start).flatMap { key(for: $0, timeZone: calendar.timeZone) }
        }
    }

    static func key(for date: Date, timeZone: TimeZone = .current) -> String? {
        guard date.timeIntervalSinceReferenceDate.isFinite,
              date >= Date(timeIntervalSince1970: -2_209_075_200),
              date < Date(timeIntervalSince1970: 253_402_387_200) else { return nil }
        let parts = calendar(in: timeZone).dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day, (1900...9999).contains(year) else { return nil }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func isValid(_ key: String) -> Bool { components(key) != nil }

    /// Local noon avoids DST changes at midnight. A fallback UTC noon covers a
    /// civil date skipped entirely by a historical timezone transition.
    static func date(for key: String, timeZone: TimeZone = .current) -> Date? {
        guard var parts = components(key) else { return nil }
        parts.hour = 12
        let calendar = calendar(in: timeZone)
        if let value = calendar.date(from: parts), self.key(for: value, timeZone: timeZone) == key { return value }
        return self.calendar(in: utc).date(from: parts)
    }

    static func resolved(_ stored: String?, rawDate: Date, sourceTimeZone: TimeZone) -> String? {
        if let stored { return isValid(stored) ? stored : nil }
        return key(for: rawDate, timeZone: sourceTimeZone)
    }

    static func displayDate(key: String?, rawDate: Date, timeZone: TimeZone = .current) -> Date {
        key.flatMap { date(for: $0, timeZone: timeZone) } ?? rawDate
    }

    /// Text should format the civil key in UTC, including rare dates that never
    /// occurred in the viewer's timezone (for example Samoa's skipped day).
    static func formatted(key: String?, rawDate: Date, style: Date.FormatStyle = .init(date: .abbreviated, time: .omitted)) -> String {
        guard let key, let date = date(for: key, timeZone: utc) else { return rawDate.formatted(style) }
        var style = style; style.timeZone = utc
        return date.formatted(style)
    }

    static func matches(_ stored: String?, rawDate: Date, day: Date, calendar: Calendar = .current) -> Bool {
        guard let target = key(for: day, timeZone: calendar.timeZone) else { return false }
        return resolved(stored, rawDate: rawDate, sourceTimeZone: calendar.timeZone) == target
    }

    /// A stored date may be tomorrow relative to the viewer after east-to-west
    /// travel. Validate against the latest civil date currently possible rather
    /// than reinterpreting it in the viewer's timezone.
    static func isNotFuture(_ key: String, now: Date) -> Bool {
        guard isValid(key), let latest = self.key(for: now, timeZone: TimeZone(secondsFromGMT: 14 * 3600)!) else { return false }
        return key <= latest
    }

    /// Accept a key only if some real-world UTC offset could associate it with
    /// the retained timestamp. This prevents arbitrary unrelated date labels.
    static func isPlausible(_ key: String, for rawDate: Date) -> Bool {
        guard rawDate.timeIntervalSinceReferenceDate.isFinite, let noon = date(for: key, timeZone: utc) else { return false }
        let start = noon.addingTimeInterval(-12 * 3600)
        return rawDate >= start.addingTimeInterval(-14 * 3600)
            && rawDate < start.addingTimeInterval(24 * 3600 + 12 * 3600)
    }

    static func range(ending date: Date, days: Int = 7, timeZone: TimeZone = .current) -> ClosedRange<String>? {
        guard (1...3660).contains(days), let end = key(for: date, timeZone: timeZone),
              let endDate = self.date(for: end, timeZone: utc),
              let startDate = calendar(in: utc).date(byAdding: .day, value: 1 - days, to: endDate),
              let start = key(for: startDate, timeZone: utc) else { return nil }
        return start...end
    }

    private static func components(_ key: String) -> DateComponents? {
        let bytes = Array(key.utf8)
        guard bytes.count == 10, bytes[4] == 45, bytes[7] == 45,
              bytes.enumerated().allSatisfy({ $0.offset == 4 || $0.offset == 7 || (48...57).contains($0.element) }),
              let year = Int(key.prefix(4)), let month = Int(key.dropFirst(5).prefix(2)), let day = Int(key.suffix(2)),
              (1900...9999).contains(year), (1...12).contains(month), (1...31).contains(day) else { return nil }
        let parts = DateComponents(year: year, month: month, day: day)
        let calendar = calendar(in: utc)
        guard let value = calendar.date(from: parts), calendar.dateComponents([.year, .month, .day], from: value) == parts else { return nil }
        return parts
    }
}

extension CheckIn {
    var displayDay: Date { DayIdentity.displayDate(key: dayKey, rawDate: day) }
    func dayText(_ style: Date.FormatStyle = .init(date: .abbreviated, time: .omitted)) -> String {
        DayIdentity.formatted(key: dayKey, rawDate: day, style: style)
    }
    func isOn(_ date: Date, calendar: Calendar = .current) -> Bool {
        DayIdentity.matches(dayKey, rawDate: day, day: date, calendar: calendar)
    }
}
extension RoutineDay {
    var displayDay: Date { DayIdentity.displayDate(key: dayKey, rawDate: day) }
    func dayText(_ style: Date.FormatStyle = .init(date: .abbreviated, time: .omitted)) -> String {
        DayIdentity.formatted(key: dayKey, rawDate: day, style: style)
    }
    func isOn(_ date: Date, calendar: Calendar = .current) -> Bool {
        DayIdentity.matches(dayKey, rawDate: day, day: date, calendar: calendar)
    }
}
extension WeightEntry {
    var displayDate: Date { DayIdentity.displayDate(key: dateKey, rawDate: date) }
    func dateText(_ style: Date.FormatStyle = .init(date: .abbreviated, time: .omitted)) -> String {
        DayIdentity.formatted(key: dateKey, rawDate: date, style: style)
    }
    func isOn(_ day: Date, calendar: Calendar = .current) -> Bool {
        DayIdentity.matches(dateKey, rawDate: date, day: day, calendar: calendar)
    }
}
extension Milestone {
    var displayDate: Date { DayIdentity.displayDate(key: dateKey, rawDate: date) }
    func dateText(_ style: Date.FormatStyle = .init(date: .abbreviated, time: .omitted)) -> String {
        DayIdentity.formatted(key: dateKey, rawDate: date, style: style)
    }
    func isOn(_ day: Date, calendar: Calendar = .current) -> Bool {
        DayIdentity.matches(dateKey, rawDate: date, day: day, calendar: calendar)
    }
}

extension Journal {
    /// Explicit source wins for archives. Native legacy migration otherwise uses
    /// the retained ledger timezone, with current timezone as a last resort.
    func legacyDayTimeZone(fallback: TimeZone = .current) -> TimeZone {
        pipProgress.flatMap { TimeZone(identifier: $0.timeZoneID) } ?? fallback
    }

    mutating func normalizeDayKeys(sourceTimeZone: TimeZone? = nil) {
        let zone = sourceTimeZone ?? legacyDayTimeZone()
        for index in checkIns.indices where checkIns[index].dayKey == nil {
            checkIns[index].dayKey = DayIdentity.key(for: checkIns[index].day, timeZone: zone)
        }
        for index in weights.indices where weights[index].dateKey == nil {
            weights[index].dateKey = DayIdentity.key(for: weights[index].date, timeZone: zone)
        }
        for index in milestones.indices where milestones[index].dateKey == nil {
            milestones[index].dateKey = DayIdentity.key(for: milestones[index].date, timeZone: zone)
        }
        if routineDays != nil {
            for index in routineDays!.indices where routineDays![index].dayKey == nil {
                routineDays![index].dayKey = DayIdentity.key(for: routineDays![index].day, timeZone: zone)
            }
        }
    }

    func checkIn(on day: Date, calendar: Calendar = .current) -> CheckIn? {
        checkIns.first { $0.isOn(day, calendar: calendar) }
    }
    func weight(on day: Date, calendar: Calendar = .current) -> WeightEntry? {
        weights.first { $0.isOn(day, calendar: calendar) }
    }
}
