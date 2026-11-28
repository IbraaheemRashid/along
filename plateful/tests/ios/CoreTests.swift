import Foundation

@main struct CoreTests {
    @MainActor static func main() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2026-11-01T12:00:00Z")!
        var checks = 0
        func expect(_ condition: Bool, _ name: String) { precondition(condition, name); checks += 1 }
        for (firstWeekday, firstKey) in [(1, "2026-11-01"), (2, "2026-10-26")] {
            var gridCalendar = calendar
            gridCalendar.firstWeekday = firstWeekday
            let grid = DayIdentity.monthGrid(containing: now, calendar: gridCalendar)
            expect(grid.first == firstKey && grid.last == "2026-11-30", "Calendar cells start under the locale’s first weekday")
            expect(DayIdentity.weekdays(in: gridCalendar).first == firstWeekday, "Week headings and dates agree")
        }
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
        let thisWeek = WeekSummary(journal: sample, ending: now, calendar: calendar)
        let previousWeek = WeekSummary(journal: sample, ending: now.addingTimeInterval(-7 * 86400), calendar: calendar)
        expect(thisWeek.recordedDays == 4 && previousWeek.recordedDays == 4, "Weekly history counts each selected seven-day period")
        expect(Set(thisWeek.checkIns.map(\.id)).isDisjoint(with: Set(previousWeek.checkIns.map(\.id))), "Adjacent weekly reflections do not repeat boundary records")
        expect(thisWeek.milestones.count == 2 && previousWeek.milestones.count == 1, "Each reflection keeps its own milestone dates")
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
        draft.hasStartDate = true; draft.startDate = Calendar.current.startOfDay(for: .now).addingTimeInterval(172800)
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
        let entryTime = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970))
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
        existing.normalizeDayKeys() // Loading stamps legacy milestones without changing their content.
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

        var progression = Journal.sample(now: now, calendar: calendar)
        progression.reconcileProgress(now: now)
        expect(progression.recordedDayCount == 0 && !progression.canUse(.scarf), "Fictional samples cannot earn days or keep demo-only cosmetic unlocks")
        expect(!progression.canRead(PipStory.all[1]) && progression.canRead(PipStory.all[0]), "A starter story is available; later stories need actual progress")
        let realDay = CheckIn(day: now, mood: .tough, appetite: .hungry, routines: [], note: "")
        progression.save(realDay, calendar: calendar)
        progression.reconcileProgress(now: now)
        expect(progression.recordedDayCount == 1 && progression.availableRewards == [.notebook], "A real first day earns the notebook regardless of mood or appetite")
        progression.save(CheckIn(day: now, mood: .bright, appetite: .low, routines: [], note: "Edit"), calendar: calendar)
        progression.reconcileProgress(now: now)
        expect(progression.recordedDayCount == 1, "Repeated saves do not award another day")
        progression.toggleRoutine(.movement, on: now, calendar: calendar)
        progression.reconcileProgress(now: now)
        expect(progression.recordedDayCount == 1, "A routine and a check-in on one date count once")
        progression.toggleRoutine(.reflection, on: calendar.date(byAdding: .day, value: -2, to: now)!, calendar: calendar)
        progression.reconcileProgress(now: now)
        expect(progression.recordedDayCount == 2 && progression.checkIns.count == 9, "A separate routine day earns progress without inventing a mood or appetite")
        progression.checkIns.removeAll()
        progression.routineDays = []
        progression.reconcileProgress(now: now.addingTimeInterval(86400 * 30))
        expect(progression.recordedDayCount == 2, "Deleting history or time away never removes earned days")
        progression.save(realDay, calendar: calendar)
        progression.reconcileProgress(now: now)
        expect(progression.recordedDayCount == 2, "Deleting and readding the same day cannot farm progress")
        progression.save(CheckIn(day: now.addingTimeInterval(172800), mood: .steady, appetite: .comfortable, routines: [], note: "Future"), calendar: calendar)
        progression.reconcileProgress(now: now)
        expect(progression.recordedDayCount == 2, "A day beyond the latest possible civil date cannot earn progress")
        var travel = PipProgress(timeZoneID: "Pacific/Kiritimati")
        travel.credit(id: realDay.id, day: now, now: now)
        travel.timeZoneID = "America/Los_Angeles"
        travel.credit(id: realDay.id, day: now, now: now)
        expect(travel.recordedDays.count == 1, "A previously credited record cannot gain a second day after a timezone change")
        let progressStore = JournalStore(directory: testRoot.appendingPathComponent("progress"), arguments: [], clearCredentials: {})
        expect(progressStore.toggleRoutine(.nutrition), "A chosen routine records without opening a check-in")
        expect(progressStore.journal.checkIns.isEmpty && progressStore.journal.recordedRoutines(on: .now) == [.nutrition], "Quick routine logging never invents feelings")
        expect(progressStore.claimReward(.notebook), "An earned keepsake can be claimed")
        expect(!progressStore.claimReward(.notebook) && !progressStore.claimReward(.lantern), "Claiming is idempotent and locked rewards cannot be claimed")
        expect(progressStore.toggleRoutine(.nutrition) && progressStore.journal.recordedRoutines(on: .now).isEmpty && progressStore.journal.roomRewards.contains(.notebook), "Undoing a routine keeps permanent earned rewards")
        let progressReload = JournalStore(directory: testRoot.appendingPathComponent("progress"), arguments: [], clearCredentials: {})
        expect(progressReload.journal.roomRewards.contains(.notebook) && progressReload.journal.recordedDayCount == 1, "Claimed rewards and earned day ledger survive relaunch")
        let failureDirectory = testRoot.appendingPathComponent("failed-writes")
        let failureStore = JournalStore(directory: failureDirectory, arguments: [], clearCredentials: {})
        let failureURL = failureDirectory.appendingPathComponent("journal-v1.json")
        try FileManager.default.removeItem(at: failureURL)
        try FileManager.default.createDirectory(at: failureURL, withIntermediateDirectories: false)
        let beforeFailure = failureStore.journal
        expect(!failureStore.saveCheckIn(day: .now, mood: .steady, appetite: .comfortable, routines: [], note: "Unwritten"), "A failed disk write reports failure")
        expect(failureStore.journal == beforeFailure, "Failed saving cannot publish a phantom entry or reward in memory")
        expect(!failureStore.toggleRoutine(.movement) && failureStore.journal == beforeFailure, "Failed quick logging keeps both UI state and ledger unchanged")
        expect(!failureStore.clearJournal() && failureStore.journal == beforeFailure, "A failed reset cannot claim data was cleared")
        let restoreDirectory = testRoot.appendingPathComponent("restore-boundary")
        let restoreStore = JournalStore(directory: restoreDirectory, arguments: [], clearCredentials: {})
        restoreStore.onboardingDraft = readyDraft()
        expect(restoreStore.saveOnboardingEntry(now: entryTime), "Restore fixture has an owned setup entry")
        let staleDraft = try Data(contentsOf: restoreDirectory.appendingPathComponent("onboarding-draft-v1.json"))
        var replacement = Journal()
        replacement.hasOnboarded = true; replacement.isDesignPreview = true
        replacement.name = "Restored"
        replacement.save(CheckIn(day: entryTime, mood: .bright, appetite: .comfortable, routines: [], note: "Restored record"))
        expect(restoreStore.restoreJournal(replacement), "Restored journal persists atomically")
        expect(!restoreStore.journal.hasOnboarded && restoreStore.journal.isDesignPreview != true, "Restore preserves local access flags even if the supplied journal tries to grant access")
        try staleDraft.write(to: restoreDirectory.appendingPathComponent("onboarding-draft-v1.json"))
        let restoredReload = JournalStore(directory: restoreDirectory, arguments: [], clearCredentials: {})
        expect(restoredReload.onboardingEntry == nil && restoredReload.onboardingDraft.step == 0, "A stale setup file cannot reclaim ownership after an interrupted restore")
        expect(restoredReload.journal.checkIns.first?.note == "Restored record", "Restored history survives stale draft recovery")
        expect(restoredReload.onboardingDraft.name == "Restored", "Recovery seeds current restored profile instead of old setup answers")
        try FileManager.default.removeItem(at: restoreDirectory.appendingPathComponent("onboarding-draft-v1.json"))
        let missingDraftReload = JournalStore(directory: restoreDirectory, arguments: [], clearCredentials: {})
        expect(missingDraftReload.onboardingDraft.name == "Restored", "Interruption before writing the first restored draft still recovers saved preferences")
        try Data("{corrupt".utf8).write(to: restoreDirectory.appendingPathComponent("journal-v1.json"))
        let corruptStore = JournalStore(directory: restoreDirectory, arguments: [], clearCredentials: {})
        expect(corruptStore.error != nil && corruptStore.restoreJournal(replacement), "Explicit validated restore can recover an unreadable local journal")
        expect(corruptStore.journal.checkIns.first?.note == "Restored record", "Successful recovery publishes the restored data")
        let routineRestore = JournalStore(directory: testRoot.appendingPathComponent("routine-restore"), arguments: [], clearCredentials: {})
        var routineReplacement = Journal()
        routineReplacement.toggleRoutine(.movement, on: entryTime)
        routineReplacement.reconcileProgress()
        expect(routineRestore.restoreJournal(routineReplacement), "Routine-only backup restores before setup")
        routineRestore.onboardingDraft = readyDraft()
        expect(routineRestore.saveOnboardingEntry(now: entryTime), "Setup can add a check-in to a restored routine day")
        expect(routineRestore.journal.checkIns.first?.routines == [.movement] && (routineRestore.journal.routineDays ?? []).isEmpty, "Setup consolidates restored routines without inventing or dropping completion")
        _ = try JournalBackup.make(from: routineRestore.journal)
        expect(true, "Consolidated journal remains exportable")
        let travelStore = JournalStore(directory: testRoot.appendingPathComponent("travel-edits"), arguments: [], clearCredentials: {})
        let travelledTime = ISO8601DateFormatter().date(from: "2026-10-12T23:30:00Z")!
        let travelledCheckIn = CheckIn(day: travelledTime, mood: .steady, appetite: .comfortable, routines: [], note: "Original", isSample: true, dayKey: "2026-10-13")
        let travelledWeight = WeightEntry(date: travelledTime, kilograms: 93.8, isSample: true, dateKey: "2026-10-13")
        expect(travelStore.updateJournal { $0.hasSampleData = true; $0.checkIns = [travelledCheckIn]; $0.weights = [travelledWeight] }, "Travelled records persist")
        expect(travelStore.saveCheckIn(day: travelledCheckIn.displayDay, mood: .bright, appetite: .low, routines: [.movement], note: "Edited", editing: travelledCheckIn.id), "A travelled check-in can be edited by ID")
        expect(travelStore.addWeight(value: 93.8, unit: .kg, date: travelledWeight.displayDate, editing: travelledWeight.id), "A travelled weight can be edited by ID")
        expect(travelStore.journal.checkIns.count == 1 && travelStore.journal.checkIns[0].day == travelledTime && travelStore.journal.checkIns[0].dayKey == "2026-10-13" && travelStore.journal.checkIns[0].isSample, "Store edits preserve date identity and sample provenance")
        expect(travelStore.journal.weights.count == 1 && travelStore.journal.weights[0] == travelledWeight, "Untouched weight edits preserve exact value, ID and civil date")
        expect(!travelStore.saveCheckIn(day: .now, mood: .steady, appetite: .comfortable, routines: [], note: "", editing: UUID()), "An editor cannot resurrect a deleted check-in")
        travelStore.referenceDate = DayIdentity.date(for: "2026-10-13")!
        expect(travelStore.today?.id == travelledCheckIn.id, "Today resolves the recorded civil day")
        travelStore.referenceDate = DayIdentity.date(for: "2026-10-14")!
        expect(travelStore.today == nil && travelStore.weekRecordedDays == 1, "Day rollover clears Today while retaining the rolling recap")
        _ = try JournalBackup.make(from: travelStore.journal)
        expect(true, "Travelled store edits remain exportable")
        let resumedTravel = JournalStore(directory: testRoot.appendingPathComponent("travel-setup"), arguments: [], clearCredentials: {})
        resumedTravel.onboardingDraft = readyDraft()
        var london = calendar; london.timeZone = TimeZone(identifier: "Europe/London")!
        var newYork = calendar; newYork.timeZone = TimeZone(identifier: "America/New_York")!
        expect(resumedTravel.saveOnboardingEntry(now: travelledTime, calendar: london), "Setup records the original civil day")
        let preservedWeight = WeightEntry(date: travelledTime, kilograms: 91, dateKey: "2026-10-13")
        expect(resumedTravel.updateJournal { $0.weights = [preservedWeight] }, "An independently recorded weight exists on the setup day")
        resumedTravel.onboardingDraft.showWeight = true; resumedTravel.onboardingDraft.weightValue = "75"
        expect(resumedTravel.saveOnboardingEntry(now: .now, calendar: newYork), "Setup resumes after travel")
        expect(resumedTravel.journal.weights == [preservedWeight], "Travelled setup cannot duplicate or overwrite an independent same-day weight")

        var setup = SetupDraft()
        expect(setup.step == .welcome && setup.progress == 0, "Peptide setup starts on the welcome screen")
        expect(SetupStep.allCases.first == .welcome && SetupStep.allCases.last == .paywall, "Peptide setup ends on the paywall")
        expect(!setup.canContinue(at: .experience) && !setup.canContinue(at: .goals) && !setup.canContinue(at: .source)
               && !setup.canContinue(at: .frequency) && !setup.canContinue(at: .obstacles), "Required setup answers cannot be skipped")
        setup.goals = [.recovery]
        expect(!setup.steps.contains(.weight) && !setup.steps.contains(.target) && setup.step(after: .birthday) == .commitment, "Weight is only asked for weight goals")
        expect(setup.step(after: .weight) == .commitment, "Leaving a retired or hidden screen moves forward")
        setup.goals.insert(.weightLoss)
        expect(setup.step(after: .weight) == .target && setup.step(before: .commitment) == .target, "Weight goals add the goal-weight screen")
        expect(setup.step(before: .plan) == .ready && setup.step(before: .account) == .plan && setup.step(before: .paywall) == .account, "Going back never replays the loader")
        setup.goals = [.recovery]
        expect(setup.step(before: .target) == .birthday, "Back from a hidden step lands on the nearest visible screen")
        setup.goals = [.weightLoss]; setup.weightKg = 90
        setup.prepareTarget()
        expect(setup.targetKg < setup.weightKg && setup.targetDirection == "Lose weight", "Weight-loss goals seed a lower target")
        setup.hasChosenTarget = true; setup.targetKg = 95; setup.prepareTarget()
        expect(setup.targetKg == 95, "A chosen target is never overwritten")
        setup.birthDate = calendar.date(byAdding: .year, value: -17, to: now)!
        expect(!setup.canContinue(at: .birthday, now: now) && !setup.isAdult(now: now), "Under-18s cannot continue")
        setup.birthDate = calendar.date(byAdding: .year, value: -30, to: now)!
        expect(setup.canContinue(at: .birthday, now: now), "Adults can continue")
        setup.toggleCompound("BPC-157"); setup.toggleCompound("bpc-157")
        expect(setup.compounds.isEmpty, "Compound toggles are case-insensitive")
        setup.toggleCompound("BPC-157"); setup.toggleCompound("TB-500"); setup.toggleCompound("GHK-Cu")
        expect(setup.compounds.count == 3, "Each peptide can be added once")
        expect(Peptide.library.count >= 60, "Search catalogue covers a broad peptide set")
        expect(Peptide.matches("sema").contains(where: { $0.name == "Semaglutide" }), "Catalogue search matches by name")
        expect(Peptide.matches("recovery").contains(where: { $0.name == "BPC-157" }), "Catalogue search matches by category")
        setup.toggleCompound(String(repeating: "x", count: 41)); setup.toggleCompound("  ")
        expect(setup.compounds.count == 3, "Blank or oversized custom peptides are rejected")
        setup.referralCode = "CREATOR-10"
        expect(setup.canContinue(at: .referral), "Referral codes accept letters, numbers and dashes")
        setup.referralCode = "NO SPACES"
        expect(!setup.canContinue(at: .referral) && !setup.isValid, "Invalid referral codes are rejected")
        setup.referralCode = ""
        expect(setup.isValid, "A complete setup is valid")
        let setupData = try JSONEncoder().encode(setup)
        expect(try JSONDecoder().decode(SetupDraft.self, from: setupData) == setup, "Setup survives persistence round trip")
        expect(try JSONDecoder().decode(SetupDraft.self, from: Data("{\"step\":\"goals\"}".utf8)).step == .goals, "Partial setup files decode with defaults")
        let retired = try JSONDecoder().decode(SetupDraft.self, from: Data("{\"step\":\"height\",\"experience\":\"stack\",\"obstacles\":[\"forgetting\",\"retired\"]}".utf8))
        expect(retired.step == .welcome && retired.experience == nil && retired.obstacles == [.forgetting], "Retired screens and answers fall back safely")

        let setupRoot = testRoot.appendingPathComponent("peptide-setup")
        let setupStore = JournalStore(directory: setupRoot, arguments: [], clearCredentials: {})
        setup.frequency = .daily
        setup.step = .frequency
        setupStore.setup = setup
        let resumedSetup = JournalStore(directory: setupRoot, arguments: [], clearCredentials: {})
        expect(resumedSetup.setup == setup && !resumedSetup.journal.hasOnboarded, "Incomplete setup resumes at the saved screen")
        resumedSetup.setup.weightKg = 88.4
        expect(resumedSetup.finishSetup(now: now, calendar: calendar), "A valid setup completes")
        expect(resumedSetup.journal.hasOnboarded && resumedSetup.journal.setupProfile?.weightKg == 88.4, "Setup answers are saved to the journal")
        expect(resumedSetup.journal.weights.count == 1 && resumedSetup.journal.weights[0].kilograms == 88.4 && resumedSetup.journal.showWeight, "Starting weight becomes the first weight record")
        expect(resumedSetup.finishSetup(now: now, calendar: calendar) && resumedSetup.journal.weights.count == 1, "Finishing twice never duplicates the starting weight")
        let noWeightGoal = JournalStore(directory: testRoot.appendingPathComponent("skin-setup"), arguments: [], clearCredentials: {})
        noWeightGoal.setup = setup
        noWeightGoal.setup.goals = [.skin]
        expect(noWeightGoal.finishSetup(now: now, calendar: calendar) && noWeightGoal.journal.weights.isEmpty, "Goals without weight never invent a weight record")
        _ = try JournalBackup.make(from: resumedSetup.journal)
        expect(true, "Journals with a setup profile remain exportable")
        let underage = JournalStore(directory: testRoot.appendingPathComponent("underage-setup"), arguments: [], clearCredentials: {})
        underage.setup = setup
        underage.setup.birthDate = calendar.date(byAdding: .year, value: -16, to: now)!
        expect(!underage.finishSetup(now: now, calendar: calendar) && !underage.journal.hasOnboarded, "Under-18 setups never complete")
        let handover = resumedSetup.journal.protocolPeptides
        expect(handover.map(\.name) == setup.compounds, "Setup peptides become the starting protocol")
        expect(handover.allSatisfy { $0.amount == nil && $0.startKey == "2026-11-01" }, "Setup never fills in a dose amount")
        expect(handover.allSatisfy { $0.schedule.times == [DoseTime(hour: setup.doseHour, minute: setup.doseMinute)] }, "The chosen dose time carries into every schedule")
        expect(resumedSetup.finishSetup(now: now, calendar: calendar) && resumedSetup.journal.protocolPeptides.count == handover.count, "Finishing twice never duplicates peptides")
        var weeklySetup = setup; weeklySetup.frequency = .weekly
        let morning = DoseTime(hour: setup.doseHour, minute: setup.doseMinute)
        expect(weeklySetup.initialPeptides(startKey: "2026-11-04").allSatisfy { $0.schedule == .unscheduled }, "Old weekly drafts never infer a weekday from completion")
        weeklySetup.sharedWeekdays = [6]
        expect(weeklySetup.initialPeptides(startKey: "2026-11-04").first?.schedule == .on([6], at: morning), "Weekly setup uses the selected weekday")
        var fewSetup = setup; fewSetup.frequency = .fewPerWeek
        expect(!fewSetup.canContinue(at: .doseTime), "Several dose days must be selected explicitly")
        fewSetup.sharedWeekdays = [3, 7]
        expect(fewSetup.canContinue(at: .doseTime) && fewSetup.initialPeptides(startKey: "2026-11-04").allSatisfy { $0.schedule == .on([3, 7], at: morning) }, "Shared weekdays match the user's choices")
        var varied = setup; varied.frequency = .varies
        let evening = DoseTime(hour: 20, minute: 45)
        varied.peptideSchedules[setup.compounds[0]] = .on([3], at: evening)
        varied.peptideSchedules[setup.compounds[1]] = .on([2, 6], at: morning)
        let mixed = varied.initialPeptides(startKey: "2026-11-01")
        expect(mixed.map(\.schedule) == [.on([3], at: evening), .on([2, 6], at: morning), .unscheduled], "Mixed protocols retain each chosen time and leave undecided peptides unscheduled")
        expect(mixed[2].isValid && !ProtocolSchedule.isDue(mixed[2], on: "2026-11-03"), "An unscheduled peptide is valid and never due")
        expect(ProtocolSchedule.nextDose(after: now, peptides: [mixed[2]], logs: []) == nil, "Unscheduled peptides cannot be the next dose")
        var mixedJournal = Journal()
        mixedJournal.setupProfile = varied
        mixedJournal.adoptSetupPeptides(mixed)
        let archive = try JournalBackup.make(from: mixedJournal).encoded()
        let restoredMixed = try JournalBackup.decode(archive).restoring(into: Journal())
        expect(restoredMixed.setupProfile == varied && restoredMixed.protocolPeptides == mixed, "Backup preserves specific and deferred schedules")
        varied.toggleCompound(setup.compounds[0])
        expect(varied.peptideSchedules[setup.compounds[0]] == nil, "Removing a peptide clears its draft schedule")
        do {
            var weeklySetup = setup
            weeklySetup.frequency = .weekly
            expect(!weeklySetup.canContinue(at: .doseTime) && weeklySetup.schedule(for: setup.compounds[0]) == .unscheduled, "Weekly setup waits for the person to choose a day")
            weeklySetup.sharedWeekdays = [2]
            let friday = ISO8601DateFormatter().date(from: "2026-11-06T12:00:00Z")!
            let confirmed = weeklySetup.initialPeptides(startKey: "2026-11-06")
            let nextMonday = ProtocolSchedule.nextDose(after: friday, peptides: confirmed, logs: [], timeZone: calendar.timeZone)
            expect(nextMonday?.slot.dayKey == "2026-11-09", "Finishing on Friday preserves the selected Monday")
            var mixed = setup
            mixed.frequency = .varies
            mixed.peptideSchedules[mixed.compounds[0]] = .on([2], at: DoseTime(hour: 8, minute: 0))
            let different = mixed.initialPeptides(startKey: "2026-11-06")
            expect(different[0].schedule.weekdays == [2] && different[1].schedule == .unscheduled, "Each peptide keeps its own confirmed schedule")
            expect(ProtocolSchedule.nextDose(after: friday, peptides: [different[1]], logs: [], timeZone: calendar.timeZone) == nil, "Deferred schedules have no next dose")
            let earlyMonday = ISO8601DateFormatter().date(from: "2026-11-09T06:00:00Z")!
            let earlyLog = SetupInjection(takenAt: earlyMonday, dayKey: "2026-11-09").log(for: different[0])
            let following = ProtocolSchedule.nextDose(after: earlyMonday, peptides: [different[0]], logs: [earlyLog], timeZone: calendar.timeZone)
            expect(following?.slot.dayKey == "2026-11-16", "An injection logged early answers its single slot that day")
            let oldDraft = try JSONDecoder().decode(SetupDraft.self, from: Data("{\"frequency\":\"varies\",\"compounds\":[\"Example\"]}".utf8))
            expect(oldDraft.lastInjections.isEmpty && oldDraft.schedule(for: "Example") == .unscheduled, "Old drafts keep unconfirmed times unset")

            let injectionStore = JournalStore(directory: testRoot.appendingPathComponent("last-injection"), arguments: [], clearCredentials: {})
            var intake = weeklySetup
            let monday = ISO8601DateFormatter().date(from: "2026-11-02T12:00:00Z")!
            let dayKey = DayIdentity.key(for: monday, timeZone: calendar.timeZone)!
            let name = intake.compounds[0]
            intake.sharedWeekdays = [ProtocolSchedule.weekday(of: dayKey)!]
            let entry = SetupInjection(takenAt: monday, dayKey: dayKey, site: .armLeft)
            intake.lastInjections[name] = entry
            injectionStore.setup = intake
            expect(injectionStore.journal.protocolLogs.isEmpty && !injectionStore.journal.hasOnboarded, "Pre-purchase entries only exist in the draft")
            let persisted = JournalStore(directory: testRoot.appendingPathComponent("last-injection"), arguments: [], clearCredentials: {})
            expect(persisted.setup.lastInjections[name] == entry, "Last injection and civil day survive relaunch")
            expect(persisted.finishSetup(now: monday, calendar: calendar), "A confirmed last injection can become a dose record")
            let archived = try JournalBackup.decode(JournalBackup.make(from: persisted.journal).encoded()).restoring(into: Journal())
            expect(archived.protocolLogs.count == 1 && archived.protocolLogs.first?.id == entry.id && archived.protocolLogs.first?.site == .armLeft, "A note-free setup entry survives backup")
            expect(persisted.finishSetup(now: monday, calendar: calendar) && persisted.journal.protocolLogs.count == 1, "Finishing twice preserves a single injection")
            expect(persisted.setup.lastInjections.isEmpty, "Completed setup keeps a single copy in the journal")
            intake.toggleCompound(name)
            expect(intake.lastInjections[name] == nil, "Removing a peptide clears only its draft injection")
        }

        let protocolStore = resumedSetup
        protocolStore.referenceDate = now
        let firstPeptide = handover[0]
        var renamed = firstPeptide; renamed.name = handover[1].name.uppercased()
        expect(!protocolStore.savePeptide(renamed), "Two peptides cannot share a name")
        var edited = firstPeptide; edited.amount = 250; edited.unit = .mcg; edited.schedule.times = [DoseTime(hour: 20, minute: 0), DoseTime(hour: 8, minute: 0), DoseTime(hour: 8, minute: 0)]
        expect(protocolStore.savePeptide(edited) && protocolStore.peptide(firstPeptide.id)?.schedule.times == [DoseTime(hour: 8, minute: 0), DoseTime(hour: 20, minute: 0)], "Saving tidies duplicate and unordered times")
        var invalid = firstPeptide; invalid.amount = -1
        expect(!protocolStore.savePeptide(invalid) && protocolStore.peptide(firstPeptide.id)?.amount == 250, "An invalid edit leaves the protocol unchanged")
        let custom = TrackedPeptide(name: "  My blend ", schedule: .every(3, at: DoseTime(hour: 9, minute: 0)), startKey: "2026-11-01")
        expect(protocolStore.savePeptide(custom) && protocolStore.peptide(custom.id)?.name == "My blend", "Custom peptides can be added")

        let todaySlots = protocolStore.slots(on: "2026-11-01")
        let morningSlot = todaySlots.first { $0.peptide.id == firstPeptide.id && $0.time == DoseTime(hour: 8, minute: 0) }!
        expect(protocolStore.logDose(morningSlot, at: now), "A scheduled dose logs in one tap")
        let logged = protocolStore.journal.protocolLogs.first!
        expect(logged.amount == 250 && logged.unit == .mcg && logged.status == .taken, "One-tap logs copy the protocol's own amount")
        expect(protocolStore.logDose(protocolStore.slots(on: "2026-11-01").first { $0.id == morningSlot.id }!, status: .skipped, at: now) && protocolStore.journal.protocolLogs.count == 1 && protocolStore.journal.protocolLogs[0].status == .skipped, "Changing an answer updates the same record")
        var duplicate = DoseLog(peptideID: firstPeptide.id, dayKey: "2026-11-01", scheduledTime: DoseTime(hour: 8, minute: 0), takenAt: now)
        expect(!protocolStore.saveDose(duplicate), "A slot cannot be answered twice")
        duplicate.scheduledTime = nil; duplicate.site = .thighLeft; duplicate.note = "  Felt fine  "
        expect(protocolStore.saveDose(duplicate) && protocolStore.journal.protocolLogs.count == 2 && protocolStore.journal.protocolLogs[1].note == "Felt fine", "Extra doses can be logged with a site and note")
        expect(!protocolStore.saveDose(DoseLog(peptideID: UUID(), dayKey: "2026-11-01", takenAt: now)), "Doses for unknown peptides are rejected")
        expect(protocolStore.setPaused(firstPeptide.id, true) && !protocolStore.slots(on: "2026-11-02").contains { $0.peptide.id == firstPeptide.id }, "Paused peptides leave the schedule")
        expect(protocolStore.journal.protocolLogs.count == 2, "Pausing keeps dose history")
        expect(protocolStore.removeDose(duplicate.id) && protocolStore.journal.protocolLogs.count == 1, "Doses can be deleted")
        expect(protocolStore.removePeptide(firstPeptide.id) && protocolStore.peptide(firstPeptide.id) == nil && protocolStore.journal.protocolLogs.isEmpty, "Removing a peptide removes its history")
        let reloaded = JournalStore(directory: setupRoot, arguments: [], clearCredentials: {})
        expect(reloaded.journal.protocolPeptides == protocolStore.journal.protocolPeptides, "Protocol changes persist across launches")

        resumedSetup.resetOnboarding()
        expect(resumedSetup.setup == SetupDraft(), "Restarting setup clears every answer")
        let accountChecks = try await AccountSyncTests.run(in: testRoot.appendingPathComponent("account-switching"))
        print("PASS: \(accountChecks) account isolation and backup checks")
        print("PASS: \(checks) meaningful Along domain checks")
    }
}
