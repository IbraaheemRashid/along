import Foundation

@main struct CoreTests {
    @MainActor static func main() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2026-11-01T12:00:00Z")!
        var checks = 0
        func expect(_ condition: Bool, _ name: String) { precondition(condition, name); checks += 1 }
        var journal = Journal()
        let first = CheckIn(day: now, mood: .steady, appetite: .comfortable, routines: [.nutrition], note: "Original")
        journal.save(first, calendar: calendar)
        journal.save(CheckIn(day: now.addingTimeInterval(3600), mood: .tough, appetite: .low, routines: [], note: "Edited"), calendar: calendar)
        expect(journal.checkIns.count == 1, "A day must not award duplicate check-ins")
        expect(journal.checkIns[0].id == first.id, "Edits preserve identity")
        expect(journal.checkIns[0].note == "Edited" && journal.checkIns[0].routines.isEmpty, "Editing can clear previous routines")
        for offset in [-7, -6, -1, 1] { journal.save(CheckIn(day: calendar.date(byAdding: .day, value: offset, to: now)!, mood: .steady, appetite: .comfortable, routines: [], note: ""), calendar: calendar) }
        expect(journal.week(ending: now, calendar: calendar).count == 3, "Week includes six prior days and today, excludes previous week and future")
        expect(!JournalValidation.checkIn(note: "", day: now.addingTimeInterval(86400), now: now, calendar: calendar), "Future check-ins are rejected")
        expect(!JournalValidation.checkIn(note: String(repeating: "a", count: 501), day: now, now: now), "Oversized journal note rejected")
        expect(JournalValidation.checkIn(note: "", day: now, now: now), "Notes and routines can be skipped")
        expect(abs(WeightUnit.lb.kilograms(WeightUnit.lb.display(94.2)) - 94.2) < 0.000001, "Units round trip without stored-data drift")
        expect(!JournalValidation.weight(.nan) && !JournalValidation.weight(.infinity) && !JournalValidation.weight(-2), "Invalid numeric weights rejected")
        expect(JournalValidation.weight(80.5), "Valid weight accepted")
        let weight = WeightEntry(date: now, kilograms: 81)
        journal.save(weight, calendar: calendar); journal.save(WeightEntry(date: now, kilograms: 80), calendar: calendar)
        expect(journal.weights.count == 1 && journal.weights[0].id == weight.id && journal.weights[0].kilograms == 80, "Daily weight upsert is stable")
        expect(!journal.canUse(.scarf), "Weight changes do not unlock rewards")
        journal.unlockedAccessories.insert(.scarf); journal.checkIns.removeAll()
        expect(journal.canUse(.scarf), "Deleting entries never takes away an earned keepsake")
        expect(!JournalValidation.milestone(title: "   ", note: ""), "Blank milestone rejected")
        expect(!JournalValidation.milestone(title: "A day", note: String(repeating: "x", count: 301)), "Oversized milestone note rejected")
        let sample = Journal.sample(now: now, calendar: calendar)
        expect(sample.hasSampleData && sample.checkIns.count == 8 && sample.milestones.count == 3, "Sample history is clearly identified")
        expect(sample.week(ending: now, calendar: calendar).count == 4, "Sample weekly recap counts actual records")
        expect(sample.checkIns.allSatisfy { !calendar.isDate($0.day, inSameDayAs: now) }, "Demo begins with today available for user's first action")
        expect(sample.checkIns.allSatisfy(\.isSample) && sample.milestones.allSatisfy(\.isSample) && sample.weights.allSatisfy(\.isSample), "Sample provenance survives mixed user/demo history")
        var editedSample = sample
        editedSample.save(CheckIn(day: sample.checkIns[0].day, mood: .bright, appetite: .hungry, routines: [], note: "Updated"), calendar: calendar)
        expect(editedSample.checkIns[0].isSample, "Editing a fictional example doesn't silently turn it into genuine history")
        let data = try JSONEncoder().encode(sample)
        expect(try JSONDecoder().decode(Journal.self, from: data) == sample, "Journal survives persistence round trip")

        let legacy = try JSONDecoder().decode(Journal.self, from: data)
        expect(legacy.onboardingPreferences == nil && legacy.isDesignPreview == nil, "Legacy journals decode without the optional onboarding fields")
        expect(OnboardingDraft.totalSteps == 26 && OnboardingPlan.allCases.map(\.rawValue) == ["annual", "monthly"], "Setup has 26 screens and only direct paid plan choices")
        var draft = OnboardingDraft()
        expect(draft.step == 0 && draft.frequency == "Flexible" && draft.reminder == "Off" && draft.displayCompanionName == "Pip", "Optional routine and reminder defaults are usable")
        expect(!draft.canContinue(at: -1) && !draft.canContinue(at: 26), "Step validation rejects out-of-range indices")
        expect(!draft.canContinue(at: 2) && !draft.canContinue(at: 4) && !draft.canContinue(at: 5), "Required journey choices cannot be skipped accidentally")
        expect(!draft.canContinue(at: 7), "Progress preview needs at least one chosen area")
        draft.progressAreas = ["Energy", "Comfort", "Confidence", "Strength"]
        expect(!draft.canContinue(at: 7), "At most three progress areas are allowed")
        draft.routines = Set(Routine.allCases)
        expect(!draft.canContinue(at: 12), "At most two optional routines are allowed")
        draft.routines = []
        expect(draft.canContinue(at: 12), "Choosing no routine remains valid")
        draft.routineNames = ["movement": ""]
        expect(!draft.canContinue(at: 13) && draft.isValidForPersistence == false, "Empty wording cannot advance while another oversized choice still invalidates this draft")
        draft.progressAreas = ["Energy"]
        expect(draft.isValidForPersistence, "An in-progress empty routine label can still be resumed")
        draft.routineNames = ["unknown": "My routine"]
        expect(!draft.canContinue(at: 13), "Routine names must use actual routine keys")
        draft.routineNames = [:]
        draft.companionName = "   "
        expect(draft.displayCompanionName == "Pip" && draft.canContinue(at: 19), "A blank optional companion name uses Pip")
        draft.name = String(repeating: "x", count: 31)
        expect(!draft.canContinue(at: 1), "Preferred name has a bounded length")
        draft.name = ""
        draft.showWeight = true
        expect(draft.baselineKilograms == nil && draft.canContinue(at: 10), "Opting into weight never forces a first measurement")
        for text in ["nan", "inf", "-1", "0", "1,234.5", "80kg", "8e1", "501"] {
            draft.weightValue = text
            expect(draft.baselineKilograms == nil && !draft.canContinue(at: 10), "Invalid baseline weight rejected: \(text)")
        }
        draft.weightValue = "80,5"
        expect(draft.baselineKilograms == 80.5, "A decimal comma is supported without ambiguous grouping")
        draft.weightUnit = .lb; draft.weightValue = "176.369809748"
        expect(abs((draft.baselineKilograms ?? 0) - 80) < 0.000001, "Optional pounds are stored as kilograms")
        draft.hasStartDate = true; draft.startDate = Date().addingTimeInterval(172800)
        expect(!draft.canContinue(at: 3), "Selected treatment start date cannot be in the future")
        draft.hasStartDate = false
        expect(draft.canContinue(at: 3), "Unknown start date is valid without inventing treatment context")
        draft.mood = .steady
        expect(!draft.canContinue(at: 20), "Mood alone does not complete the real first check-in")
        draft.appetite = .comfortable
        expect(draft.canContinue(at: 20), "Mood and appetite complete the required first check-in")
        draft.note = String(repeating: "x", count: 501)
        expect(!draft.canContinue(at: 21), "First moment shares the 500-character journal limit")
        expect(try JSONDecoder().decode(OnboardingDraft.self, from: JSONEncoder().encode(draft)) == draft, "Draft contract is Codable and Equatable")

        func readyDraft() -> OnboardingDraft {
            var value = OnboardingDraft()
            value.name = "Ada"; value.stage = "Recently started"; value.priority = "Keep a clear record"
            value.obstacle = "Remembering details"; value.progressAreas = ["Energy", "Confidence"]
            value.routines = [.movement]; value.routineNames = ["movement": "A walk when it suits me"]
            value.mood = .steady; value.appetite = .comfortable; value.note = "A real first moment."
            value.step = 22; value.accessory = .flower
            return value
        }
        let testRoot = FileManager.default.temporaryDirectory.appendingPathComponent("along-onboarding-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: testRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: testRoot) }
        let storeDirectory = testRoot.appendingPathComponent("round-trip", isDirectory: true)
        let store = JournalStore(directory: storeDirectory, arguments: [], clearCredentials: {})
        store.onboardingDraft = readyDraft()
        expect(store.onboardingEntry == nil, "Draft-only examples are not presented as persisted journal entries")
        store.onboardingDraft.step = 4
        store.onboardingDraft.name = "Ada B"
        let resumed = JournalStore(directory: storeDirectory, arguments: [], clearCredentials: {})
        expect(resumed.onboardingDraft == store.onboardingDraft && resumed.onboardingDraft.step == 4, "Back navigation and answer edits autosave and resume exactly")
        resumed.onboardingDraft.step = 22
        let entryTime = Date()
        expect(resumed.saveOnboardingEntry(now: entryTime), "First real entry persists")
        expect(resumed.journal.checkIns.count == 1 && !resumed.journal.checkIns[0].isSample && !resumed.journal.hasOnboarded, "Saving a first entry does not grant app access or create sample history")
        expect(resumed.onboardingEntry == resumed.journal.checkIns[0], "The onboarding card can read the actual persisted check-in")
        expect(resumed.journal.checkIns[0].routines.isEmpty, "Choosing future routines does not claim they were already completed")
        expect(resumed.journal.weights.isEmpty && resumed.journal.onboardingPreferences != nil, "An omitted baseline creates no fabricated weight")
        expect(resumed.journal.canUse(.flower), "The chosen starter accessory is actually available")
        let firstEntryID = resumed.journal.checkIns[0].id
        let originalEntryDay = resumed.journal.checkIns[0].day
        resumed.onboardingDraft.showWeight = true; resumed.onboardingDraft.weightValue = "80.5"
        expect(resumed.saveOnboardingEntry(now: entryTime), "An optional baseline can be added when going back")
        let firstWeightID = resumed.journal.weights[0].id
        let nextDayStore = JournalStore(directory: storeDirectory, arguments: [], clearCredentials: {})
        nextDayStore.onboardingDraft.note = "Added a little more."
        nextDayStore.onboardingDraft.weightValue = "80.2"
        expect(nextDayStore.saveOnboardingEntry(now: entryTime.addingTimeInterval(86400)), "A resumed first entry can be edited after midnight")
        expect(nextDayStore.journal.checkIns.count == 1 && nextDayStore.journal.checkIns[0].id == firstEntryID && nextDayStore.journal.checkIns[0].day == originalEntryDay, "Repeated entry saves preserve both identity and original date")
        expect(nextDayStore.onboardingEntry?.id == firstEntryID && nextDayStore.onboardingEntry?.day == originalEntryDay && nextDayStore.onboardingEntry?.note == "Added a little more.", "Resumed cards receive the saved entry and its original date instead of today's draft label")
        expect(nextDayStore.journal.weights.count == 1 && nextDayStore.journal.weights[0].id == firstWeightID && nextDayStore.journal.weights[0].kilograms == 80.2, "Baseline edits are idempotent")
        nextDayStore.onboardingDraft.showWeight = false
        expect(nextDayStore.saveOnboardingEntry(now: entryTime.addingTimeInterval(86400)) && nextDayStore.journal.weights.isEmpty, "Skipping removes only the baseline created by this setup")
        #if DEBUG
        expect(nextDayStore.finishOnboardingPreview() && nextDayStore.journal.hasOnboarded && nextDayStore.journal.isDesignPreview == true, "Development access is explicitly marked as a design preview")
        #else
        expect(!nextDayStore.finishOnboardingPreview() && !nextDayStore.journal.hasOnboarded, "Release builds cannot open a design-preview access bypass")
        #endif
        let beforeReview = nextDayStore.journal
        nextDayStore.resetOnboarding()
        expect(!nextDayStore.journal.hasOnboarded && nextDayStore.onboardingDraft.step == 0 && nextDayStore.journal.checkIns == beforeReview.checkIns, "Reviewing setup keeps the existing journal records")
        nextDayStore.clearJournal()
        expect(nextDayStore.journal.checkIns.isEmpty && !FileManager.default.fileExists(atPath: storeDirectory.appendingPathComponent("onboarding-draft-v1.json").path), "Explicitly clearing local data also removes the setup draft")

        let legacyDirectory = testRoot.appendingPathComponent("legacy", isDirectory: true)
        try FileManager.default.createDirectory(at: legacyDirectory, withIntermediateDirectories: true)
        var existing = Journal()
        existing.hasOnboarded = true
        existing.save(CheckIn(day: entryTime, mood: .bright, appetite: .hungry, routines: [.nutrition], note: "Do not overwrite this recorded day."))
        existing.save(WeightEntry(date: entryTime, kilograms: 91))
        existing.milestones = [Milestone(date: entryTime, title: "My existing moment", note: "Keep it", kind: .other)]
        let journalURL = legacyDirectory.appendingPathComponent("journal-v1.json")
        try JSONEncoder().encode(existing).write(to: journalURL)
        let existingStore = JournalStore(directory: legacyDirectory, arguments: [], clearCredentials: {})
        existingStore.onboardingDraft = readyDraft()
        existingStore.onboardingDraft.showWeight = true; existingStore.onboardingDraft.weightValue = "75"
        expect(existingStore.saveOnboardingEntry(now: entryTime), "A legacy journal can acquire optional onboarding preferences")
        expect(existingStore.journal.checkIns == existing.checkIns && existingStore.journal.weights == existing.weights && existingStore.journal.milestones == existing.milestones, "Setup never overwrites unrelated existing history or same-day measurements")
        expect(existingStore.onboardingEntry == existing.checkIns[0], "When an existing day is preserved, the card gets that actual record rather than unsaved draft answers")
        let savedJournal = try Data(contentsOf: journalURL)
        let corruptDraftURL = legacyDirectory.appendingPathComponent("onboarding-draft-v1.json")
        try Data("{broken draft".utf8).write(to: corruptDraftURL)
        let protected = JournalStore(directory: legacyDirectory, arguments: [], clearCredentials: {})
        expect(protected.journal.checkIns == existing.checkIns && protected.error != nil, "A malformed draft does not prevent loading the journal")
        protected.onboardingDraft = readyDraft()
        let refusedCorruptDraft = !protected.saveOnboardingEntry(now: entryTime)
        let unchangedJournalData = try Data(contentsOf: journalURL)
        expect(refusedCorruptDraft && unchangedJournalData == savedJournal, "Unreadable draft state cannot silently overwrite a healthy journal")
        protected.resetOnboarding()
        expect(protected.journal.checkIns == existing.checkIns && protected.saveOnboardingDraft(), "Explicitly restarting setup recovers the draft while preserving journal records")
        #if DEBUG
        for flag in ["--ui-testing", "--onboarding-step", "--review-onboarding"] {
            var credentialClears = 0
            let directory = testRoot.appendingPathComponent("credential-isolation-\(flag)", isDirectory: true)
            let reviewStore = JournalStore(directory: directory, arguments: [flag, "0", "--reset-demo"], clearCredentials: { credentialClears += 1 })
            expect(credentialClears == 0, "\(flag) startup reset does not clear the normal keychain session")
            reviewStore.clearJournal()
            expect(credentialClears == 0, "\(flag) explicit review-data deletion remains isolated from the normal keychain")
        }
        #endif
        var ordinaryCredentialClears = 0
        let ordinaryStore = JournalStore(directory: testRoot.appendingPathComponent("ordinary-clear", isDirectory: true), arguments: [], clearCredentials: { ordinaryCredentialClears += 1 })
        expect(ordinaryCredentialClears == 0, "Opening a normal journal does not clear credentials")
        ordinaryStore.clearJournal()
        expect(ordinaryCredentialClears == 1, "Explicitly deleting normal local data still clears its own credentials once")
        let petDirectory = testRoot.appendingPathComponent("pet-stories", isDirectory: true)
        let petStore = JournalStore(directory: petDirectory, arguments: [], clearCredentials: {})
        let beforePetStory = petStore.journal
        expect(legacy.companionDiscoveries == nil, "Old journals decode without pet discoveries")
        expect(!petStore.rememberPipStory(PipStory.all[0], choice: "invalid"), "Unknown story choices are rejected")
        expect(petStore.rememberPipStory(PipStory.all[0], choice: "rain"), "A chosen fictional discovery persists")
        let petReload = JournalStore(directory: petDirectory, arguments: [], clearCredentials: {})
        expect(petReload.journal.companionDiscoveries?["window"] == "rain", "Pet discovery survives store restart")
        expect(petReload.journal.checkIns == beforePetStory.checkIns && petReload.journal.weights == beforePetStory.weights && petReload.journal.unlockedAccessories == beforePetStory.unlockedAccessories && !petReload.journal.hasOnboarded, "Pet stories do not fabricate records, unlock keepsakes or bypass membership")
        expect(petReload.rememberPipStory(PipStory.all[0], choice: "birds") && petReload.journal.companionDiscoveries?.count == 1, "Revisiting a story replaces its choice without duplicate progress")
        expect(petReload.exportText.contains("Fictional companion discovery · Birdsong"), "Export distinguishes fictional pet discoveries")
        petReload.clearJournal()
        expect(petReload.journal.companionDiscoveries == nil, "Deleting local data removes pet memories too")
        print("PASS: \(checks) meaningful Along domain checks")
    }
}
