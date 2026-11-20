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
    var journalGeneration: UUID?
}

@MainActor @Observable final class JournalStore {
    var journal = Journal()
    var onboardingDraft = OnboardingDraft() {
        didSet { if !loadingDraft { saveOnboardingDraft() } }
    }
    var setup = SetupDraft() {
        didSet { if !loadingDraft && setup != oldValue { saveSetup() } }
    }
    var selectedTab = 0
    var referenceDate = Date.now
    var toast: String?
    var error: String?
    private static var writeOptions: Data.WritingOptions {
        #if os(iOS)
        [.atomic, .completeFileProtection]
        #else
        [.atomic] // macOS command-line checks do not support iOS file protection.
        #endif
    }
    private let url: URL
    private let draftURL: URL
    private let setupURL: URL
    private let clearCredentials: () -> Void
    private var canSave = true
    private var canSaveDraft = true
    private var loadingDraft = true
    private var onboardingArchive = OnboardingArchive()
    private var toastTask: Task<Void, Never>?
    private static func recoveredDraft(from journal: Journal) -> OnboardingDraft {
        var draft = journal.onboardingPreferences ?? OnboardingDraft()
        draft.step = journal.hasOnboarded ? 25 : 0
        draft.name = journal.name
        draft.companionName = journal.companionName
        draft.routines = journal.routines
        draft.showWeight = journal.showWeight
        draft.weightUnit = journal.weightUnit
        draft.weightValue = ""
        draft.accessory = journal.accessory
        draft.startDate = journal.startDate
        return draft
    }
    let startupArguments: [String]
    init(directory: URL? = nil, arguments: [String] = ProcessInfo.processInfo.arguments, clearCredentials: @escaping () -> Void = TokenVault.clear) {
        startupArguments = arguments
        var folder = "Along"
        #if DEBUG
        let isReviewSession = arguments.contains("--ui-testing") || arguments.contains("--onboarding-step") || arguments.contains("--review-onboarding") || arguments.contains("--setup-step")
        if isReviewSession { folder = "AlongDesignReview" }
        #endif
        let directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent(folder, isDirectory: true)
        url = directory.appendingPathComponent("journal-v1.json")
        draftURL = directory.appendingPathComponent("onboarding-draft-v1.json")
        setupURL = directory.appendingPathComponent("setup-v2.json")
        // Review storage must not share the real journal's credential lifecycle.
        // A reset during screenshots or design review never clears its session.
        #if DEBUG
        self.clearCredentials = isReviewSession ? {} : clearCredentials
        #else
        self.clearCredentials = clearCredentials
        #endif
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: url.path) {
                let data = try Data(contentsOf: url)
                guard data.count <= 8 * 1024 * 1024 else { throw CocoaError(.fileReadCorruptFile) }
                let loaded = try JSONDecoder().decode(Journal.self, from: data)
                guard loaded.version == 1, loaded.weights.allSatisfy({ JournalValidation.weight($0.kilograms) }) else { throw CocoaError(.fileReadCorruptFile) }
                journal = loaded
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
                if archive.journalGeneration == journal.restoreGeneration {
                    onboardingArchive = archive
                    onboardingDraft = archive.draft
                } else {
                    // A successful restore invalidates old ownership even if the
                    // app was interrupted before the draft could be rewritten.
                    let restoredDraft = Self.recoveredDraft(from: journal)
                    onboardingArchive = OnboardingArchive(draft: restoredDraft, journalGeneration: journal.restoreGeneration)
                    onboardingDraft = restoredDraft
                }
            } else if journal.restoreGeneration != nil {
                let restoredDraft = Self.recoveredDraft(from: journal)
                onboardingArchive = OnboardingArchive(draft: restoredDraft, journalGeneration: journal.restoreGeneration)
                onboardingDraft = restoredDraft
            }
        } catch {
            if journal.restoreGeneration != nil {
                let restoredDraft = Self.recoveredDraft(from: journal)
                onboardingArchive = OnboardingArchive(draft: restoredDraft, journalGeneration: journal.restoreGeneration)
                onboardingDraft = restoredDraft
                if self.error == nil { self.error = "Your setup draft couldn’t be opened. Your saved journal preferences have been recovered; your records are unchanged." }
            } else {
                canSaveDraft = false
                if self.error == nil { self.error = "Your setup draft couldn’t be opened. Your journal is unchanged. Restart setup to replace only the draft." }
            }
        }
        if let data = try? Data(contentsOf: setupURL), data.count <= 65536,
           let saved = try? JSONDecoder().decode(SetupDraft.self, from: data), saved.isValid {
            setup = saved
        } else if let profile = journal.setupProfile, profile.isValid {
            setup = profile
        }
        loadingDraft = false
        #if DEBUG
        if arguments.contains("--reset-demo") { clearJournal(); error = nil }
        if let index = arguments.firstIndex(of: "--setup-step"), arguments.indices.contains(index + 1), let step = SetupStep(rawValue: arguments[index + 1]) {
            journal.hasOnboarded = false; persist()
            setup = step == .welcome ? SetupDraft() : SetupDraft.example(at: step)
        }
        if arguments.contains("--setup-complete") {
            clearJournal(); setup = SetupDraft.example(at: .paywall); finishSetupPreview(); error = nil
        }
        if arguments.contains("--sample-journey") {
            journal = Journal.sample(); journal.name = "Alex"; journal.hasOnboarded = true; journal.isDesignPreview = true; canSave = true; error = nil; persist()
        }
        if isReviewSession, let index = arguments.firstIndex(of: "--pip-preview-days"), arguments.indices.contains(index + 1), let days = Int(arguments[index + 1]) {
            journal.reconcileProgress()
            journal.pipProgress = .preview(days: days)
            journal.reconcileProgress(); persist()
        }
        if arguments.contains("--review-onboarding") { journal.hasOnboarded = false; persist() }
        #endif
        if canSave {
            var migrated = journal
            migrated.reconcileProgress()
            if migrated != journal, persist(migrated) { journal = migrated }
        }
    }
    var today: CheckIn? { journal.checkIn(on: referenceDate) }
    var onboardingEntry: CheckIn? {
        guard let id = onboardingArchive.entryID else { return nil }
        return journal.checkIns.first { $0.id == id }
    }
    #if DEBUG
    var developmentStorageDirectory: URL { url.deletingLastPathComponent() }
    #endif
    var week: [CheckIn] { journal.week(ending: referenceDate) }
    var weekRecordedDays: Int {
        (0..<7).filter { offset in
            let day = Calendar.current.date(byAdding: .day, value: -offset, to: referenceDate)!
            return week.contains { $0.isOn(day) } || !journal.recordedRoutines(on: day).isEmpty
        }.count
    }
    var routineCount: Int {
        (0..<7).reduce(0) { total, offset in
            let day = Calendar.current.date(byAdding: .day, value: -offset, to: referenceDate)!
            return total + journal.recordedRoutines(on: day).count
        }
    }
    var weeklyMilestones: [Milestone] {
        guard let range = DayIdentity.range(ending: referenceDate) else { return [] }
        return journal.milestones.filter { $0.dateKey.map { range.contains($0) } ?? false }.sorted { $0.displayDate > $1.displayDate }
    }
    var companionName: String { journal.companionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Pip" : journal.companionName }
    var daysTogether: Int { max(1, (Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: journal.startDate), to: Calendar.current.startOfDay(for: referenceDate)).day ?? 0) + 1) }
    var recap: String {
        if weekRecordedDays == 0 { return "Your story starts with a moment. Check in whenever it feels useful, and your recorded moments will appear here." }
        let noun = weekRecordedDays == 1 ? "day" : "days"
        let moments = routineCount == 1 ? "routine moment" : "routine moments"
        return "You kept a record on \(weekRecordedDays) \(noun), including \(week.count) \(week.count == 1 ? "check-in" : "check-ins") and \(routineCount) \(moments) in the last seven days. Every entry is a little piece of your story. Days without entries simply aren’t recorded."
    }
    @discardableResult func persist() -> Bool {
        persist(journal)
    }
    /// Publish state only after the entire replacement file has been written.
    @discardableResult func updateJournal(_ change: (inout Journal) -> Void) -> Bool {
        var candidate = journal
        change(&candidate)
        candidate.reconcileProgress()
        guard persist(candidate) else { return false }
        journal = candidate
        return true
    }
    @discardableResult func claimReward(_ reward: PipReward) -> Bool {
        guard journal.availableRewards.contains(reward) else { return false }
        return updateJournal { value in
            value.pipProgress?.claimedRewards.insert(reward)
            if let accessory = reward.accessory { value.accessory = accessory }
        }
    }
    @discardableResult func wearAccessory(_ accessory: Accessory) -> Bool {
        guard journal.canUse(accessory) else { return false }
        return updateJournal { $0.accessory = accessory }
    }
    @discardableResult func toggleRoutine(_ routine: Routine, on day: Date = .now) -> Bool {
        guard journal.routines.contains(routine), JournalValidation.checkIn(note: "", day: day) else { return false }
        return updateJournal { $0.toggleRoutine(routine, on: day) }
    }
    @discardableResult func rememberPipStory(_ story: PipStory, choice: String) -> Bool {
        var candidate = journal
        guard candidate.remember(story, choice: choice), persist(candidate) else { return false }
        journal = candidate
        return true
    }
    private func persist(_ value: Journal) -> Bool {
        guard canSave else { error = "The existing journal could not be read. To protect it, saving is disabled. Reopen the app to retry, or explicitly reset local data in You."; return false }
        do {
            let data = try JSONEncoder().encode(value)
            guard data.count <= 8 * 1024 * 1024 else { throw CocoaError(.fileWriteUnknown) }
            var resource = url.deletingLastPathComponent()
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try resource.setResourceValues(values)
            try data.write(to: url, options: Self.writeOptions)
            return true
        } catch { self.error = "Your changes couldn’t be saved on this device. Please try again before closing the app."; return false }
    }
    @discardableResult func saveOnboardingDraft() -> Bool {
        guard canSaveDraft else { error = "Your existing setup draft is protected. Restart setup to replace the draft; your journal will be kept."; return false }
        guard onboardingDraft.isValidForPersistence else { error = "Check the length of your setup answers before continuing."; return false }
        do {
            onboardingArchive.draft = onboardingDraft
            onboardingArchive.journalGeneration = journal.restoreGeneration
            let data = try JSONEncoder().encode(onboardingArchive)
            var resource = draftURL.deletingLastPathComponent()
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try resource.setResourceValues(values)
            try data.write(to: draftURL, options: Self.writeOptions)
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
        let ownedEntry = candidate.checkIns.first { $0.id == onboardingArchive.entryID }
        let validDate = ownedEntry.map { JournalValidation.storedRecordDate($0.day, key: $0.dayKey, now: now) } ?? JournalValidation.recordDate(day, now: now, calendar: calendar)
        guard JournalValidation.text(onboardingDraft.note, limit: 500), validDate else { error = "Check the date and note before saving your first entry."; return false }
        if onboardingArchive.entryID == nil {
            if let existing = candidate.checkIns.first(where: { $0.isOn(day, calendar: calendar) && !$0.isSample }) {
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
            let old = candidate.checkIns.first { $0.id == id }
            let existingRoutines = old?.routines ?? candidate.recordedRoutines(on: date, calendar: calendar)
            let entry = CheckIn(id: id, day: date, mood: mood, appetite: appetite, routines: existingRoutines, note: onboardingDraft.note.trimmingCharacters(in: .whitespacesAndNewlines), isSample: old?.isSample ?? false, dayKey: old?.dayKey ?? DayIdentity.key(for: date, timeZone: calendar.timeZone))
            if let index = candidate.checkIns.firstIndex(where: { $0.id == id }) { candidate.checkIns[index] = entry }
            else {
                // Keep unrelated real records, even if added since this draft.
                if !candidate.checkIns.contains(where: { $0.isOn(date, calendar: calendar) && !$0.isSample }) {
                    candidate.checkIns.removeAll { $0.isSample && $0.isOn(date, calendar: calendar) }
                    candidate.routineDays?.removeAll { $0.isOn(date, calendar: calendar) }
                    candidate.checkIns.append(entry)
                }
            }
        }
        if let kilograms = onboardingDraft.baselineKilograms, let date = onboardingArchive.entryDate {
            let entryKey = candidate.checkIns.first(where: { $0.id == onboardingArchive.entryID })?.dayKey
            let recordDay = entryKey.flatMap { DayIdentity.date(for: $0, timeZone: calendar.timeZone) } ?? date
            if onboardingArchive.weightID == nil {
                if let existing = candidate.weights.first(where: { $0.isOn(recordDay, calendar: calendar) && !$0.isSample }) {
                    onboardingArchive.weightID = existing.id; onboardingArchive.ownsWeight = false
                } else { onboardingArchive.weightID = UUID(); onboardingArchive.ownsWeight = true }
            }
            if onboardingArchive.ownsWeight, let id = onboardingArchive.weightID {
                let old = candidate.weights.first { $0.id == id }
                let weight = WeightEntry(id: id, date: old?.date ?? date, kilograms: kilograms, isSample: old?.isSample ?? false, dateKey: old?.dateKey ?? entryKey ?? DayIdentity.key(for: date, timeZone: calendar.timeZone))
                if let index = candidate.weights.firstIndex(where: { $0.id == id }) { candidate.weights[index] = weight }
                else if !candidate.weights.contains(where: { $0.isOn(recordDay, calendar: calendar) && !$0.isSample }) {
                    candidate.weights.removeAll { $0.isSample && $0.isOn(recordDay, calendar: calendar) }
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
        candidate.reconcileProgress(now: now)
        // The chosen look remains a starter gift even when setup is revisited.
        for reward in PipReward.allCases where reward.accessory == onboardingDraft.accessory {
            candidate.pipProgress?.claimedRewards.insert(reward)
        }
        // Save the identity/date envelope first, so a retry after interruption or
        // a different calendar day cannot manufacture another first entry.
        guard saveOnboardingDraft(), persist(candidate) else { return false }
        journal = candidate
        return true
    }
    @discardableResult func saveSetup() -> Bool {
        guard setup.isValid else { return false }
        do {
            let data = try JSONEncoder().encode(setup)
            var resource = setupURL.deletingLastPathComponent()
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try resource.setResourceValues(values)
            try data.write(to: setupURL, options: Self.writeOptions)
            return true
        } catch { self.error = "Your setup couldn’t be saved on this device. Please try again before closing the app."; return false }
    }
    /// Copies setup answers into the journal: the profile, display unit, the
    /// chosen peptides as a starting protocol and, for
    /// weight goals, a starting weight for today unless a real record exists.
    private func journalAfterSetup(now: Date = .now, calendar: Calendar = .current) -> Journal? {
        guard setup.isValid, setup.isAdult(now: now) else {
            error = "Some setup answers need another look before continuing. Your journal is unchanged."; return nil
        }
        var candidate = journal
        candidate.setupProfile = setup
        candidate.weightUnit = setup.weightUnit
        if let today = DayIdentity.key(for: now, timeZone: calendar.timeZone) {
            candidate.adoptSetupPeptides(setup.initialPeptides(startKey: today))
        }
        guard setup.tracksWeightGoal else { return candidate }
        candidate.showWeight = true
        if !candidate.weights.contains(where: { $0.isOn(now, calendar: calendar) && !$0.isSample }) {
            candidate.weights.removeAll { $0.isSample && $0.isOn(now, calendar: calendar) }
            candidate.save(WeightEntry(date: now, kilograms: setup.weightKg), calendar: calendar)
        }
        return candidate
    }
    @discardableResult func finishSetup(now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard var candidate = journalAfterSetup(now: now, calendar: calendar) else { return false }
        candidate.hasOnboarded = true; candidate.isDesignPreview = false
        candidate.reconcileProgress(now: now)
        guard persist(candidate) else { return false }
        journal = candidate
        return true
    }
    @discardableResult func finishSetupPreview(now: Date = .now) -> Bool {
        #if DEBUG
        guard var candidate = journalAfterSetup(now: now) else { return false }
        candidate.hasOnboarded = true; candidate.isDesignPreview = true
        candidate.reconcileProgress(now: now)
        guard persist(candidate) else { return false }
        journal = candidate
        return true
        #else
        error = "Design preview access is only available in a development build. No subscription has been activated."
        return false
        #endif
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
    /// Completion is only a setup flag. RootView independently requires a
    /// verified BillingStore entitlement for access in every Release build.
    @discardableResult func finishPaidOnboarding() -> Bool {
        guard saveOnboardingEntry() else { return false }
        return updateJournal { $0.hasOnboarded = true; $0.isDesignPreview = false }
    }
    @discardableResult func restoreJournal(_ replacement: Journal) -> Bool {
        do { _ = try JournalBackup.make(from: replacement) }
        catch { self.error = "This backup could not be validated. Your existing journal is unchanged."; return false }
        var candidate = replacement
        candidate.hasOnboarded = journal.hasOnboarded
        candidate.isDesignPreview = journal.isDesignPreview
        candidate.restoreGeneration = UUID()
        let couldSave = canSave
        canSave = true // Only an explicitly confirmed, validated restore can replace an unreadable journal.
        guard updateJournal({ $0 = candidate }) else { canSave = couldSave; return false }
        let draft = Self.recoveredDraft(from: candidate)
        onboardingArchive = OnboardingArchive(draft: draft, journalGeneration: candidate.restoreGeneration)
        loadingDraft = true; onboardingDraft = draft; loadingDraft = false
        canSaveDraft = true
        _ = saveOnboardingDraft()
        return true
    }
    func resetOnboarding() {
        guard canSave else { error = "Your existing journal is protected. Reopen the app to retry before restarting setup."; return }
        var candidate = journal
        candidate.hasOnboarded = false
        guard persist(candidate) else { return }
        journal = candidate
        onboardingArchive = OnboardingArchive()
        loadingDraft = true; onboardingDraft = OnboardingDraft(); setup = SetupDraft(); loadingDraft = false
        canSaveDraft = true
        selectedTab = 0
        saveOnboardingDraft(); saveSetup()
    }
    func saveCheckIn(day: Date, mood: Mood, appetite: Appetite, routines: Set<Routine>, note: String, editing id: UUID? = nil) -> Bool {
        let old = journal.checkIns.first { $0.id == id }
        if id != nil && old == nil { error = "This check-in is no longer in your journal."; return false }
        let validDate = old.map { JournalValidation.storedRecordDate($0.day, key: $0.dayKey) } ?? JournalValidation.recordDate(day)
        guard JournalValidation.text(note, limit: 500), validDate else { error = "Use a supported date, with a note of up to 500 characters."; return false }
        return updateJournal { $0.save(CheckIn(id: old?.id ?? UUID(), day: old?.day ?? day, mood: mood, appetite: appetite, routines: routines, note: note.trimmingCharacters(in: .whitespacesAndNewlines), isSample: old?.isSample ?? false, dayKey: old?.dayKey)) }
    }
    func addMilestone(title: String, note: String, kind: MilestoneKind, date: Date, editing id: UUID? = nil) -> Bool {
        let old = journal.milestones.first { $0.id == id }
        if id != nil && old == nil { error = "This milestone is no longer in your journal."; return false }
        let unchangedDate = old.map { $0.isOn(date) || $0.displayDate == date } ?? false
        let validDate = unchangedDate ? JournalValidation.storedRecordDate(old!.date, key: old!.dateKey) : JournalValidation.recordDate(date)
        guard JournalValidation.milestone(title: title, note: note), validDate else { error = "Add a title of up to 80 characters, a note of up to 300, and a supported date no later than today."; return false }
        guard updateJournal({ value in
            let item = Milestone(id: old?.id ?? UUID(), date: unchangedDate ? old!.date : date, title: title.trimmingCharacters(in: .whitespacesAndNewlines), note: note, kind: kind, isSample: old?.isSample ?? false, dateKey: unchangedDate ? old!.dateKey : DayIdentity.key(for: date))
            if let index = value.milestones.firstIndex(where: { $0.id == id }) { value.milestones[index] = item }
            else { value.milestones.append(item) }
        }) else { return false }
        showToast("A moment worth keeping"); return true
    }
    func addWeight(value: Double, unit: WeightUnit, date: Date, editing id: UUID? = nil) -> Bool {
        let kg = unit.kilograms(value)
        let old = journal.weights.first { $0.id == id }
        if id != nil && old == nil { error = "This weight record is no longer in your journal."; return false }
        let validDate = old.map { JournalValidation.storedRecordDate($0.date, key: $0.dateKey) } ?? JournalValidation.recordDate(date)
        guard JournalValidation.weight(kg), validDate else { error = "Enter a valid weight and a supported date."; return false }
        guard updateJournal({ $0.save(WeightEntry(id: old?.id ?? UUID(), date: old?.date ?? date, kilograms: kg, isSample: old?.isSample ?? false, dateKey: old?.dateKey)); $0.showWeight = true }) else { return false }
        showToast("Weight record saved"); return true
    }
    func removeCheckIn(_ id: UUID) { updateJournal { $0.checkIns.removeAll { $0.id == id } } }
    func removeMilestone(_ id: UUID) { updateJournal { $0.milestones.removeAll { $0.id == id } } }
    func removeWeight(_ id: UUID) { updateJournal { $0.weights.removeAll { $0.id == id } } }
    func removeRoutineDay(_ id: UUID) { updateJournal { $0.routineDays?.removeAll { $0.id == id } } }
    @discardableResult func saveRoutineDay(_ id: UUID, routines: Set<Routine>) -> Bool {
        guard let index = journal.routineDays?.firstIndex(where: { $0.id == id }) else { error = "This record is no longer in your journal."; return false }
        return updateJournal { $0.routineDays?[index].routines = routines }
    }
    func showToast(_ text: String) {
        toastTask?.cancel(); toast = text
        toastTask = Task { try? await Task.sleep(for: .seconds(2.5)); if !Task.isCancelled { toast = nil } }
    }
    var exportText: String {
        var lines = ["Along — local protocol export",
                     journal.hasSampleData ? "Contains fictional sample records mixed with any entries added in this prototype." : "Records saved on this device.",
                     "Name: \(journal.name)", ""]
        for peptide in journal.protocolPeptides {
            lines.append("\(peptide.isSample ? "[SAMPLE] " : "")Peptide · \(peptide.name) · \(peptide.amountText ?? "dose not set") · \(peptide.schedule.summary) · \(peptide.schedule.timesSummary)\(peptide.isPaused ? " · paused" : "")")
            if !peptide.note.isEmpty { lines.append(peptide.note) }
        }
        lines.append("")
        for log in journal.protocolLogs.sorted(by: { $0.takenAt < $1.takenAt }) {
            let name = peptide(log.peptideID)?.name ?? "Peptide"
            let amount = log.amountText ?? ""
            let site = log.site?.shortTitle ?? ""
            lines.append("\(log.isSample ? "[SAMPLE] " : "")Dose · \(log.dayKey) · \(name) · \(log.status.rawValue)\(amount.isEmpty ? "" : " · \(amount)")\(site.isEmpty ? "" : " · \(site)")")
            if !log.note.isEmpty { lines.append(log.note) }
        }
        lines.append("")
        for entry in journal.weights.sorted(by: { $0.displayDate < $1.displayDate }) {
            lines.append("\(entry.isSample ? "[SAMPLE] " : "")Weight · \(entry.dateText()) · \(entry.kilograms.formatted(.number.precision(.fractionLength(1)))) kg")
        }
        // Legacy companion discoveries from the retired Pip journal remain exportable.
        for story in PipStory.all {
            if let answer = journal.companionDiscoveries?[story.id], let choice = story.choices.first(where: { $0.id == answer }) {
                lines.append("Fictional companion discovery · \(choice.discovery)")
            }
        }
        return lines.joined(separator: "\n")
    }
    @discardableResult func clearJournal() -> Bool {
        let couldSave = canSave
        canSave = true // This path is only invoked by explicit reset confirmation.
        var blank = Journal()
        blank.restoreGeneration = UUID()
        guard persist(blank) else { canSave = couldSave; return false }
        journal = blank; selectedTab = 0
        onboardingArchive = OnboardingArchive(journalGeneration: blank.restoreGeneration)
        loadingDraft = true; onboardingDraft = OnboardingDraft(); setup = SetupDraft(); loadingDraft = false
        canSaveDraft = true
        clearCredentials()
        do {
            if FileManager.default.fileExists(atPath: draftURL.path) { try FileManager.default.removeItem(at: draftURL) }
            if FileManager.default.fileExists(atPath: setupURL.path) { try FileManager.default.removeItem(at: setupURL) }
        } catch { self.error = "Your journal was cleared, but your setup draft could not be removed. Please retry clearing local data."; return false }
        return true
    }
    #if DEBUG
    func loadSample() {
        var candidate = Journal()
        candidate.name = journal.name
        candidate.hasOnboarded = true
        candidate.isDesignPreview = true
        candidate.showWeight = true
        candidate.addSampleProtocol()
        guard persist(candidate) else { return }; journal = candidate
    }
    func startBlank() {
        var candidate = Journal()
        candidate.name = journal.name
        candidate.hasOnboarded = true
        candidate.isDesignPreview = true
        guard persist(candidate) else { return }; journal = candidate
    }
    #endif
}
