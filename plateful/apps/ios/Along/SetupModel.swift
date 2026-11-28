import Foundation

enum SetupStep: String, Codable, CaseIterable, Identifiable {
    case welcome, experience, goals, source, showcase, pinMap, birthday, weight, target, commitment
    case compounds, frequency, doseTime, obstacles, trust, reminders, referral, ready, building, plan, account, paywall
    var id: String { rawValue }

    /// Steps that count towards the progress bar. The welcome, loader, reveal,
    /// account gate and paywall sit outside the questionnaire.
    var showsProgress: Bool { ![.welcome, .building, .plan, .account, .paywall].contains(self) }
    var showsBack: Bool { ![.welcome, .building].contains(self) }
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
    case daily, fewPerWeek, weekly, varies, later
    var id: String { rawValue }
    var title: String { switch self { case .daily: "Every day"; case .fewPerWeek: "A few times a week"; case .weekly: "Once a week"; case .varies: "Different days for each peptide"; case .later: "Set my schedule later" } }
    var detail: String { switch self { case .daily: "Choose a daily time"; case .fewPerWeek: "Choose the days in your protocol"; case .weekly: "One dose day each week"; case .varies: "Choose days and a time separately"; case .later: "Keep the peptide in your tracker without a due time" } }
    var symbol: String { switch self { case .daily: "sun.max"; case .fewPerWeek: "calendar"; case .weekly: "calendar.badge.clock"; case .varies: "square.grid.2x2"; case .later: "clock" } }
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

/// Public-catalogue reference signals for a peptide. Tracking context only —
/// never dosing guidance, efficacy claims, or medical advice.
struct PeptideReference: Equatable {
    /// Relative research-mention interest (0…100).
    var researchAttention: Int
    /// Relative published-study volume band (0…100).
    var studyVolume: Int
    /// Relative practical tracking interest in community catalogues (0…100).
    var practicalUse: Int

    var points: [(label: String, value: Int)] {
        [("Research", researchAttention), ("Studies", studyVolume), ("Tracking", practicalUse)]
    }

    static let disclaimer = "Reference signals from public catalogues for context only. Not medical advice, efficacy claims, or dosing guidance."
}

struct Peptide: Identifiable, Hashable {
    let name: String
    let category: String
    var id: String { name }

    /// Broad reference catalogue for search. Custom names remain allowed.
    static let library: [Peptide] = [
        Peptide(name: "Semaglutide", category: "GLP-1"),
        Peptide(name: "Tirzepatide", category: "GLP-1 / GIP"),
        Peptide(name: "Retatrutide", category: "GLP-1 / GIP / GCG"),
        Peptide(name: "Liraglutide", category: "GLP-1"),
        Peptide(name: "Dulaglutide", category: "GLP-1"),
        Peptide(name: "Exenatide", category: "GLP-1"),
        Peptide(name: "Cagrilintide", category: "Amylin"),
        Peptide(name: "BPC-157", category: "Recovery"),
        Peptide(name: "TB-500", category: "Recovery"),
        Peptide(name: "Thymosin Beta-4", category: "Recovery"),
        Peptide(name: "KPV", category: "Recovery"),
        Peptide(name: "GHK-Cu", category: "Skin"),
        Peptide(name: "AHK-Cu", category: "Skin"),
        Peptide(name: "Snap-8", category: "Skin"),
        Peptide(name: "Argireline", category: "Skin"),
        Peptide(name: "Ipamorelin", category: "GH secretagogue"),
        Peptide(name: "CJC-1295", category: "GH secretagogue"),
        Peptide(name: "CJC-1295 DAC", category: "GH secretagogue"),
        Peptide(name: "Tesamorelin", category: "GH secretagogue"),
        Peptide(name: "Sermorelin", category: "GH secretagogue"),
        Peptide(name: "GHRP-2", category: "GH secretagogue"),
        Peptide(name: "GHRP-6", category: "GH secretagogue"),
        Peptide(name: "Hexarelin", category: "GH secretagogue"),
        Peptide(name: "MK-677", category: "GH secretagogue"),
        Peptide(name: "MOTS-c", category: "Metabolic"),
        Peptide(name: "AOD-9604", category: "Metabolic"),
        Peptide(name: "5-Amino-1MQ", category: "Metabolic"),
        Peptide(name: "SLU-PP-332", category: "Metabolic"),
        Peptide(name: "NAD+", category: "Longevity"),
        Peptide(name: "NMN", category: "Longevity"),
        Peptide(name: "NR", category: "Longevity"),
        Peptide(name: "Epitalon", category: "Longevity"),
        Peptide(name: "FOXO4-DRI", category: "Longevity"),
        Peptide(name: "Humanin", category: "Longevity"),
        Peptide(name: "PT-141", category: "Sexual health"),
        Peptide(name: "Melanotan II", category: "Sexual health"),
        Peptide(name: "Oxytocin", category: "Sexual health"),
        Peptide(name: "Semax", category: "Cognitive"),
        Peptide(name: "Selank", category: "Cognitive"),
        Peptide(name: "Dihexa", category: "Cognitive"),
        Peptide(name: "P21", category: "Cognitive"),
        Peptide(name: "Noopept", category: "Cognitive"),
        Peptide(name: "Pinealon", category: "Cognitive"),
        Peptide(name: "DSIP", category: "Sleep"),
        Peptide(name: "Epithalon", category: "Longevity"),
        Peptide(name: "Thymosin Alpha-1", category: "Immune"),
        Peptide(name: "LL-37", category: "Immune"),
        Peptide(name: "Thymalin", category: "Immune"),
        Peptide(name: "SS-31", category: "Mitochondrial"),
        Peptide(name: "Methylene Blue", category: "Mitochondrial"),
        Peptide(name: "IGF-1 LR3", category: "Growth factor"),
        Peptide(name: "PEG-MGF", category: "Growth factor"),
        Peptide(name: "Follistatin 344", category: "Growth factor"),
        Peptide(name: "ACE-031", category: "Growth factor"),
        Peptide(name: "Kisspeptin-10", category: "Hormonal"),
        Peptide(name: "Gonadorelin", category: "Hormonal"),
        Peptide(name: "HCG", category: "Hormonal"),
        Peptide(name: "VIP", category: "Gut / immune"),
        Peptide(name: "Larazotide", category: "Gut / immune"),
        Peptide(name: "BPC-157 Oral", category: "Recovery"),
        Peptide(name: "Cerebrolysin", category: "Cognitive"),
        Peptide(name: "PNC-27", category: "Research"),
        Peptide(name: "ARA-290", category: "Recovery"),
        Peptide(name: "BAM-15", category: "Metabolic"),
        Peptide(name: "Cardarine", category: "Metabolic"),
        Peptide(name: "GW501516", category: "Metabolic"),
        Peptide(name: "Tesofensine", category: "Metabolic"),
        Peptide(name: "Survodutide", category: "GLP-1 / GCG"),
        Peptide(name: "Mazdutide", category: "GLP-1 / GCG"),
        Peptide(name: "Orforglipron", category: "GLP-1"),
        Peptide(name: "MariTide", category: "GLP-1 / GIP"),
    ]
    /// Shown when search is empty. First twelve of the catalogue.
    static let popular = Array(library.prefix(12))

    static func category(for name: String) -> String {
        library.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.category ?? "Custom"
    }

    static func matches(_ query: String) -> [Peptide] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return popular }
        return library.filter {
            $0.name.localizedCaseInsensitiveContains(q) || $0.category.localizedCaseInsensitiveContains(q)
        }
    }

    /// Curated reference bands for known names; category defaults otherwise.
    static func reference(for name: String) -> PeptideReference {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let known = referenceTable[key] { return known }
        return categoryDefaults[category(for: name)] ?? PeptideReference(researchAttention: 35, studyVolume: 30, practicalUse: 35)
    }

    private static let referenceTable: [String: PeptideReference] = [
        "semaglutide": .init(researchAttention: 96, studyVolume: 94, practicalUse: 92),
        "tirzepatide": .init(researchAttention: 94, studyVolume: 90, practicalUse: 93),
        "retatrutide": .init(researchAttention: 82, studyVolume: 70, practicalUse: 78),
        "liraglutide": .init(researchAttention: 88, studyVolume: 92, practicalUse: 70),
        "dulaglutide": .init(researchAttention: 80, studyVolume: 85, practicalUse: 62),
        "bpc-157": .init(researchAttention: 72, studyVolume: 48, practicalUse: 88),
        "tb-500": .init(researchAttention: 58, studyVolume: 36, practicalUse: 80),
        "ghk-cu": .init(researchAttention: 64, studyVolume: 52, practicalUse: 76),
        "ipamorelin": .init(researchAttention: 60, studyVolume: 44, practicalUse: 74),
        "cjc-1295": .init(researchAttention: 55, studyVolume: 40, practicalUse: 70),
        "cjc-1295 dac": .init(researchAttention: 52, studyVolume: 38, practicalUse: 66),
        "tesamorelin": .init(researchAttention: 70, studyVolume: 68, practicalUse: 58),
        "mots-c": .init(researchAttention: 62, studyVolume: 50, practicalUse: 64),
        "epitalon": .init(researchAttention: 48, studyVolume: 34, practicalUse: 60),
        "epithalon": .init(researchAttention: 48, studyVolume: 34, practicalUse: 60),
        "pt-141": .init(researchAttention: 68, studyVolume: 60, practicalUse: 72),
        "semax": .init(researchAttention: 50, studyVolume: 42, practicalUse: 58),
        "selank": .init(researchAttention: 46, studyVolume: 38, practicalUse: 54),
        "ss-31": .init(researchAttention: 66, studyVolume: 55, practicalUse: 60),
        "thymosin alpha-1": .init(researchAttention: 74, studyVolume: 72, practicalUse: 56),
        "nad+": .init(researchAttention: 78, studyVolume: 70, practicalUse: 82),
        "mk-677": .init(researchAttention: 58, studyVolume: 45, practicalUse: 76),
    ]

    private static let categoryDefaults: [String: PeptideReference] = [
        "GLP-1": .init(researchAttention: 85, studyVolume: 80, practicalUse: 78),
        "GLP-1 / GIP": .init(researchAttention: 88, studyVolume: 82, practicalUse: 84),
        "GLP-1 / GIP / GCG": .init(researchAttention: 80, studyVolume: 68, practicalUse: 76),
        "GLP-1 / GCG": .init(researchAttention: 78, studyVolume: 70, practicalUse: 72),
        "Recovery": .init(researchAttention: 55, studyVolume: 40, practicalUse: 72),
        "Skin": .init(researchAttention: 50, studyVolume: 42, practicalUse: 65),
        "GH secretagogue": .init(researchAttention: 52, studyVolume: 40, practicalUse: 68),
        "Metabolic": .init(researchAttention: 58, studyVolume: 45, practicalUse: 62),
        "Longevity": .init(researchAttention: 55, studyVolume: 42, practicalUse: 60),
        "Cognitive": .init(researchAttention: 48, studyVolume: 38, practicalUse: 52),
        "Immune": .init(researchAttention: 60, studyVolume: 55, practicalUse: 50),
        "Custom": .init(researchAttention: 30, studyVolume: 25, practicalUse: 30),
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
    var quickSetup = false
    var experience: PeptideExperience?
    var goals: Set<SetupGoal> = []
    var heardFrom: HeardFrom?
    /// New setups store only the adult confirmation. Keep dates from earlier journals readable.
    var birthDate: Date?
    var confirmedAdult = false
    var usesMetric = Locale.current.measurementSystem == .metric
    var weightKg = 80.0
    var targetKg = 75.0
    var hasChosenTarget = false
    var compounds: [String] = [] {
        didSet {
            peptideSchedules = peptideSchedules.filter { compounds.contains($0.key) }
            lastInjections = lastInjections.filter { compounds.contains($0.key) }
        }
    }
    var sharedWeekdays: Set<Int> = []
    var peptideSchedules: [String: DoseSchedule] = [:]
    var lastInjections: [String: SetupInjection] = [:]
    var frequency: DoseFrequency?
    var doseHour = 8
    var doseMinute = 0
    var obstacles: Set<SetupObstacle> = []
    var remindersRequested: Bool?
    var referralCode = ""
    var plan: OnboardingPlan = .annual
    /// Collected before paywall; Firebase account is created on successful purchase.
    var accountEmail = ""

    init() {}

    init(from decoder: Decoder) throws {
        // Every field is optional on disk, and retired screens or answers fall back
        // to defaults, so older drafts still open.
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let base = SetupDraft()
        step = (try? c.decodeIfPresent(SetupStep.self, forKey: .step)) ?? base.step
        quickSetup = try c.decodeIfPresent(Bool.self, forKey: .quickSetup) ?? false
        experience = (try? c.decodeIfPresent(PeptideExperience.self, forKey: .experience)) ?? nil
        if let goalValues = try c.decodeIfPresent([String].self, forKey: .goals) {
            goals = Set(goalValues.compactMap(SetupGoal.init(rawValue:)))
        } else {
            goals = try c.decodeIfPresent(Set<SetupGoal>.self, forKey: .goals) ?? []
        }
        heardFrom = try c.decodeIfPresent(HeardFrom.self, forKey: .heardFrom)
        birthDate = try c.decodeIfPresent(Date.self, forKey: .birthDate)
        confirmedAdult = try c.decodeIfPresent(Bool.self, forKey: .confirmedAdult) ?? false
        usesMetric = try c.decodeIfPresent(Bool.self, forKey: .usesMetric) ?? base.usesMetric
        weightKg = try c.decodeIfPresent(Double.self, forKey: .weightKg) ?? base.weightKg
        targetKg = try c.decodeIfPresent(Double.self, forKey: .targetKg) ?? base.targetKg
        hasChosenTarget = try c.decodeIfPresent(Bool.self, forKey: .hasChosenTarget) ?? false
        compounds = try c.decodeIfPresent([String].self, forKey: .compounds) ?? []
        sharedWeekdays = try c.decodeIfPresent(Set<Int>.self, forKey: .sharedWeekdays) ?? []
        peptideSchedules = try c.decodeIfPresent([String: DoseSchedule].self, forKey: .peptideSchedules) ?? [:]
        lastInjections = try c.decodeIfPresent([String: SetupInjection].self, forKey: .lastInjections) ?? [:]
        frequency = try c.decodeIfPresent(DoseFrequency.self, forKey: .frequency)
        doseHour = try c.decodeIfPresent(Int.self, forKey: .doseHour) ?? base.doseHour
        doseMinute = try c.decodeIfPresent(Int.self, forKey: .doseMinute) ?? base.doseMinute
        obstacles = Set(((try? c.decodeIfPresent([String].self, forKey: .obstacles)) ?? nil ?? []).compactMap(SetupObstacle.init(rawValue:)))
        remindersRequested = try c.decodeIfPresent(Bool.self, forKey: .remindersRequested)
        referralCode = try c.decodeIfPresent(String.self, forKey: .referralCode) ?? ""
        plan = try c.decodeIfPresent(OnboardingPlan.self, forKey: .plan) ?? .annual
        accountEmail = try c.decodeIfPresent(String.self, forKey: .accountEmail) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(step, forKey: .step)
        if quickSetup { try c.encode(true, forKey: .quickSetup) }
        try c.encodeIfPresent(experience, forKey: .experience)
        try c.encode(goals.map(\.rawValue).sorted(), forKey: .goals)
        try c.encodeIfPresent(heardFrom, forKey: .heardFrom)
        try c.encodeIfPresent(birthDate, forKey: .birthDate)
        if confirmedAdult { try c.encode(true, forKey: .confirmedAdult) }
        try c.encode(usesMetric, forKey: .usesMetric)
        try c.encode(weightKg, forKey: .weightKg)
        try c.encode(targetKg, forKey: .targetKg)
        try c.encode(hasChosenTarget, forKey: .hasChosenTarget)
        try c.encode(compounds, forKey: .compounds)
        if !sharedWeekdays.isEmpty { try c.encode(sharedWeekdays, forKey: .sharedWeekdays) }
        if !peptideSchedules.isEmpty { try c.encode(peptideSchedules, forKey: .peptideSchedules) }
        if !lastInjections.isEmpty { try c.encode(lastInjections, forKey: .lastInjections) }
        try c.encodeIfPresent(frequency, forKey: .frequency)
        try c.encode(doseHour, forKey: .doseHour)
        try c.encode(doseMinute, forKey: .doseMinute)
        try c.encode(obstacles.map(\.rawValue).sorted(), forKey: .obstacles)
        try c.encodeIfPresent(remindersRequested, forKey: .remindersRequested)
        try c.encode(referralCode, forKey: .referralCode)
        try c.encode(plan, forKey: .plan)
        try c.encode(accountEmail, forKey: .accountEmail)
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case step, quickSetup, experience, goals, heardFrom, birthDate, confirmedAdult, usesMetric, weightKg, targetKg, hasChosenTarget
        case sharedWeekdays, peptideSchedules, lastInjections
        case compounds, frequency, doseHour, doseMinute, obstacles, remindersRequested, referralCode, plan, accountEmail
    }

    // MARK: Flow

    var tracksWeightGoal: Bool { goals.contains(.weightLoss) || goals.contains(.muscle) }

    private var route: [SetupStep] {
        if quickSetup {
            return [.welcome, .birthday, .compounds, .frequency, .doseTime, .reminders, .ready, .plan, .account, .paywall]
        }
        return SetupStep.allCases.filter { $0 != .building }
    }

    var steps: [SetupStep] {
        route.filter { candidate in
            switch candidate {
            case .weight, .target: tracksWeightGoal
            case .frequency, .ready: !compounds.isEmpty
            case .doseTime: !compounds.isEmpty && frequency != .later
            case .reminders: hasScheduledPeptides
            default: true
            }
        }
    }

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
        return visible[index - 1]
    }

    /// 0...1 across the questionnaire steps only.
    var progress: Double {
        let questions = route.filter(\.showsProgress)
        guard let index = questions.firstIndex(of: step) else { return step == .welcome ? 0 : 1 }
        return Double(index + 1) / Double(questions.count + 1)
    }

    func canContinue(at step: SetupStep, now: Date = .now) -> Bool {
        switch step {
        case .experience: experience != nil
        case .goals: !goals.isEmpty
        case .birthday: isAdult(now: now)
        case .weight: Self.weightRange.contains(weightKg)
        case .target: Self.weightRange.contains(targetKg)
        case .frequency: frequency != nil
        case .doseTime:
            if compounds.isEmpty { true }
            else if frequency == .weekly { sharedWeekdays.count == 1 }
            else if frequency == .fewPerWeek { sharedWeekdays.count >= 2 }
            else { true }
        case .referral, .plan: referralCode.isEmpty || Self.validReferral(referralCode)
        case .account: Self.validEmail(accountEmail)
        default: true
        }
    }

    // MARK: Derived values

    func age(now: Date = .now) -> Int? {
        guard let birthDate, birthDate <= now else { return nil }
        return Calendar.current.dateComponents([.year], from: birthDate, to: now).year
    }

    func isAdult(now: Date = .now) -> Bool {
        guard birthDate != nil else { return confirmedAdult }
        return (18...110).contains(age(now: now) ?? 0)
    }

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

    func schedule(for name: String) -> DoseSchedule {
        let time = DoseTime(hour: doseHour, minute: doseMinute)
        switch frequency {
        case .daily: return .daily(at: time)
        case .weekly, .fewPerWeek:
            guard !sharedWeekdays.isEmpty, canContinue(at: .doseTime) else { return .unscheduled }
            return .on(sharedWeekdays, at: time)
        case .varies: return peptideSchedules[name] ?? .unscheduled
        case .later, nil: return .unscheduled
        }
    }

    var hasScheduledPeptides: Bool { compounds.contains { schedule(for: $0).kind != .unscheduled } }

    var reminderSummary: String {
        guard remindersRequested == true else { return "Reminders off" }
        return hasScheduledPeptides ? "Reminders at your scheduled times" : "Reminders start when you add a schedule"
    }

    var primaryGoal: SetupGoal? { SetupGoal.allCases.first { goals.contains($0) } }

    var doseTime: Date {
        Calendar.current.date(bySettingHour: doseHour, minute: doseMinute, second: 0, of: .now) ?? .now
    }

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


    // MARK: Validation

    static func validCompound(_ name: String) -> Bool {
        !name.isEmpty && name.count <= compoundNameLimit && name.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) }
    }

    static func validReferral(_ code: String) -> Bool {
        code.count <= referralLimit && !code.isEmpty
            && code.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_" }
    }

    static func validEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= 254, trimmed.contains("@") else { return false }
        let parts = trimmed.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, parts[1].contains(".") else { return false }
        return trimmed.unicodeScalars.allSatisfy { !CharacterSet.whitespacesAndNewlines.contains($0) }
    }

    #if DEBUG
    static func example(at step: SetupStep) -> SetupDraft {
        var draft = SetupDraft()
        draft.step = step
        draft.confirmedAdult = true
        draft.experience = .starting; draft.goals = [.weightLoss, .recovery]; draft.heardFrom = .tiktok
        draft.usesMetric = true; draft.weightKg = 88.4; draft.targetKg = 80; draft.hasChosenTarget = true
        draft.compounds = ["Tirzepatide", "BPC-157"]; draft.frequency = .fewPerWeek; draft.obstacles = [.forgetting, .schedules]
        draft.sharedWeekdays = [2, 4, 6]
        return draft
    }
    #endif

    var isValid: Bool {
        (birthDate?.timeIntervalSinceReferenceDate.isFinite ?? true)
            && Self.weightRange.contains(weightKg) && Self.weightRange.contains(targetKg)
            && compounds.count <= Self.compoundLimit && compounds.allSatisfy(Self.validCompound)
            && Set(compounds.map { $0.lowercased() }).count == compounds.count
            && sharedWeekdays.isSubset(of: Set(1...7))
            && peptideSchedules.allSatisfy { compounds.contains($0.key) && $0.value.kind == .weekdays && $0.value.isValid }
            && lastInjections.allSatisfy { compounds.contains($0.key) && DayIdentity.isPlausible($0.value.dayKey, for: $0.value.takenAt) }
            && Set(lastInjections.values.map(\.id)).count == lastInjections.count
            && (0...23).contains(doseHour) && (0...59).contains(doseMinute)
            && (referralCode.isEmpty || Self.validReferral(referralCode))
    }
}
