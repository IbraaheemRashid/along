import Foundation

struct RoutineDay: Codable, Equatable, Identifiable {
    var id = UUID()
    var day: Date
    var routines: Set<Routine>
    var isSample = false
}

/// Permanent, cumulative progress. The first timezone is retained so travelling
/// or editing a record cannot turn the same entry into another earned day.
struct PipProgress: Codable, Equatable {
    var timeZoneID = TimeZone.current.identifier
    var recordedDays: Set<String> = []
    var creditedEntries: Set<UUID> = []
    var claimedRewards: Set<PipReward> = []

    mutating func credit(id: UUID, day: Date, now: Date) {
        guard !creditedEntries.contains(id) else { return }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? TimeZone(secondsFromGMT: 0)!
        guard day.timeIntervalSinceReferenceDate.isFinite,
              calendar.startOfDay(for: day) <= calendar.startOfDay(for: now) else { return }
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        recordedDays.insert(String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!))
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
            pipProgress?.credit(id: entry.id, day: entry.day, now: now)
        }
        for entry in routineDays ?? [] where !entry.isSample && !entry.routines.isEmpty {
            pipProgress?.credit(id: entry.id, day: entry.day, now: now)
        }
        for accessory in Accessory.allCases where recordedDayCount >= accessory.requiredDays {
            unlockedAccessories.insert(accessory)
        }
    }

    func canRead(_ story: PipStory) -> Bool {
        recordedDayCount >= story.requiredDays || companionDiscoveries?[story.id] != nil
    }

    func recordedRoutines(on day: Date, calendar: Calendar = .current) -> Set<Routine> {
        if let entry = (routineDays ?? []).first(where: { calendar.isDate($0.day, inSameDayAs: day) }) { return entry.routines }
        return checkIns.first(where: { calendar.isDate($0.day, inSameDayAs: day) })?.routines ?? []
    }

    mutating func toggleRoutine(_ routine: Routine, on day: Date, calendar: Calendar = .current) {
        if let index = checkIns.firstIndex(where: { calendar.isDate($0.day, inSameDayAs: day) }) {
            if checkIns[index].routines.contains(routine) { checkIns[index].routines.remove(routine) }
            else { checkIns[index].routines.insert(routine) }
        } else {
            var entries = routineDays ?? []
            if let index = entries.firstIndex(where: { calendar.isDate($0.day, inSameDayAs: day) }) {
                if entries[index].routines.contains(routine) { entries[index].routines.remove(routine) }
                else { entries[index].routines.insert(routine) }
            } else { entries.append(RoutineDay(day: day, routines: [routine])) }
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
