import Foundation

struct RoutineDay: Codable, Equatable, Identifiable {
    var id = UUID()
    var day: Date
    var routines: Set<Routine>
    var isSample = false
    var dayKey: String?
}

/// Permanent, cumulative progress. Existing credited IDs/dates never change.
/// The original timezone is retained for legacy timestamp-only records.
struct PipProgress: Codable, Equatable {
    var timeZoneID = TimeZone.current.identifier
    var recordedDays: Set<String> = []
    var creditedEntries: Set<UUID> = []
    var claimedRewards: Set<PipReward> = []

    mutating func credit(id: UUID, day: Date, now: Date, dayKey: String? = nil) {
        guard !creditedEntries.contains(id) else { return }
        let zone = TimeZone(identifier: timeZoneID) ?? TimeZone(secondsFromGMT: 0)!
        guard let key = DayIdentity.resolved(dayKey, rawDate: day, sourceTimeZone: zone),
              DayIdentity.isPlausible(key, for: day) else { return }
        if dayKey != nil {
            guard JournalValidation.storedRecordDate(day, key: key, now: now) else { return }
        } else {
            guard let today = DayIdentity.key(for: now, timeZone: zone), key <= today else { return }
        }
        recordedDays.insert(key)
        creditedEntries.insert(id)
    }
}

enum PipReward: String, Codable, CaseIterable, Identifiable {
    case notebook, scarf, flower, plant, lantern, stars
    var id: String { rawValue }
    var requiredDays: Int {
        switch self { case .notebook: 1; case .scarf: 3; case .flower: 7; case .plant: 14; case .lantern: 30; case .stars: 60 }
    }
    var title: String {
        switch self { case .notebook: "A little notebook"; case .scarf: "Cosy scarf"; case .flower: "Sunny bloom"; case .plant: "Windowsill plant"; case .lantern: "A warm little light"; case .stars: "A sky of your own" }
    }
    var symbol: String {
        switch self { case .notebook: "book.closed.fill"; case .scarf: "wind"; case .flower: "camera.macro"; case .plant: "leaf.fill"; case .lantern: "lamp.table.fill"; case .stars: "sparkles" }
    }
    var detail: String {
        switch self {
        case .notebook: "A home for little discoveries. This notebook joins the shelf in Pip’s room."
        case .scarf: "Something soft for curious little adventures. A new look for your companion."
        case .flower: "A small bloom for ordinary days. A new look for your companion."
        case .plant: "A little green company by the window. It stays happy when you’re away."
        case .lantern: "A warm glow for the reading corner. Your recorded moments made a little more room."
        case .stars: "A constellation above the window, for all those separate days that became a story."
        }
    }
    var accessory: Accessory? {
        switch self { case .scarf: .scarf; case .flower: .flower; default: nil }
    }
}

extension Journal {
    var recordedDayCount: Int { pipProgress?.recordedDays.count ?? 0 }
    var availableRewards: [PipReward] {
        PipReward.allCases.filter { recordedDayCount >= $0.requiredDays && !(pipProgress?.claimedRewards.contains($0) ?? false) }
    }
    var nextReward: PipReward? {
        PipReward.allCases.first { recordedDayCount < $0.requiredDays && !(pipProgress?.claimedRewards.contains($0) ?? false) }
    }
    var roomRewards: Set<PipReward> { pipProgress?.claimedRewards ?? [] }

    mutating func reconcileProgress(now: Date = .now) {
        normalizeDayKeys()
        if pipProgress == nil {
            pipProgress = PipProgress()
            // A starter gift is a gift, never advertised later as something earned.
            // Old sample journals gave every cosmetic away for demonstration.
            if hasSampleData {
                unlockedAccessories = [.leaf, onboardingPreferences?.accessory ?? .leaf]
                if !unlockedAccessories.contains(accessory) { accessory = .leaf }
            }
            for reward in PipReward.allCases {
                if let accessory = reward.accessory, unlockedAccessories.contains(accessory) {
                    pipProgress?.claimedRewards.insert(reward)
                }
            }
        }
        for entry in checkIns where !entry.isSample {
            pipProgress?.credit(id: entry.id, day: entry.day, now: now, dayKey: entry.dayKey)
        }
        for entry in routineDays ?? [] where !entry.isSample && !entry.routines.isEmpty {
            pipProgress?.credit(id: entry.id, day: entry.day, now: now, dayKey: entry.dayKey)
        }
        for accessory in Accessory.allCases where recordedDayCount >= accessory.requiredDays {
            unlockedAccessories.insert(accessory)
        }
    }

    func canRead(_ story: PipStory) -> Bool {
        recordedDayCount >= story.requiredDays || companionDiscoveries?[story.id] != nil
    }

    func recordedRoutines(on day: Date, calendar: Calendar = .current) -> Set<Routine> {
        if let entry = (routineDays ?? []).first(where: { $0.isOn(day, calendar: calendar) }) { return entry.routines }
        return checkIn(on: day, calendar: calendar)?.routines ?? []
    }

    mutating func toggleRoutine(_ routine: Routine, on day: Date, calendar: Calendar = .current) {
        normalizeDayKeys(sourceTimeZone: legacyDayTimeZone(fallback: calendar.timeZone))
        guard let key = DayIdentity.key(for: day, timeZone: calendar.timeZone) else { return }
        if let index = checkIns.firstIndex(where: { $0.dayKey == key }) {
            if checkIns[index].routines.contains(routine) { checkIns[index].routines.remove(routine) }
            else { checkIns[index].routines.insert(routine) }
        } else {
            var entries = routineDays ?? []
            if let index = entries.firstIndex(where: { $0.dayKey == key }) {
                if entries[index].routines.contains(routine) { entries[index].routines.remove(routine) }
                else { entries[index].routines.insert(routine) }
            } else { entries.append(RoutineDay(day: day, routines: [routine], dayKey: key)) }
            routineDays = entries
        }
    }
}

#if DEBUG
extension PipProgress {
    /// Explicitly synthetic ledger for the isolated Dev Lab, never normal data.
    static func preview(days: Int, now: Date = .now) -> PipProgress {
        var value = PipProgress()
        for offset in 0..<max(0, min(days, 90)) {
            value.credit(id: UUID(), day: Calendar.current.date(byAdding: .day, value: -offset, to: now)!, now: now)
        }
        return value
    }
}
#endif
