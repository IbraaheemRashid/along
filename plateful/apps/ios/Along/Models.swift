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
    var startDate = Calendar.current.startOfDay(for: .now)
    // Optional additions allow journals written before expanded onboarding to
    // decode unchanged. A design preview is never a subscription entitlement.
    var onboardingPreferences: OnboardingDraft?
    var isDesignPreview: Bool?
    // Optional for compatibility with journals saved before Pip's story chats.
    // These are fictional pet preferences, separate from health/journal records.
    var companionDiscoveries: [String: String]?
    var pipProgress: PipProgress?
    var routineDays: [RoutineDay]?
    // Local restore boundary; never included in exported backup content.
    var restoreGeneration: UUID?

    @discardableResult mutating func remember(_ story: PipStory, choice: String) -> Bool {
        guard canRead(story), story.choices.contains(where: { $0.id == choice }) else { return false }
        var discoveries = companionDiscoveries ?? [:]
        discoveries[story.id] = choice
        companionDiscoveries = discoveries
        return true
    }

    mutating func save(_ entry: CheckIn, calendar: Calendar = .current) {
        routineDays?.removeAll { calendar.isDate($0.day, inSameDayAs: entry.day) }
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

struct PipStory: Identifiable {
    struct Choice: Identifiable {
        let id: String
        let title: String
        let reply: String
        let discovery: String
    }
    let id: String
    let title: String
    let symbol: String
    let prompt: String
    let choices: [Choice]
    var requiredDays: Int {
        switch id { case "window": 0; case "book": 3; case "garden": 7; case "plant": 14; case "light": 30; default: 60 }
    }

    static let all: [PipStory] = [
        PipStory(id: "window", title: "A sound at the window", symbol: "cloud.rain", prompt: "I heard little taps on the window. The rain was making its own music! What should we listen for?", choices: [
            Choice(id: "rain", title: "The rhythm of the rain", reply: "Tap, tap, pause. I like that every little drop gets its own turn.", discovery: "Rainy-day rhythms"),
            Choice(id: "birds", title: "The birds between the showers", reply: "There they are! A tiny song between the raindrops. I’m glad we listened.", discovery: "Birdsong by the window")
        ]),
        PipStory(id: "book", title: "A page to turn", symbol: "book.closed", prompt: "I found an empty notebook on the shelf. There’s room for all sorts of things in here. Where should I begin?", choices: [
            Choice(id: "drawing", title: "Draw something you noticed", reply: "I drew our little window. It’s a bit wonky, but it feels like home.", discovery: "Wonky little drawings"),
            Choice(id: "word", title: "Start with one word", reply: "I chose ‘curious’. One little word can be a lovely beginning.", discovery: "Collecting little words")
        ]),
        PipStory(id: "garden", title: "A leaf on the doorstep", symbol: "leaf", prompt: "A little leaf landed by the door. It has so many tiny lines! What do you think it looks like?", choices: [
            Choice(id: "map", title: "A map of tiny paths", reply: "A tiny map! I wonder where all those little paths would take us.", discovery: "Maps in fallen leaves"),
            Choice(id: "heart", title: "A little heart", reply: "I can see it now. A little hello from the world outside.", discovery: "Hearts in everyday things")
        ]),
        PipStory(id: "plant", title: "A new neighbour", symbol: "leaf", prompt: "There’s a tiny plant by the window now. I’ve been looking at the way its leaves turn towards the light. What should we name it?", choices: [
            Choice(id: "fern", title: "Fern, a very leafy name", reply: "Fern it is. I think we’ll be good neighbours, even on the quiet days.", discovery: "A leafy neighbour called Fern"),
            Choice(id: "sunny", title: "Sunny, for its favourite spot", reply: "Sunny has the window seat. I have the rug. There’s a place for both of us.", discovery: "A window friend called Sunny")
        ]),
        PipStory(id: "light", title: "An evening glow", symbol: "lamp.table", prompt: "Our little lamp makes soft shapes on the wall. I’ve been watching them change. What can you see?", choices: [
            Choice(id: "mountain", title: "A tiny mountain range", reply: "Mountains made of light. An adventure we can have right here at home.", discovery: "Mountains in the lamplight"),
            Choice(id: "cloud", title: "A sleepy cloud", reply: "It does look sleepy. I’ll leave a little space for it to float.", discovery: "Clouds in a cosy corner")
        ]),
        PipStory(id: "stars", title: "Our own constellation", symbol: "sparkles", prompt: "There are stars above the window! I’ve been joining the dots in my head. What picture should we make?", choices: [
            Choice(id: "path", title: "A wandering path", reply: "Some turns, some pauses, and lots of little places to stop. I like our path.", discovery: "A path between the stars"),
            Choice(id: "home", title: "A little house", reply: "A house with a bright window. Just like this one. I’m glad we’re here.", discovery: "A home among the stars")
        ])
    ]
}
