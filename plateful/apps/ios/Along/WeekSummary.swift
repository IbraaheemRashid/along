import Foundation

/// Seven civil days, ending on the selected day. Missing entries stay unknown.
struct WeekSummary {
    let range: ClosedRange<String>
    let checkIns: [CheckIn]
    let routineDays: [RoutineDay]
    let milestones: [Milestone]
    let recordedDays: Int
    let routineCount: Int

    init(journal: Journal, ending date: Date, calendar: Calendar = .current) {
        range = DayIdentity.range(ending: date, timeZone: calendar.timeZone) ?? "1900-01-01"..."1900-01-01"
        let source = journal.legacyDayTimeZone(fallback: calendar.timeZone)
        func key(_ stored: String?, _ raw: Date) -> String? { DayIdentity.resolved(stored, rawDate: raw, sourceTimeZone: source) }
        let selectedRange = range
        checkIns = journal.checkIns.filter { key($0.dayKey, $0.day).map { selectedRange.contains($0) } ?? false }.sorted { ($0.dayKey ?? "") > ($1.dayKey ?? "") }
        routineDays = (journal.routineDays ?? []).filter { !$0.routines.isEmpty && (key($0.dayKey, $0.day).map { selectedRange.contains($0) } ?? false) }
        milestones = journal.milestones.filter { key($0.dateKey, $0.date).map { selectedRange.contains($0) } ?? false }.sorted { ($0.dateKey ?? "") > ($1.dateKey ?? "") }
        var routines: [String: Set<Routine>] = [:]
        var days = Set<String>()
        for entry in checkIns {
            if let day = key(entry.dayKey, entry.day) { days.insert(day); routines[day, default: []].formUnion(entry.routines) }
        }
        for entry in routineDays {
            if let day = key(entry.dayKey, entry.day) { days.insert(day); routines[day, default: []].formUnion(entry.routines) }
        }
        recordedDays = days.count
        routineCount = routines.values.reduce(0) { $0 + $1.count }
    }

    var dateLabel: String {
        let style = Date.FormatStyle(date: .abbreviated, time: .omitted)
        return DayIdentity.formatted(key: range.lowerBound, rawDate: .distantPast, style: style) + " – " + DayIdentity.formatted(key: range.upperBound, rawDate: .distantPast, style: style)
    }
    var reflection: String {
        guard recordedDays > 0 else { return "There are no recorded days in this week. That doesn’t tell us how the week felt. Your journal is here whenever you want to add a moment." }
        return "You kept a record on \(recordedDays) \(recordedDays == 1 ? "day" : "days"), including \(checkIns.count) \(checkIns.count == 1 ? "check-in" : "check-ins") and \(routineCount) \(routineCount == 1 ? "routine moment" : "routine moments") in these seven days. Days without entries simply aren’t recorded."
    }
}
