import Foundation

enum Mood: String, Codable, CaseIterable, Identifiable {
    case bright, steady, tough
    var id: String { rawValue }
    var title: String { switch self { case .bright: "Pretty good"; case .steady: "Somewhere in between"; case .tough: "A tougher day" } }
    var shortTitle: String { switch self { case .bright: "Bright"; case .steady: "Steady"; case .tough: "Tough" } }
    var symbol: String { switch self { case .bright: "sun.max"; case .steady: "cloud.sun"; case .tough: "cloud" } }
}
enum Appetite: String, Codable, CaseIterable, Identifiable {
    case low, comfortable, hungry
    var id: String { rawValue }
    var title: String { switch self { case .low: "Not much"; case .comfortable: "Comfortable"; case .hungry: "More today" } }
}
enum Routine: String, Codable, CaseIterable, Identifiable {
    case nutrition, movement, reflection
    var id: String { rawValue }
    var title: String { switch self { case .nutrition: "Made time for food"; case .movement: "Moved in my own way"; case .reflection: "Took a moment for myself" } }
    var shortTitle: String { switch self { case .nutrition: "Nourish"; case .movement: "Move"; case .reflection: "Reflect" } }
    var symbol: String { switch self { case .nutrition: "leaf"; case .movement: "figure.walk"; case .reflection: "sparkles" } }
    var description: String { switch self { case .nutrition: "Food and hydration, without perfection."; case .movement: "The activity that works for you."; case .reflection: "A little room to notice how you feel." } }
}
enum MilestoneKind: String, Codable, CaseIterable, Identifiable {
    case everyday, strength, confidence, other
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String { switch self { case .everyday: "sun.max"; case .strength: "figure.strengthtraining.traditional"; case .confidence: "sparkles"; case .other: "flag" } }
}
struct CheckIn: Codable, Identifiable, Equatable {
    var id = UUID()
    var day: Date
    var mood: Mood
    var appetite: Appetite
    var routines: Set<Routine>
    var note: String
    var isSample = false
}
struct Milestone: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var title: String
    var note: String
    var kind: MilestoneKind
    var isSample = false
}
struct WeightEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var kilograms: Double
    var isSample = false
}
enum WeightUnit: String, Codable, CaseIterable {
    case kg, lb
    func display(_ kg: Double) -> Double { self == .kg ? kg : kg * 2.20462262185 }
    func kilograms(_ value: Double) -> Double { self == .kg ? value : value / 2.20462262185 }
}
enum Accessory: String, Codable, CaseIterable, Identifiable {
    case leaf, scarf, flower
    var id: String { rawValue }
    var title: String { switch self { case .leaf: "Little leaf"; case .scarf: "Cosy scarf"; case .flower: "Sunny bloom" } }
    var requiredDays: Int { switch self { case .leaf: 0; case .scarf: 3; case .flower: 7 } }
}
struct Journal: Codable, Equatable {
    var version = 1
    var hasOnboarded = false
    var name = ""
    var companionName = "Pip"
    var routines: Set<Routine> = [.nutrition, .movement, .reflection]
    var checkIns: [CheckIn] = []
    var milestones: [Milestone] = []
    var weights: [WeightEntry] = []
    var weightUnit: WeightUnit = .kg
    var showWeight = false
    var accessory: Accessory = .leaf
    var unlockedAccessories: Set<Accessory> = [.leaf]
    var hasSampleData = false
    var startDate = Date()

    mutating func save(_ entry: CheckIn, calendar: Calendar = .current) {
        if let index = checkIns.firstIndex(where: { calendar.isDate($0.day, inSameDayAs: entry.day) }) {
            var replacement = entry
            replacement.id = checkIns[index].id
            replacement.isSample = checkIns[index].isSample
            checkIns[index] = replacement
        } else { checkIns.append(entry) }
    }
    mutating func save(_ entry: WeightEntry, calendar: Calendar = .current) {
        if let index = weights.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: entry.date) }) {
            var replacement = entry
            replacement.id = weights[index].id
            replacement.isSample = weights[index].isSample
            weights[index] = replacement
        } else { weights.append(entry) }
    }
    func week(ending date: Date = .now, calendar: Calendar = .current) -> [CheckIn] {
        let today = calendar.startOfDay(for: date)
        let start = calendar.date(byAdding: .day, value: -6, to: today)!
        let end = calendar.date(byAdding: .day, value: 1, to: today)!
        return checkIns.filter { $0.day >= start && $0.day < end }
    }
    func canUse(_ accessory: Accessory) -> Bool { unlockedAccessories.contains(accessory) }
    static func sample(now: Date = .now, calendar: Calendar = .current) -> Journal {
        var journal = Journal()
        journal.hasSampleData = true
        journal.unlockedAccessories = Set(Accessory.allCases)
        journal.startDate = calendar.date(byAdding: .day, value: -13, to: now)!
        let samples: [(Int, Mood, Appetite, Set<Routine>, String)] = [
            (-13, .steady, .comfortable, [.reflection], "Starting this with a little curiosity."),
            (-11, .bright, .comfortable, [.nutrition, .movement], "A walk in the park with a friend. Glad I went."),
            (-9, .tough, .low, [.reflection], "A quiet day. Wrote down a few questions for my appointment."),
            (-7, .steady, .comfortable, [.nutrition], "Found a breakfast I actually look forward to."),
            (-6, .bright, .comfortable, [.movement, .reflection], "Had a good catch-up on our walk."),
            (-4, .steady, .low, [.nutrition], "Kept things simple today."),
            (-3, .bright, .comfortable, [.movement, .nutrition], "Tried a short strength session at my own pace."),
            (-1, .steady, .hungry, [.nutrition, .reflection], "Feeling more settled into my own routine.")
        ]
        journal.checkIns = samples.map { offset, mood, appetite, routines, note in
            CheckIn(day: calendar.date(byAdding: .day, value: offset, to: now)!, mood: mood, appetite: appetite, routines: routines, note: note, isSample: true)
        }
        journal.milestones = [
            Milestone(date: calendar.date(byAdding: .day, value: -10, to: now)!, title: "Made time for a walk", note: "No pace to beat. Just fresh air and good company.", kind: .everyday, isSample: true),
            Milestone(date: calendar.date(byAdding: .day, value: -5, to: now)!, title: "Found my kind of breakfast", note: "Something familiar that fits my mornings.", kind: .everyday, isSample: true),
            Milestone(date: calendar.date(byAdding: .day, value: -3, to: now)!, title: "My first strength session", note: "I started where I was. That felt good.", kind: .strength, isSample: true)
        ]
        journal.weights = [(-13, 94.2), (-8, 94.0), (-4, 94.3), (-1, 93.8)].map { offset, weight in
            WeightEntry(date: calendar.date(byAdding: .day, value: offset, to: now)!, kilograms: weight, isSample: true)
        }
        return journal
    }
}
enum JournalValidation {
    static func checkIn(note: String, day: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        note.count <= 500 && calendar.startOfDay(for: day) <= calendar.startOfDay(for: now)
    }
    static func weight(_ value: Double) -> Bool { value.isFinite && value > 0 && value <= 500 }
    static func milestone(title: String, note: String) -> Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.count <= 80 && note.count <= 300
    }
}
