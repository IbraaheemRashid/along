import Foundation

@MainActor extension JournalStore {
    func routineTitle(_ routine: Routine) -> String {
        let saved = journal.onboardingPreferences?.routineNames[routine.rawValue]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return saved.isEmpty ? routine.title : saved
    }
    var encouragementLine: String {
        switch journal.onboardingPreferences?.encouragement {
        case "Straightforward": return today == nil ? "A short check-in keeps your record up to date." : "Today’s entry is saved. You can revisit it any time."
        case "Celebratory": return today == nil ? "A new day. Another little piece of your story!" : "Another little moment in your story. Glad you’re here!"
        default: return today == nil ? "No perfect days needed.\nJust a moment to notice this one." : "Today has a place in your story.\nI’m glad you stopped by."
        }
    }
    var personalReflectionPrompt: String? {
        guard let preferences = journal.onboardingPreferences, let area = preferences.progressAreas.sorted().first else { return nil }
        return "You wanted to notice \(area.lowercased()). Is there a moment from this week you’d like to remember?"
    }
    var reflectionSchedule: String? {
        guard let day = journal.onboardingPreferences?.reflectionDay, (1...7).contains(day) else { return nil }
        return "Your \(Calendar.current.weekdaySymbols[day - 1]) reflection"
    }
}
