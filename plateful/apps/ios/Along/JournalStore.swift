import SwiftUI
import Observation

private struct OnboardingArchive: Codable {
    var version = 1
    var draft = OnboardingDraft()
    var entryID: UUID?
    var entryDate: Date?
    var ownsEntry = false
    var weightID: UUID?
    var ownsWeight = false
}

@MainActor @Observable final class JournalStore {
    var journal = Journal()
    var onboardingDraft = OnboardingDraft() {
        didSet { if !loadingDraft { saveOnboardingDraft() } }
    }
    var selectedTab = 0
    var toast: String?
    var error: String?
    private let url: URL
    private let draftURL: URL
    private let clearCredentials: () -> Void
    private var canSave = true
    private var canSaveDraft = true
    private var loadingDraft = true
    private var onboardingArchive = OnboardingArchive()
    private var toastTask: Task<Void, Never>?
    init(directory: URL? = nil, arguments: [String] = ProcessInfo.processInfo.arguments, clearCredentials: @escaping () -> Void = TokenVault.clear) {
        var folder = "Along"
        #if DEBUG
        if arguments.contains("--ui-testing") || arguments.contains("--onboarding-step") || arguments.contains("--review-onboarding") { folder = "AlongDesignReview" }
        #endif
        let directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent(folder, isDirectory: true)
        url = directory.appendingPathComponent("journal-v1.json")
        draftURL = directory.appendingPathComponent("onboarding-draft-v1.json")
        self.clearCredentials = clearCredentials
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: url.path) {
                journal = try JSONDecoder().decode(Journal.self, from: Data(contentsOf: url))
            }
        } catch { canSave = false; self.error = "We couldn’t open your local journal. Your existing file hasn’t been overwritten. You can retry by reopening the app." }
        do {
            if FileManager.default.fileExists(atPath: draftURL.path) {
                let data = try Data(contentsOf: draftURL)
                guard data.count <= 65536 else { throw CocoaError(.fileReadCorruptFile) }
                let archive = try JSONDecoder().decode(OnboardingArchive.self, from: data)
                guard archive.version == 1, archive.draft.isValidForPersistence,
                      (archive.entryID == nil) == (archive.entryDate == nil),
                      archive.entryDate?.timeIntervalSinceReferenceDate.isFinite ?? true else { throw CocoaError(.fileReadCorruptFile) }
                onboardingArchive = archive
                onboardingDraft = archive.draft
            }
        } catch {
            canSaveDraft = false
            if self.error == nil { self.error = "Your setup draft couldn’t be opened. Your journal is unchanged. Restart setup to replace only the draft." }
        }
        loadingDraft = false
        #if DEBUG
        if arguments.contains("--reset-demo") { clearJournal(); error = nil }
        if arguments.contains("--sample-journey") {
            journal = Journal.sample(); journal.name = "Alex"; journal.hasOnboarded = true; canSave = true; error = nil; persist()
        }
        if arguments.contains("--review-onboarding") { journal.hasOnboarded = false; persist() }
        #endif
    }
    var today: CheckIn? { journal.checkIns.first { Calendar.current.isDateInToday($0.day) } }
    var week: [CheckIn] { journal.week() }
    var routineCount: Int { week.reduce(0) { $0 + $1.routines.count } }
    var weeklyMilestones: [Milestone] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let start = calendar.date(byAdding: .day, value: -6, to: today)!
        let end = calendar.date(byAdding: .day, value: 1, to: today)!
        return journal.milestones.filter { $0.date >= start && $0.date < end }.sorted { $0.date > $1.date }
    }
    var companionName: String { journal.companionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Pip" : journal.companionName }
    var daysTogether: Int { max(1, (Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: journal.startDate), to: Calendar.current.startOfDay(for: .now)).day ?? 0) + 1) }
    var recap: String {
        if week.isEmpty { return "Your story starts with a moment. Check in whenever it feels useful, and your recorded moments will appear here." }
        let noun = week.count == 1 ? "day" : "days"
        let moments = routineCount == 1 ? "routine moment" : "routine moments"
        return "You made space to check in on \(week.count) \(noun) and recorded \(routineCount) \(moments) this week. Every entry is a little piece of your story. Days without entries simply aren’t recorded."
    }
    @discardableResult func persist() -> Bool {
        persist(journal)
    }
    private func persist(_ value: Journal) -> Bool {
        guard canSave else { error = "The existing journal could not be read. To protect it, saving is disabled. Reopen the app to retry, or explicitly reset local data in You."; return false }
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            var resource = url
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try resource.setResourceValues(values)
            return true
        } catch { self.error = "Your changes couldn’t be saved on this device. Please try again before closing the app."; return false }
    }
    @discardableResult func saveOnboardingDraft() -> Bool {
        guard canSaveDraft else { error = "Your existing setup draft is protected. Restart setup to replace the draft; your journal will be kept."; return false }
        guard onboardingDraft.isValidForPersistence else { error = "Check the length of your setup answers before continuing."; return false }
        do {
            onboardingArchive.draft = onboardingDraft
            let data = try JSONEncoder().encode(onboardingArchive)
            try data.write(to: draftURL, options: [.atomic, .completeFileProtection])
            var resource = draftURL
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try resource.setResourceValues(values)
            return true
        } catch { self.error = "Your setup couldn’t be saved on this device. Please try again before closing the app."; return false }
    }
    @discardableResult func saveOnboardingEntry(now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard canSave, onboardingDraft.isReadyToSaveEntry,
              let mood = onboardingDraft.mood, let appetite = onboardingDraft.appetite else {
            error = "Complete your setup choices and first check-in before continuing. Your existing journal is unchanged."; return false
        }
        var candidate = journal
        let day = onboardingArchive.entryDate ?? now
        guard JournalValidation.checkIn(note: onboardingDraft.note, day: day, now: now, calendar: calendar) else { error = "Check the date and note before saving your first entry."; return false }
        if onboardingArchive.entryID == nil {
            if let existing = candidate.checkIns.first(where: { calendar.isDate($0.day, inSameDayAs: day) && !$0.isSample }) {
                // Reviewing setup must never overwrite somebody's existing day.
                onboardingArchive.entryID = existing.id
                onboardingArchive.entryDate = existing.day
                onboardingArchive.ownsEntry = false
            } else {
                onboardingArchive.entryID = UUID()
                onboardingArchive.entryDate = day
                onboardingArchive.ownsEntry = true
            }
        }
        if onboardingArchive.ownsEntry, let id = onboardingArchive.entryID, let date = onboardingArchive.entryDate {
            let entry = CheckIn(id: id, day: date, mood: mood, appetite: appetite, routines: [], note: onboardingDraft.note.trimmingCharacters(in: .whitespacesAndNewlines), isSample: false)
            if let index = candidate.checkIns.firstIndex(where: { $0.id == id }) { candidate.checkIns[index] = entry }
            else {
                // Keep unrelated real records, even if added since this draft.
                if !candidate.checkIns.contains(where: { calendar.isDate($0.day, inSameDayAs: date) && !$0.isSample }) {
                    candidate.checkIns.removeAll { $0.isSample && calendar.isDate($0.day, inSameDayAs: date) }
                    candidate.checkIns.append(entry)
                }
            }
        }
        if let kilograms = onboardingDraft.baselineKilograms, let date = onboardingArchive.entryDate {
            if onboardingArchive.weightID == nil {
                if let existing = candidate.weights.first(where: { calendar.isDate($0.date, inSameDayAs: date) && !$0.isSample }) {
                    onboardingArchive.weightID = existing.id; onboardingArchive.ownsWeight = false
                } else { onboardingArchive.weightID = UUID(); onboardingArchive.ownsWeight = true }
            }
            if onboardingArchive.ownsWeight, let id = onboardingArchive.weightID {
                let weight = WeightEntry(id: id, date: date, kilograms: kilograms, isSample: false)
                if let index = candidate.weights.firstIndex(where: { $0.id == id }) { candidate.weights[index] = weight }
                else if !candidate.weights.contains(where: { calendar.isDate($0.date, inSameDayAs: date) && !$0.isSample }) {
                    candidate.weights.removeAll { $0.isSample && calendar.isDate($0.date, inSameDayAs: date) }
                    candidate.weights.append(weight)
                }
            }
        } else if onboardingArchive.ownsWeight, let id = onboardingArchive.weightID {
            // Back/skip can undo only the baseline created by this setup.
            candidate.weights.removeAll { $0.id == id }
        }
        candidate.name = onboardingDraft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        candidate.companionName = onboardingDraft.displayCompanionName
        candidate.routines = onboardingDraft.routines
        candidate.weightUnit = onboardingDraft.weightUnit
        candidate.showWeight = onboardingDraft.showWeight
        candidate.accessory = onboardingDraft.accessory
        candidate.unlockedAccessories.insert(onboardingDraft.accessory)
        if onboardingDraft.hasStartDate { candidate.startDate = onboardingDraft.startDate }
        candidate.onboardingPreferences = onboardingDraft
        // Save the identity/date envelope first, so a retry after interruption or
        // a different calendar day cannot manufacture another first entry.
        guard saveOnboardingDraft(), persist(candidate) else { return false }
        journal = candidate
        return true
    }
    @discardableResult func finishOnboardingPreview() -> Bool {
        #if DEBUG
        guard saveOnboardingEntry() else { return false }
        var candidate = journal
        candidate.isDesignPreview = true
        candidate.hasOnboarded = true
        guard persist(candidate) else { return false }
        journal = candidate
        return true
        #else
        error = "Design preview access is only available in a development build. No subscription has been activated."
        return false
        #endif
    }
    func resetOnboarding() {
        guard canSave else { error = "Your existing journal is protected. Reopen the app to retry before restarting setup."; return }
        var candidate = journal
        candidate.hasOnboarded = false
        guard persist(candidate) else { return }
        journal = candidate
        onboardingArchive = OnboardingArchive()
        loadingDraft = true; onboardingDraft = OnboardingDraft(); loadingDraft = false
        canSaveDraft = true
        selectedTab = 0
        saveOnboardingDraft()
    }
    func onboard(name: String, companion: String, routines: Set<Routine>, sample: Bool) {
        journal = sample ? Journal.sample() : Journal()
        journal.name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(30))
        journal.companionName = String(companion.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
        if journal.companionName.isEmpty { journal.companionName = "Pip" }
        journal.routines = routines
        journal.hasOnboarded = true
        persist()
    }
    func saveCheckIn(day: Date, mood: Mood, appetite: Appetite, routines: Set<Routine>, note: String) -> Bool {
        guard JournalValidation.checkIn(note: note, day: day) else { error = "Use today or an earlier date, with a note of up to 500 characters."; return false }
        journal.save(CheckIn(day: day, mood: mood, appetite: appetite, routines: routines, note: note.trimmingCharacters(in: .whitespacesAndNewlines)))
        for accessory in Accessory.allCases where journal.checkIns.count >= accessory.requiredDays { journal.unlockedAccessories.insert(accessory) }
        guard persist() else { return false }
        return true
    }
    func addMilestone(title: String, note: String, kind: MilestoneKind, date: Date) -> Bool {
        guard JournalValidation.milestone(title: title, note: note), Calendar.current.startOfDay(for: date) <= Calendar.current.startOfDay(for: .now) else { error = "Add a title of up to 80 characters, a note of up to 300, and a date no later than today."; return false }
        journal.milestones.append(Milestone(date: date, title: title.trimmingCharacters(in: .whitespacesAndNewlines), note: note, kind: kind))
        guard persist() else { return false }; showToast("A moment worth keeping"); return true
    }
    func addWeight(value: Double, unit: WeightUnit, date: Date) -> Bool {
        let kg = unit.kilograms(value)
        guard JournalValidation.weight(kg), Calendar.current.startOfDay(for: date) <= Calendar.current.startOfDay(for: .now) else { error = "Enter a valid weight and a date no later than today."; return false }
        journal.save(WeightEntry(date: date, kilograms: kg))
        guard persist() else { return false }; showToast("Weight record saved"); return true
    }
    func removeCheckIn(_ id: UUID) { journal.checkIns.removeAll { $0.id == id }; persist() }
    func removeMilestone(_ id: UUID) { journal.milestones.removeAll { $0.id == id }; persist() }
    func removeWeight(_ id: UUID) { journal.weights.removeAll { $0.id == id }; persist() }
    func showToast(_ text: String) {
        toastTask?.cancel(); toast = text
        toastTask = Task { try? await Task.sleep(for: .seconds(2.5)); if !Task.isCancelled { toast = nil } }
    }
    var exportText: String {
        var lines = ["Along — local journal export", journal.hasSampleData ? "Contains fictional sample records mixed with any entries added in this prototype." : "Entries recorded on this device.", "Name: \(journal.name)", "Companion: \(companionName)", ""]
        for entry in journal.checkIns.sorted(by: { $0.day < $1.day }) {
            lines.append("\(entry.isSample ? "[SAMPLE] " : "")\(entry.day.formatted(date: .abbreviated, time: .omitted)) · \(entry.mood.title) · Appetite: \(entry.appetite.title)")
            lines.append(entry.routines.sorted { $0.rawValue < $1.rawValue }.map(\.title).joined(separator: "; "))
            if !entry.note.isEmpty { lines.append(entry.note) }; lines.append("")
        }
        for milestone in journal.milestones.sorted(by: { $0.date < $1.date }) { lines.append("\(milestone.isSample ? "[SAMPLE] " : "")Milestone · \(milestone.date.formatted(date: .abbreviated, time: .omitted)) · \(milestone.title)\n\(milestone.note)\n") }
        for entry in journal.weights.sorted(by: { $0.date < $1.date }) { lines.append("\(entry.isSample ? "[SAMPLE] " : "")Weight · \(entry.date.formatted(date: .abbreviated, time: .omitted)) · \(entry.kilograms.formatted(.number.precision(.fractionLength(1)))) kg") }
        return lines.joined(separator: "\n")
    }
    func clearJournal() {
        journal = Journal(); selectedTab = 0; canSave = true
        onboardingArchive = OnboardingArchive()
        loadingDraft = true; onboardingDraft = OnboardingDraft(); loadingDraft = false
        canSaveDraft = true
        do {
            if FileManager.default.fileExists(atPath: draftURL.path) { try FileManager.default.removeItem(at: draftURL) }
        } catch { self.error = "Your setup draft could not be removed. Please retry clearing local data." }
        clearCredentials()
        persist()
    }
    func loadSample() { let name = journal.name; let companion = companionName; journal = Journal.sample(); journal.name = name; journal.companionName = companion; journal.hasOnboarded = true; canSave = true; persist() }
    func startBlank() { let name = journal.name; let companion = companionName; let routines = journal.routines; journal = Journal(); journal.name = name; journal.companionName = companion; journal.routines = routines; journal.hasOnboarded = true; canSave = true; persist() }
}
