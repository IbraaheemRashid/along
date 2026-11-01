import SwiftUI
import Observation

@MainActor @Observable final class JournalStore {
    var journal = Journal()
    var selectedTab = 0
    var toast: String?
    var error: String?
    private let url: URL
    private var canSave = true
    private var toastTask: Task<Void, Never>?
    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Along", isDirectory: true)
        url = directory.appendingPathComponent("journal-v1.json")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: url.path) {
                journal = try JSONDecoder().decode(Journal.self, from: Data(contentsOf: url))
            }
        } catch { canSave = false; self.error = "We couldn’t open your local journal. Your existing file hasn’t been overwritten. You can retry by reopening the app." }
        if ProcessInfo.processInfo.arguments.contains("--reset-demo") { journal = Journal(); canSave = true; error = nil; persist() }
        if ProcessInfo.processInfo.arguments.contains("--sample-journey") {
            journal = Journal.sample(); journal.name = "Alex"; journal.hasOnboarded = true; canSave = true; error = nil; persist()
        }
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
        guard canSave else { error = "The existing journal could not be read. To protect it, saving is disabled. Reopen the app to retry, or explicitly reset local data in You."; return false }
        do {
            let data = try JSONEncoder().encode(journal)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            var resource = url
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try resource.setResourceValues(values)
            return true
        } catch { self.error = "Your changes couldn’t be saved on this device. Please try again before closing the app."; return false }
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
    func clearJournal() { journal = Journal(); selectedTab = 0; canSave = true; TokenVault.clear(); persist() }
    func loadSample() { let name = journal.name; let companion = companionName; journal = Journal.sample(); journal.name = name; journal.companionName = companion; journal.hasOnboarded = true; canSave = true; persist() }
    func startBlank() { let name = journal.name; let companion = companionName; let routines = journal.routines; journal = Journal(); journal.name = name; journal.companionName = companion; journal.routines = routines; journal.hasOnboarded = true; canSave = true; persist() }
}
