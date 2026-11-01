import Foundation

enum OnboardingPlan: String, Codable, CaseIterable, Identifiable {
    case annual, monthly
    var id: String { rawValue }
}

struct OnboardingDraft: Codable, Equatable {
    static let totalSteps = 26
    var step = 0
    var name = ""
    var stage = ""
    var hasStartDate = false
    var startDate = Date()
    var priority = ""
    var obstacle = ""
    var progressAreas: Set<String> = []
    var intention = ""
    var showWeight = false
    var weightValue = ""
    var weightUnit: WeightUnit = .kg
    var routines: Set<Routine> = []
    var routineNames: [String: String] = [:]
    var frequency = "Flexible"
    var reminder = "Off"
    var reflectionDay = 1
    var encouragement = "Gentle"
    var accessory: Accessory = .leaf
    var companionName = "Pip"
    var mood: Mood?
    var appetite: Appetite?
    var note = ""
    var plan: OnboardingPlan = .annual

    var displayCompanionName: String {
        let value = companionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Pip" : value
    }

    var baselineKilograms: Double? {
        guard showWeight else { return nil }
        let raw = weightValue.trimmingCharacters(in: .whitespacesAndNewlines)
        // Accept either decimal separator, but not ambiguous grouping, exponents,
        // nonfinite values, signs or partially parsed numbers.
        guard raw.range(of: #"^[0-9]+(?:[.,][0-9]+)?$"#, options: .regularExpression) != nil,
              let value = Double(raw.replacingOccurrences(of: ",", with: ".")) else { return nil }
        let kilograms = weightUnit.kilograms(value)
        return JournalValidation.weight(kilograms) ? kilograms : nil
    }

    func canContinue(at index: Int) -> Bool {
        guard (0..<Self.totalSteps).contains(index) else { return false }
        switch index {
        case 1: return Self.validText(name, limit: 30)
        case 2: return Self.validText(stage, limit: 80, required: true)
        case 3: return !hasStartDate || (startDate.timeIntervalSinceReferenceDate.isFinite && Calendar.current.startOfDay(for: startDate) <= Calendar.current.startOfDay(for: .now))
        case 4: return Self.validText(priority, limit: 80, required: true)
        case 5: return Self.validText(obstacle, limit: 80, required: true)
        case 7: return (1...3).contains(progressAreas.count) && progressAreas.allSatisfy { Self.validText($0, limit: 80, required: true) }
        case 8: return Self.validText(intention, limit: 300)
        case 10: return !showWeight || weightValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || baselineKilograms != nil
        case 12: return routines.count <= 2
        case 13: return routineNames.allSatisfy { Routine(rawValue: $0.key) != nil && Self.validText($0.value, limit: 80, required: true) }
        case 14: return Self.validText(frequency, limit: 80, required: true)
        case 15: return Self.validText(reminder, limit: 80, required: true)
        case 16: return (1...7).contains(reflectionDay)
        case 17: return ["Gentle", "Straightforward", "Celebratory"].contains(encouragement)
        case 19: return Self.validText(companionName, limit: 24)
        case 20: return mood != nil && appetite != nil
        case 21: return Self.validText(note, limit: 500)
        default: return true
        }
    }

    /// Drafts may be incomplete, but oversized or malformed local files must not
    /// replace a valid journal. Required choices are enforced at their own step.
    var isValidForPersistence: Bool {
        (0..<Self.totalSteps).contains(step)
            && Self.validText(name, limit: 30)
            && Self.validText(stage, limit: 80)
            && startDate.timeIntervalSinceReferenceDate.isFinite
            && Self.validText(priority, limit: 80)
            && Self.validText(obstacle, limit: 80)
            && progressAreas.count <= 3
            && progressAreas.allSatisfy { Self.validText($0, limit: 80, required: true) }
            && Self.validText(intention, limit: 300)
            && Self.validText(weightValue, limit: 30)
            && routines.count <= 2
            && routineNames.count <= Routine.allCases.count
            && routineNames.allSatisfy { Routine(rawValue: $0.key) != nil && Self.validText($0.value, limit: 80) }
            && Self.validText(frequency, limit: 80)
            && Self.validText(reminder, limit: 80)
            && (1...7).contains(reflectionDay)
            && ["Gentle", "Straightforward", "Celebratory"].contains(encouragement)
            && Self.validText(companionName, limit: 24)
            && Self.validText(note, limit: 500)
    }

    var isReadyToSaveEntry: Bool {
        isValidForPersistence && (0...21).allSatisfy { canContinue(at: $0) }
    }

    private static func validText(_ text: String, limit: Int, required: Bool = false) -> Bool {
        text.count <= limit
            && (!required || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            && !text.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) && $0 != "\n" && $0 != "\t" }
    }
}
