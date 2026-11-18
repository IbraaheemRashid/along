import Foundation

enum SetupStep: String, Codable, CaseIterable, Identifiable {
    case welcome, experience, goals, source, showcase, birthday, weight, target, commitment
    case compounds, frequency, doseTime, obstacles, trust, reminders, referral, ready, building, plan, paywall
    var id: String { rawValue }

    /// Steps that count towards the progress bar. The welcome, loader, reveal and
    /// paywall sit outside the questionnaire.
    var showsProgress: Bool { ![.welcome, .building, .plan, .paywall].contains(self) }
    var showsBack: Bool { ![.welcome, .building, .plan].contains(self) }
}

enum PeptideExperience: String, Codable, CaseIterable, Identifiable {
    case planning, starting, experienced
    var id: String { rawValue }
    var title: String { switch self { case .planning: "About to start"; case .starting: "Just started"; case .experienced: "Been at it a while" } }
    var detail: String {
        switch self {
        case .planning: "I’ve bought peptides or I’m planning to."
        case .starting: "I’m in my first few weeks."
        case .experienced: "I know my protocol. I want it organised."
        }
    }
    var symbol: String { switch self { case .planning: "shippingbox"; case .starting: "leaf"; case .experienced: "square.stack.3d.up" } }
}

enum SetupGoal: String, Codable, CaseIterable, Identifiable {
    case weightLoss, recovery, skin, longevity, muscle, energy
    var id: String { rawValue }
    var title: String {
        switch self {
        case .weightLoss: "Weight loss"
        case .recovery: "Injury & recovery"
        case .skin: "Skin & anti-ageing"
        case .longevity: "Longevity"
        case .muscle: "Muscle & performance"
        case .energy: "Energy & sleep"
        }
    }
    var symbol: String {
        switch self {
        case .weightLoss: "scalemass"
        case .recovery: "bandage"
        case .skin: "sparkles"
        case .longevity: "hourglass"
        case .muscle: "figure.strengthtraining.traditional"
        case .energy: "moon.zzz"
        }
    }
    /// Used in the plan headline, e.g. "Better recovery starts with a plan".
    var ambition: String {
        switch self {
        case .weightLoss: "Losing weight"
        case .recovery: "Better recovery"
        case .skin: "Healthier skin"
        case .longevity: "Ageing well"
        case .muscle: "Building strength"
        case .energy: "Better energy and sleep"
        }
    }
}

enum HeardFrom: String, Codable, CaseIterable, Identifiable {
    case tiktok, instagram, youtube, x, reddit, google, appStore, podcast, friend, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .tiktok: "TikTok"
        case .instagram: "Instagram"
        case .youtube: "YouTube"
        case .x: "X"
        case .reddit: "Reddit"
        case .google: "Google"
        case .appStore: "App Store"
        case .podcast: "Podcast"
        case .friend: "Friend or family"
        case .other: "Other"
        }
    }
    var symbol: String {
        switch self {
        case .tiktok: "music.note"
        case .instagram: "camera"
        case .youtube: "play.rectangle.fill"
        case .x: "xmark"
        case .reddit: "bubble.left.and.bubble.right.fill"
        case .google: "magnifyingglass"
        case .appStore: "bag.fill"
        case .podcast: "mic.fill"
        case .friend: "person.2.fill"
        case .other: "ellipsis"
        }
    }
}

enum DoseFrequency: String, Codable, CaseIterable, Identifiable {
    case daily, fewPerWeek, weekly, varies
    var id: String { rawValue }
    var title: String { switch self { case .daily: "Every day"; case .fewPerWeek: "A few times a week"; case .weekly: "Once a week"; case .varies: "It varies by peptide" } }
    var detail: String { switch self { case .daily: "One or more doses daily"; case .fewPerWeek: "Two to five days a week"; case .weekly: "One dose day each week"; case .varies: "Different schedules in one stack" } }
    var symbol: String { switch self { case .daily: "sun.max"; case .fewPerWeek: "calendar"; case .weekly: "calendar.badge.clock"; case .varies: "square.grid.2x2" } }
    /// Days of the week (0 = Monday) that show a dose in the illustrative week strip.
    var weekPattern: [Bool] {
        switch self {
        case .daily: [true, true, true, true, true, true, true]
        case .fewPerWeek: [true, false, true, false, true, false, false]
        case .weekly: [true, false, false, false, false, false, false]
        case .varies: [true, true, false, true, true, false, true]
        }
    }
}

enum SetupObstacle: String, Codable, CaseIterable, Identifiable {
    case forgetting, schedules, tracking, response, progress
    var id: String { rawValue }
    var title: String {
        switch self {
        case .forgetting: "Remembering every dose"
        case .schedules: "Keeping different schedules straight"
        case .tracking: "Knowing what I took and when"
        case .response: "Noticing how my body responds"
        case .progress: "Seeing my progress over time"
        }
    }
    var symbol: String {
        switch self {
        case .forgetting: "alarm"
        case .schedules: "calendar"
        case .tracking: "checklist"
        case .response: "waveform.path.ecg"
        case .progress: "chart.line.uptrend.xyaxis"
        }
    }
}

struct Peptide: Identifiable, Hashable {
    let name: String
    let category: String
    var id: String { name }

    static let library: [Peptide] = [
        Peptide(name: "Semaglutide", category: "GLP-1"),
        Peptide(name: "Tirzepatide", category: "GLP-1 / GIP"),
        Peptide(name: "Retatrutide", category: "GLP-1 / GIP / GCG"),
        Peptide(name: "BPC-157", category: "Recovery"),
        Peptide(name: "TB-500", category: "Recovery"),
        Peptide(name: "GHK-Cu", category: "Skin"),
        Peptide(name: "Ipamorelin", category: "GH secretagogue"),
        Peptide(name: "CJC-1295", category: "GH secretagogue"),
        Peptide(name: "MOTS-c", category: "Metabolic"),
        Peptide(name: "NAD+", category: "Longevity"),
        Peptide(name: "PT-141", category: "Sexual health"),
        Peptide(name: "KPV", category: "Recovery"),
        Peptide(name: "Liraglutide", category: "GLP-1"),
        Peptide(name: "Cagrilintide", category: "Amylin"),
        Peptide(name: "Tesamorelin", category: "GH secretagogue"),
        Peptide(name: "Sermorelin", category: "GH secretagogue"),
        Peptide(name: "AOD-9604", category: "Metabolic"),
        Peptide(name: "Epitalon", category: "Longevity"),
        Peptide(name: "Semax", category: "Cognitive"),
        Peptide(name: "Selank", category: "Cognitive"),
        Peptide(name: "DSIP", category: "Sleep"),
        Peptide(name: "Thymosin Alpha-1", category: "Immune"),
    ]
    static let popular = Array(library.prefix(12))

    static func category(for name: String) -> String {
        library.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.category ?? "Custom"
    }
}

struct PeptideStack: Identifiable, Hashable {
    let name: String
    let peptides: [String]
    var id: String { name }
    static let popular = [
        PeptideStack(name: "Wolverine", peptides: ["BPC-157", "TB-500"]),
        PeptideStack(name: "GLOW", peptides: ["GHK-Cu", "BPC-157", "TB-500"]),
        PeptideStack(name: "KLOW", peptides: ["GHK-Cu", "KPV", "BPC-157", "TB-500"]),
    ]
}

/// Answers from first-run setup. Persisted on every change so the flow resumes
/// exactly, then copied into the journal as the person's profile on completion.
struct SetupDraft: Codable, Equatable {
    static let compoundLimit = 12
    static let compoundNameLimit = 40
    static let referralLimit = 24
    static let weightRange = 30.0...250.0

    var step: SetupStep = .welcome
    var experience: PeptideExperience?
    var goals: Set<SetupGoal> = []
    var heardFrom: HeardFrom?
    var birthDate = SetupDraft.defaultBirthDate
    var usesMetric = Locale.current.measurementSystem == .metric
    var weightKg = 80.0
    var targetKg = 75.0
    var hasChosenTarget = false
    var compounds: [String] = []
    var frequency: DoseFrequency?
    var doseHour = 8
    var doseMinute = 0
    var obstacles: Set<SetupObstacle> = []
    var remindersRequested: Bool?
    var referralCode = ""
    var plan: OnboardingPlan = .annual

    static var defaultBirthDate: Date {
        var components = Calendar.current.dateComponents([.year], from: .now)
        components.year = (components.year ?? 2026) - 30
        components.month = 1; components.day = 1
        return Calendar.current.date(from: components) ?? .now
    }

    init() {}

    init(from decoder: Decoder) throws {
        // Every field is optional on disk, and retired screens or answers fall back
        // to defaults, so older drafts still open.
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let base = SetupDraft()
        step = (try? c.decodeIfPresent(SetupStep.self, forKey: .step)) ?? base.step
        experience = (try? c.decodeIfPresent(PeptideExperience.self, forKey: .experience)) ?? nil
        goals = try c.decodeIfPresent(Set<SetupGoal>.self, forKey: .goals) ?? []
        heardFrom = try c.decodeIfPresent(HeardFrom.self, forKey: .heardFrom)
        birthDate = try c.decodeIfPresent(Date.self, forKey: .birthDate) ?? base.birthDate
        usesMetric = try c.decodeIfPresent(Bool.self, forKey: .usesMetric) ?? base.usesMetric
        weightKg = try c.decodeIfPresent(Double.self, forKey: .weightKg) ?? base.weightKg
        targetKg = try c.decodeIfPresent(Double.self, forKey: .targetKg) ?? base.targetKg
        hasChosenTarget = try c.decodeIfPresent(Bool.self, forKey: .hasChosenTarget) ?? false
        compounds = try c.decodeIfPresent([String].self, forKey: .compounds) ?? []
        frequency = try c.decodeIfPresent(DoseFrequency.self, forKey: .frequency)
        doseHour = try c.decodeIfPresent(Int.self, forKey: .doseHour) ?? base.doseHour
        doseMinute = try c.decodeIfPresent(Int.self, forKey: .doseMinute) ?? base.doseMinute
        obstacles = Set(((try? c.decodeIfPresent([String].self, forKey: .obstacles)) ?? nil ?? []).compactMap(SetupObstacle.init(rawValue:)))
        remindersRequested = try c.decodeIfPresent(Bool.self, forKey: .remindersRequested)
        referralCode = try c.decodeIfPresent(String.self, forKey: .referralCode) ?? ""
        plan = try c.decodeIfPresent(OnboardingPlan.self, forKey: .plan) ?? .annual
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case step, experience, goals, heardFrom, birthDate, usesMetric, weightKg, targetKg, hasChosenTarget
        case compounds, frequency, doseHour, doseMinute, obstacles, remindersRequested, referralCode, plan
    }

    // MARK: Flow

    var tracksWeightGoal: Bool { goals.contains(.weightLoss) || goals.contains(.muscle) }

    var steps: [SetupStep] { SetupStep.allCases.filter { ![.weight, .target].contains($0) || tracksWeightGoal } }

    func step(after current: SetupStep) -> SetupStep? {
        let visible = steps, all = SetupStep.allCases
        guard let index = visible.firstIndex(of: current) else {
            let position = all.firstIndex(of: current) ?? 0
            return visible.first { (all.firstIndex(of: $0) ?? 0) > position }
        }
        return index + 1 < visible.count ? visible[index + 1] : nil
    }

    func step(before current: SetupStep) -> SetupStep? {
        let visible = steps, all = SetupStep.allCases
        guard let index = visible.firstIndex(of: current) else {
            let position = all.firstIndex(of: current) ?? 0
            return visible.last { (all.firstIndex(of: $0) ?? 0) < position }
        }
        guard index > 0 else { return nil }
        // Going back from the reveal or paywall never re-runs the loader.
        let previous = visible[index - 1]
        return previous == .building ? visible[index - 2] : previous
    }

    /// 0...1 across the questionnaire steps only.
    var progress: Double {
        let questions = steps.filter(\.showsProgress)
        guard let index = questions.firstIndex(of: step) else { return step == .welcome ? 0 : 1 }
        return Double(index + 1) / Double(questions.count + 1)
    }

    func canContinue(at step: SetupStep, now: Date = .now) -> Bool {
        switch step {
        case .experience: experience != nil
        case .goals: !goals.isEmpty
        case .source: heardFrom != nil
        case .birthday: isAdult(now: now)
        case .weight: Self.weightRange.contains(weightKg)
        case .target: Self.weightRange.contains(targetKg)
        case .frequency: frequency != nil
        case .obstacles: !obstacles.isEmpty
        case .referral: referralCode.isEmpty || Self.validReferral(referralCode)
        default: true
        }
    }

    // MARK: Derived values

    func age(now: Date = .now) -> Int? {
        guard birthDate <= now else { return nil }
        return Calendar.current.dateComponents([.year], from: birthDate, to: now).year
    }

    func isAdult(now: Date = .now) -> Bool { (age(now: now) ?? 0) >= 18 && (age(now: now) ?? 0) <= 110 }

    var weightUnit: WeightUnit { usesMetric ? .kg : .lb }

    /// Signed change towards the target in kilograms, rounded to 0.1.
    var targetChange: Double { ((targetKg - weightKg) * 10).rounded() / 10 }

    var targetDirection: String {
        if abs(targetChange) < 0.5 { return "Maintain weight" }
        return targetChange < 0 ? "Lose weight" : "Gain weight"
    }

    func formattedWeight(_ kilograms: Double) -> String {
        let value = weightUnit.display(kilograms)
        return "\(value.formatted(.number.precision(.fractionLength(1)))) \(weightUnit.rawValue)"
    }

    var formattedChange: String {
        let value = abs(weightUnit.display(weightKg + targetChange) - weightUnit.display(weightKg))
        return "\(value.formatted(.number.precision(.fractionLength(0...1)))) \(weightUnit.rawValue)"
    }

    var primaryGoal: SetupGoal? { SetupGoal.allCases.first { goals.contains($0) } }

    var doseTime: Date {
        Calendar.current.date(bySettingHour: doseHour, minute: doseMinute, second: 0, of: .now) ?? .now
    }

    var doseTimeText: String { doseTime.formatted(date: .omitted, time: .shortened) }

    /// Seeds a sensible starting target the first time the ruler appears.
    mutating func prepareTarget() {
        guard !hasChosenTarget else { return }
        let change = goals.contains(.weightLoss) ? -max(2, (weightKg * 0.08 * 2).rounded() / 2) : 3
        targetKg = min(Self.weightRange.upperBound, max(Self.weightRange.lowerBound, ((weightKg + change) * 10).rounded() / 10))
    }

    mutating func toggleCompound(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let index = compounds.firstIndex(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            compounds.remove(at: index)
        } else if Self.validCompound(trimmed), compounds.count < Self.compoundLimit {
            compounds.append(trimmed)
        }
    }

    func contains(_ compound: String) -> Bool {
        compounds.contains { $0.caseInsensitiveCompare(compound) == .orderedSame }
    }

    mutating func toggleStack(_ stack: PeptideStack) {
        if stack.peptides.allSatisfy(contains) {
            compounds.removeAll { name in stack.peptides.contains { $0.caseInsensitiveCompare(name) == .orderedSame } }
        } else {
            for peptide in stack.peptides where !contains(peptide) && compounds.count < Self.compoundLimit { compounds.append(peptide) }
        }
    }

    // MARK: Validation

    static func validCompound(_ name: String) -> Bool {
        !name.isEmpty && name.count <= compoundNameLimit && name.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) }
    }

    static func validReferral(_ code: String) -> Bool {
        code.count <= referralLimit && !code.isEmpty
            && code.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_" }
    }

    #if DEBUG
    static func example(at step: SetupStep) -> SetupDraft {
        var draft = SetupDraft()
        draft.step = step
        draft.experience = .starting; draft.goals = [.weightLoss, .recovery]; draft.heardFrom = .tiktok
        draft.usesMetric = true; draft.weightKg = 88.4; draft.targetKg = 80; draft.hasChosenTarget = true
        draft.compounds = ["Tirzepatide", "BPC-157"]; draft.frequency = .fewPerWeek; draft.obstacles = [.forgetting, .schedules]
        return draft
    }
    #endif

    var isValid: Bool {
        birthDate.timeIntervalSinceReferenceDate.isFinite
            && Self.weightRange.contains(weightKg) && Self.weightRange.contains(targetKg)
            && compounds.count <= Self.compoundLimit && compounds.allSatisfy(Self.validCompound)
            && Set(compounds.map { $0.lowercased() }).count == compounds.count
            && (0...23).contains(doseHour) && (0...59).contains(doseMinute)
            && (referralCode.isEmpty || Self.validReferral(referralCode))
    }
}
