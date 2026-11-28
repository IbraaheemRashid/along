import Foundation
import SwiftUI

enum DoseUnit: String, Codable, CaseIterable, Identifiable {
    case mcg, mg, iu, ml, units
    var id: String { rawValue }
    var title: String {
        switch self {
        case .mcg: "mcg"
        case .mg: "mg"
        case .iu: "IU"
        case .ml: "ml"
        case .units: "units"
        }
    }
}

enum InjectionSite: String, Codable, CaseIterable, Identifiable {
    case abdomenLeft, abdomenRight, thighLeft, thighRight, armLeft, armRight, gluteLeft, gluteRight
    var id: String { rawValue }
    var title: String {
        switch self {
        case .abdomenLeft: "Abdomen, left"
        case .abdomenRight: "Abdomen, right"
        case .thighLeft: "Thigh, left"
        case .thighRight: "Thigh, right"
        case .armLeft: "Arm, left"
        case .armRight: "Arm, right"
        case .gluteLeft: "Glute, left"
        case .gluteRight: "Glute, right"
        }
    }
    var shortTitle: String {
        switch self {
        case .abdomenLeft: "L abdomen"
        case .abdomenRight: "R abdomen"
        case .thighLeft: "L thigh"
        case .thighRight: "R thigh"
        case .armLeft: "L arm"
        case .armRight: "R arm"
        case .gluteLeft: "L glute"
        case .gluteRight: "R glute"
        }
    }

    /// Front-facing silhouette for abdomen/thigh/arm; back for glutes.
    var isBack: Bool {
        switch self {
        case .gluteLeft, .gluteRight: true
        default: false
        }
    }

    /// Unit coordinates on the body silhouette (0…1 within the figure frame).
    var bodyPoint: CGPoint {
        switch self {
        case .armLeft: CGPoint(x: 0.16, y: 0.34)
        case .armRight: CGPoint(x: 0.84, y: 0.34)
        case .abdomenLeft: CGPoint(x: 0.38, y: 0.46)
        case .abdomenRight: CGPoint(x: 0.62, y: 0.46)
        case .gluteLeft: CGPoint(x: 0.38, y: 0.54)
        case .gluteRight: CGPoint(x: 0.62, y: 0.54)
        case .thighLeft: CGPoint(x: 0.40, y: 0.72)
        case .thighRight: CGPoint(x: 0.60, y: 0.72)
        }
    }
}

/// How often each site appears in recent logs — tracking heat only.
struct SiteHeat: Equatable {
    var counts: [InjectionSite: Int] = [:]
    var lastUsed: [InjectionSite: Date] = [:]

    var total: Int { counts.values.reduce(0, +) }

    func count(for site: InjectionSite) -> Int { counts[site] ?? 0 }

    /// 0…1 relative intensity for visualisation. Unused sites stay cool.
    func intensity(for site: InjectionSite) -> Double {
        guard let max = counts.values.max(), max > 0 else { return 0 }
        return Double(counts[site] ?? 0) / Double(max)
    }
}

struct DoseTime: Codable, Hashable, Comparable, Identifiable {
    var hour: Int
    var minute: Int
    var id: Int { minutes }
    var minutes: Int { hour * 60 + minute }
    var isValid: Bool { (0...23).contains(hour) && (0...59).contains(minute) }
    static func < (lhs: DoseTime, rhs: DoseTime) -> Bool { lhs.minutes < rhs.minutes }

    func date(on dayKey: String, timeZone: TimeZone = .current) -> Date? {
        guard let noon = DayIdentity.date(for: dayKey, timeZone: timeZone) else { return nil }
        return DayIdentity.calendar(in: timeZone).date(bySettingHour: hour, minute: minute, second: 0, of: noon)
    }

    var text: String {
        let date = DayIdentity.calendar(in: .current).date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}

/// When a peptide is due. Amounts and schedules always come from the person;
/// Along never proposes them.
struct DoseSchedule: Codable, Equatable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case daily, weekdays, interval, unscheduled
        var id: String { rawValue }
        var title: String { switch self { case .daily: "Every day"; case .weekdays: "Specific days"; case .interval: "Every few days"; case .unscheduled: "Schedule not set" } }
    }

    static let maximumTimes = 4
    static let intervalRange = 2...30

    var kind: Kind = .daily
    /// Calendar weekdays, 1 = Sunday ... 7 = Saturday.
    var weekdays: Set<Int> = []
    var intervalDays = 2
    var times: [DoseTime] = [DoseTime(hour: 8, minute: 0)]

    static let unscheduled = DoseSchedule(kind: .unscheduled, times: [])
    static func daily(at time: DoseTime) -> DoseSchedule { DoseSchedule(kind: .daily, times: [time]) }
    static func on(_ weekdays: Set<Int>, at time: DoseTime) -> DoseSchedule { DoseSchedule(kind: .weekdays, weekdays: weekdays, times: [time]) }
    static func every(_ days: Int, at time: DoseTime) -> DoseSchedule { DoseSchedule(kind: .interval, intervalDays: days, times: [time]) }

    var isValid: Bool {
        if kind == .unscheduled { return times.isEmpty && weekdays.isEmpty }
        guard !times.isEmpty, times.count <= Self.maximumTimes, times.allSatisfy(\.isValid),
              Set(times).count == times.count else { return false }
        switch kind {
        case .daily, .unscheduled: return true
        case .weekdays: return !weekdays.isEmpty && weekdays.allSatisfy { (1...7).contains($0) }
        case .interval: return Self.intervalRange.contains(intervalDays)
        }
    }

    var sortedTimes: [DoseTime] { times.sorted() }

    /// "Every day", "Mon, Wed, Fri", "Every 3 days", "Weekly on Mon".
    var summary: String {
        switch kind {
        case .unscheduled: return kind.title
        case .daily: return "Every day"
        case .interval: return "Every \(intervalDays) days"
        case .weekdays:
            let symbols = DayIdentity.calendar(in: .current).shortWeekdaySymbols
            // Monday-first ordering reads naturally for a weekly plan.
            let ordered = weekdays.sorted { ($0 + 5) % 7 < ($1 + 5) % 7 }.map { symbols[$0 - 1] }
            if ordered.count == 7 { return "Every day" }
            if ordered.count == 1 { return "Weekly on \(ordered[0])" }
            return ordered.joined(separator: ", ")
        }
    }

    var timesSummary: String { sortedTimes.map(\.text).joined(separator: " · ") }
}

/// A colour the person picks for a peptide so they can recognise it at a glance.
/// Organisation only: no swatch means anything about the peptide or the dose.
enum PeptideColor: String, Codable, CaseIterable, Identifiable {
    case blue, green, pink, purple, orange, indigo, teal, red, yellow, graphite
    var id: String { rawValue }

    var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    /// sRGB components. The first six (and graphite) are the category tints the
    /// app used before colours were editable, so existing peptides look the same.
    var rgb: (red: Double, green: Double, blue: Double) {
        switch self {
        case .blue: (0.42, 0.62, 0.93)
        case .green: (0.36, 0.72, 0.56)
        case .pink: (0.93, 0.55, 0.62)
        case .purple: (0.66, 0.55, 0.85)
        case .orange: (0.93, 0.65, 0.36)
        case .indigo: (0.45, 0.52, 0.85)
        case .teal: (0.13, 0.64, 0.70)
        case .red: (0.87, 0.30, 0.29)
        case .yellow: (0.84, 0.70, 0.10)
        case .graphite: (0.6, 0.6, 0.65)
        }
    }

    var color: Color { Color(red: rgb.red, green: rgb.green, blue: rgb.blue) }

    /// The colour a peptide shows until the person picks one.
    static func `default`(for category: String) -> PeptideColor {
        switch category {
        case let value where value.hasPrefix("GLP-1"): .blue
        case "Recovery": .green
        case "Skin": .pink
        case "GH secretagogue": .purple
        case "Longevity", "Metabolic": .orange
        case "Cognitive", "Sleep": .indigo
        default: .graphite
        }
    }
}

struct PreviousSchedule: Codable, Equatable {
    var until: String
    var startKey: String
    var schedule: DoseSchedule
    var isPaused: Bool
}

struct TrackedPeptide: Codable, Identifiable, Equatable {
    static let nameLimit = 40
    static let noteLimit = 300
    static let maximumAmount = 100_000.0
    static let limit = 30

    var id = UUID()
    var name: String
    var amount: Double?
    var unit: DoseUnit = .mg
    var schedule = DoseSchedule()
    var startKey: String
    var isPaused = false
    var note = ""
    var isSample = false
    /// Optional vial / batch expiry as a civil day key. Tracking only.
    var batchExpiryKey: String?
    /// The person's chosen colour. Nil follows the category default, so data
    /// saved before colours existed keeps the colour it always showed.
    var color: PeptideColor?

    var previousSchedules: [PreviousSchedule]?
    /// Older journals follow the device reminder preference for every scheduled peptide.
    var doseRemindersEnabled: Bool?

    func scheduleOn(_ day: String) -> PreviousSchedule {
        previousSchedules?.first { day < $0.until }
            ?? PreviousSchedule(until: "9999-12-31", startKey: startKey, schedule: schedule, isPaused: isPaused)
    }

    private var validHistory: Bool {
        let history = previousSchedules ?? []
        return history.count <= 1024 && history.allSatisfy { DayIdentity.isValid($0.until) && DayIdentity.isValid($0.startKey) && $0.schedule.isValid }
            && zip(history, history.dropFirst()).allSatisfy { $0.until < $1.until }
    }

    var category: String { Peptide.category(for: name) }
    var displayColor: PeptideColor { color ?? .default(for: category) }
    var reference: PeptideReference { Peptide.reference(for: name) }

    var amountText: String? {
        guard let amount else { return nil }
        return "\(amount.formatted(.number.precision(.fractionLength(0...3)))) \(unit.title)"
    }

    /// Days until (positive) or since (negative) batch expiry. Nil when unset.
    func batchExpiryOffset(from dayKey: String) -> Int? {
        guard let batchExpiryKey, DayIdentity.isValid(batchExpiryKey),
              let days = ProtocolSchedule.days(from: dayKey, to: batchExpiryKey) else { return nil }
        return days
    }

    var batchExpirySummary: String? {
        guard let batchExpiryKey else { return nil }
        return "Batch · \(DayIdentity.formatted(key: batchExpiryKey, rawDate: .now, style: .dateTime.day().month(.abbreviated).year()))"
    }

    var isValid: Bool {
        JournalValidation.text(name, limit: Self.nameLimit, required: true)
            && JournalValidation.text(note, limit: Self.noteLimit)
            && DayIdentity.isValid(startKey) && schedule.isValid && validHistory
            && amount.map { $0.isFinite && $0 > 0 && $0 <= Self.maximumAmount } ?? true
            && (batchExpiryKey.map(DayIdentity.isValid) ?? true)
    }
}

struct DoseLog: Codable, Identifiable, Equatable {
    enum Status: String, Codable { case taken, skipped }
    static let noteLimit = 500
    static let limit = 20_000

    var id = UUID()
    var peptideID: UUID
    /// The civil day this dose counts towards.
    var dayKey: String
    /// The scheduled slot it fulfils. Nil for an extra, unscheduled dose.
    var scheduledTime: DoseTime?
    var status: Status = .taken
    var takenAt: Date
    var amount: Double?
    var unit: DoseUnit = .mg
    var site: InjectionSite?
    /// Exact spot from the 3D picker. `site` keeps the nearest legacy region.
    var spot: InjectionSpot?
    var note = ""
    var isSample = false

    var amountText: String? {
        guard let amount else { return nil }
        return "\(amount.formatted(.number.precision(.fractionLength(0...3)))) \(unit.title)"
    }

    func isValid(now: Date = .now) -> Bool {
        DayIdentity.isValid(dayKey) && DayIdentity.isNotFuture(dayKey, now: now)
            && takenAt.timeIntervalSinceReferenceDate.isFinite && takenAt <= now.addingTimeInterval(300)
            && (scheduledTime?.isValid ?? true)
            && amount.map { $0.isFinite && $0 > 0 && $0 <= TrackedPeptide.maximumAmount } ?? true
            && JournalValidation.text(note, limit: Self.noteLimit)
    }
}

/// One scheduled dose on one day, with the record that answered it, if any.
struct DoseSlot: Identifiable, Equatable {
    var peptide: TrackedPeptide
    var dayKey: String
    var time: DoseTime?
    var log: DoseLog?
    var id: String { "\(peptide.id.uuidString)|\(dayKey)|\(time.map { String($0.minutes) } ?? log?.id.uuidString ?? "extra")" }
    var isTaken: Bool { log?.status == .taken }
    var isSkipped: Bool { log?.status == .skipped }
    var isExtra: Bool { time == nil }
}

struct Adherence: Equatable {
    var due = 0
    var taken = 0
    var skipped = 0
    /// Past slots with no record. Unknown, not missed: the person may simply
    /// not have logged it.
    var unlogged: Int { max(0, due - taken - skipped) }
    var fraction: Double? { due == 0 ? nil : Double(taken) / Double(due) }
}

/// Pure schedule maths over civil day keys, independent of the device timezone
/// except where a key is turned into a moment.
enum ProtocolSchedule {
    private static let utc = DayIdentity.calendar(in: TimeZone(secondsFromGMT: 0)!)

    static func weekday(of dayKey: String) -> Int? {
        DayIdentity.date(for: dayKey, timeZone: utc.timeZone).map { utc.component(.weekday, from: $0) }
    }

    static func days(from start: String, to end: String) -> Int? {
        guard let a = DayIdentity.date(for: start, timeZone: utc.timeZone),
              let b = DayIdentity.date(for: end, timeZone: utc.timeZone) else { return nil }
        return utc.dateComponents([.day], from: a, to: b).day
    }

    static func key(_ dayKey: String, adding days: Int) -> String? {
        guard let date = DayIdentity.date(for: dayKey, timeZone: utc.timeZone),
              let shifted = utc.date(byAdding: .day, value: days, to: date) else { return nil }
        return DayIdentity.key(for: shifted, timeZone: utc.timeZone)
    }

    static func isDue(_ peptide: TrackedPeptide, on dayKey: String) -> Bool {
        let plan = peptide.scheduleOn(dayKey)
        guard !plan.isPaused, dayKey >= plan.startKey, plan.schedule.isValid else { return false }
        switch plan.schedule.kind {
        case .unscheduled: return false
        case .daily: return true
        case .weekdays: return weekday(of: dayKey).map(plan.schedule.weekdays.contains) ?? false
        case .interval:
            guard let offset = days(from: plan.startKey, to: dayKey) else { return false }
            return offset % plan.schedule.intervalDays == 0
        }
    }

    /// Scheduled slots for the day, matched to logs, followed by extra doses.
    static func slots(on dayKey: String, peptides: [TrackedPeptide], logs: [DoseLog]) -> [DoseSlot] {
        let dayLogs = logs.filter { $0.dayKey == dayKey }
        var result: [DoseSlot] = []
        for peptide in peptides where isDue(peptide, on: dayKey) {
            for time in peptide.scheduleOn(dayKey).schedule.sortedTimes {
                let log = dayLogs.first { $0.peptideID == peptide.id && $0.scheduledTime == time }
                result.append(DoseSlot(peptide: peptide, dayKey: dayKey, time: time, log: log))
            }
        }
        let scheduledIDs = Set(result.compactMap { $0.log?.id })
        for log in dayLogs where !scheduledIDs.contains(log.id) {
            guard let peptide = peptides.first(where: { $0.id == log.peptideID }) else { continue }
            result.append(DoseSlot(peptide: peptide, dayKey: dayKey, time: nil, log: log))
        }
        return result.sorted { lhs, rhs in
            let l = lhs.time?.minutes ?? minutes(of: lhs.log?.takenAt)
            let r = rhs.time?.minutes ?? minutes(of: rhs.log?.takenAt)
            return l == r ? lhs.peptide.name < rhs.peptide.name : l < r
        }
    }

    private static func minutes(of date: Date?) -> Int {
        guard let date else { return 0 }
        let parts = DayIdentity.calendar(in: .current).dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    /// Counts scheduled slots whose time has passed within the inclusive range.
    static func adherence(from start: String, to end: String, peptides: [TrackedPeptide], logs: [DoseLog],
                          now: Date, timeZone: TimeZone = .current) -> Adherence {
        var result = Adherence()
        guard let span = days(from: start, to: end), span >= 0, span <= 3660 else { return result }
        for offset in 0...span {
            guard let key = key(start, adding: offset) else { continue }
            for slot in slots(on: key, peptides: peptides, logs: logs) where !slot.isExtra {
                guard let moment = slot.time?.date(on: key, timeZone: timeZone), moment <= now else { continue }
                result.due += 1
                if slot.isTaken { result.taken += 1 } else if slot.isSkipped { result.skipped += 1 }
            }
        }
        return result
    }

    /// The first unanswered slot at or after now, within the next 60 days.
    static func nextDose(after now: Date, peptides: [TrackedPeptide], logs: [DoseLog],
                         timeZone: TimeZone = .current) -> (slot: DoseSlot, at: Date)? {
        guard let today = DayIdentity.key(for: now, timeZone: timeZone) else { return nil }
        for offset in 0..<60 {
            guard let key = key(today, adding: offset) else { continue }
            for slot in slots(on: key, peptides: peptides, logs: logs) where !slot.isExtra && slot.log == nil {
                if let moment = slot.time?.date(on: key, timeZone: timeZone), moment >= now { return (slot, moment) }
            }
        }
        return nil
    }

    /// The most recent site used for this peptide, to support rotation tracking.
    static func lastSite(for peptideID: UUID, logs: [DoseLog]) -> InjectionSite? {
        logs.filter { $0.peptideID == peptideID && $0.status == .taken && $0.site != nil }
            .max { $0.takenAt < $1.takenAt }?.site
    }

    /// Relative site use for heat maps. Optional peptide filter; taken logs with a site only.
    static func siteHeat(logs: [DoseLog], peptideID: UUID? = nil, limit: Int = 40) -> SiteHeat {
        let filtered = logs
            .filter { $0.status == .taken && $0.site != nil && (peptideID == nil || $0.peptideID == peptideID) }
            .sorted { $0.takenAt > $1.takenAt }
            .prefix(limit)
        var heat = SiteHeat()
        for log in filtered {
            guard let site = log.site else { continue }
            heat.counts[site, default: 0] += 1
            if heat.lastUsed[site] == nil { heat.lastUsed[site] = log.takenAt }
        }
        return heat
    }

    /// Cycles sample data through sites. Not shown as a medical recommendation in UI.
    static func suggestedSite(after last: InjectionSite?) -> InjectionSite {
        guard let last, let index = InjectionSite.allCases.firstIndex(of: last) else { return .abdomenLeft }
        return InjectionSite.allCases[(index + 1) % InjectionSite.allCases.count]
    }
}

/// Keeps the reported day stable when setup resumes in another time zone.
struct SetupInjection: Codable, Equatable {
    var id = UUID()
    var takenAt: Date
    var dayKey: String
    var site: InjectionSite?

    func log(for peptide: TrackedPeptide) -> DoseLog {
        // A single, scheduled occurrence on this day can be answered even when
        // the person logged a different actual time. Never guess between slots.
        let times = peptide.schedule.sortedTimes
        let slot = times.count == 1 && ProtocolSchedule.isDue(peptide, on: dayKey) ? times.first : nil
        return DoseLog(id: id, peptideID: peptide.id, dayKey: dayKey, scheduledTime: slot,
                       takenAt: takenAt, site: site)
    }
}

extension SetupDraft {
    /// The person's own setup answers as a starting protocol. Amounts stay
    /// empty: only the person can enter a dose.
    func initialPeptides(startKey: String) -> [TrackedPeptide] {
        compounds.prefix(TrackedPeptide.limit).map { name in
            TrackedPeptide(name: name, schedule: schedule(for: name), startKey: startKey)
        }
    }
}

extension Journal {
    var protocolPeptides: [TrackedPeptide] { peptides ?? [] }
    var activePeptides: [TrackedPeptide] { protocolPeptides.filter { !$0.isPaused } }
    var protocolLogs: [DoseLog] { doseLogs ?? [] }

    /// Keep an existing record for a slot, including richer records restored
    /// from backup. Returning false aborts the entire setup transaction.
    mutating func adoptSetupInjections(_ entries: [String: SetupInjection], now: Date) -> Bool {
        var logs = protocolLogs
        for (name, entry) in entries {
            guard let peptide = protocolPeptides.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }),
                  entry.takenAt <= now else { return false }
            let log = entry.log(for: peptide)
            let recorded = logs.contains { other in
                other.id == log.id || (other.peptideID == log.peptideID && other.dayKey == log.dayKey
                    && (other.takenAt == log.takenAt || (log.scheduledTime != nil && other.scheduledTime == log.scheduledTime)))
            }
            if !recorded { logs.append(log) }
        }
        guard logs.count <= DoseLog.limit else { return false }
        doseLogs = logs
        return true
    }

    /// Adds setup peptides not already tracked, matching names case-insensitively,
    /// so finishing setup twice never duplicates a protocol.
    mutating func adoptSetupPeptides(_ incoming: [TrackedPeptide]) {
        var list = protocolPeptides
        for peptide in incoming where list.count < TrackedPeptide.limit
            && !list.contains(where: { $0.name.caseInsensitiveCompare(peptide.name) == .orderedSame }) {
            list.append(peptide)
        }
        peptides = list
    }
}

extension Journal {
    /// Fictional records for design review. Every item is flagged as a sample
    /// and the journal is marked as containing sample data.
    mutating func addSampleProtocol(now: Date = .now, calendar: Calendar = .current) {
        guard let today = DayIdentity.key(for: now, timeZone: calendar.timeZone),
              let weeklyStart = ProtocolSchedule.key(today, adding: -23) else { return }
        let morning = DoseTime(hour: 8, minute: 0), evening = DoseTime(hour: 20, minute: 0)
        let samples = [
            TrackedPeptide(name: "Tirzepatide", amount: 2.5, unit: .mg, schedule: .on([ProtocolSchedule.weekday(of: weeklyStart) ?? 2], at: morning), startKey: weeklyStart, isSample: true),
            TrackedPeptide(name: "BPC-157", amount: 250, unit: .mcg, schedule: DoseSchedule(kind: .daily, times: [morning, evening]), startKey: ProtocolSchedule.key(today, adding: -13) ?? today, isSample: true),
            TrackedPeptide(name: "GHK-Cu", amount: 1, unit: .mg, schedule: .on([2, 4, 6], at: DoseTime(hour: 21, minute: 0)), startKey: ProtocolSchedule.key(today, adding: -20) ?? today, isSample: true),
        ]
        let notes = ["Slept well.", "A little tired today.", "Felt good after training."]
        var logs: [DoseLog] = [], counter = 0
        var site = InjectionSite.abdomenLeft
        for offset in -20...0 {
            guard let key = ProtocolSchedule.key(today, adding: offset) else { continue }
            for slot in ProtocolSchedule.slots(on: key, peptides: samples, logs: []) {
                guard let time = slot.time, let moment = time.date(on: key, timeZone: calendar.timeZone), moment < now else { continue }
                counter += 1
                if counter % 7 == 0 { continue }
                let skipped = counter % 13 == 0
                logs.append(DoseLog(peptideID: slot.peptide.id, dayKey: key, scheduledTime: time, status: skipped ? .skipped : .taken,
                                    takenAt: moment.addingTimeInterval(Double(counter % 4) * 420), amount: slot.peptide.amount, unit: slot.peptide.unit,
                                    site: skipped ? nil : site, note: counter % 9 == 0 ? notes[counter % notes.count] : "", isSample: true))
                if !skipped { site = ProtocolSchedule.suggestedSite(after: site) }
            }
        }
        peptides = samples
        doseLogs = logs
        hasSampleData = true
    }
}
