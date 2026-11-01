import Foundation

@main struct DayIdentityTests {
    static func main() throws {
        func instant(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
        let london = TimeZone(identifier: "Europe/London")!
        let newYork = TimeZone(identifier: "America/New_York")!
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!
        let londonCalendar = DayIdentity.calendar(in: london)
        let newYorkCalendar = DayIdentity.calendar(in: newYork)
        let now = instant("2026-11-03T12:00:00Z")
        var checks = 0
        func expect(_ value: Bool, _ name: String) { precondition(value, name); checks += 1 }
        func rejects(_ name: String, _ action: () throws -> Void) {
            do { try action(); preconditionFailure("Expected rejection: \(name)") }
            catch { checks += 1 }
        }
        let first = CheckIn(day: instant("2026-11-01T23:30:00Z"), mood: .steady, appetite: .comfortable, routines: [], note: "First")
        let second = CheckIn(day: instant("2026-11-02T00:30:00Z"), mood: .bright, appetite: .comfortable, routines: [.nutrition], note: "Second")
        var journal = Journal(); journal.startDate = first.day
        journal.pipProgress = PipProgress(timeZoneID: london.identifier)
        journal.save(first, calendar: londonCalendar); journal.save(second, calendar: londonCalendar)
        journal.reconcileProgress(now: now)
        expect(journal.checkIns.map(\.dayKey) == ["2026-11-01", "2026-11-02"], "Records retain the two dates originally selected in London")
        expect(newYorkCalendar.isDate(first.day, inSameDayAs: second.day), "Regression fixture timestamps collapse to one day in New York")
        expect(journal.recordedDayCount == 2, "Separate stable civil dates count as two days")
        let november2NY = DayIdentity.date(for: "2026-11-02", timeZone: newYork)!
        expect(journal.checkIn(on: november2NY, calendar: newYorkCalendar)?.id == second.id, "Lookup after travel uses stable date, not shifted timestamp")
        let rawSecond = journal.checkIns[1].day
        journal.save(CheckIn(day: november2NY, mood: .tough, appetite: .low, routines: [.movement], note: "Corrected"), calendar: newYorkCalendar)
        expect(journal.checkIns.count == 2 && journal.checkIns[1].id == second.id, "Date-only upsert after travel updates the correct existing identity")
        expect(journal.checkIns[1].day == rawSecond && journal.checkIns[1].dayKey == "2026-11-02", "Editing retains both original timestamp and date key")
        var byID = journal.checkIns[1]; byID.dayKey = nil
        journal.save(byID, calendar: newYorkCalendar)
        expect(journal.checkIns[1].dayKey == "2026-11-02", "An explicit existing ID recovers its stored date even when raw timestamp would shift")
        journal.toggleRoutine(.reflection, on: november2NY, calendar: newYorkCalendar)
        expect(journal.recordedRoutines(on: november2NY, calendar: newYorkCalendar) == [.movement, .reflection], "Routine toggles edit the correct travelled day")
        expect((journal.routineDays ?? []).isEmpty, "Toggling an existing check-in does not create a competing routine-only record")
        journal.reconcileProgress(now: now)
        expect(journal.recordedDayCount == 2, "Travel, edits and routine toggles do not award duplicate days")
        let weekEnd = DayIdentity.date(for: "2026-11-08", timeZone: newYork)!
        expect(journal.week(ending: weekEnd, calendar: newYorkCalendar).map(\.id) == [second.id], "Weekly ranges include the correct civil date after travel")

        let firstWeight = WeightEntry(date: first.day, kilograms: 80)
        let secondWeight = WeightEntry(date: second.day, kilograms: 81)
        journal.save(firstWeight, calendar: londonCalendar); journal.save(secondWeight, calendar: londonCalendar)
        journal.save(WeightEntry(date: november2NY, kilograms: 82), calendar: newYorkCalendar)
        expect(journal.weights.count == 2 && journal.weights[1].id == secondWeight.id && journal.weights[1].kilograms == 82, "Weight upsert preserves the separate date and original ID")
        expect(journal.weights[1].date == secondWeight.date && journal.weight(on: november2NY, calendar: newYorkCalendar)?.id == secondWeight.id, "Weight lookup and raw timestamp survive travel")
        journal.milestones = [Milestone(date: first.day, title: "A moment", note: "", kind: .everyday, dateKey: "2026-11-01")]
        let oldLedger = journal.pipProgress
        let archive = try JournalBackup.make(from: journal, now: now, timeZone: newYork)
        let decoded = try JournalBackup.decode(archive.encoded(now: now), now: now)
        let restored = try decoded.restoring(into: Journal(), now: now)
        expect(restored.checkIns == journal.checkIns && restored.weights == journal.weights, "Cross-timezone archive round trip preserves dates, timestamps and identities")
        expect(restored.pipProgress == oldLedger, "Backup normalization does not mint progress")
        expect(restored.milestones[0].dateKey == "2026-11-01", "Milestone date key survives archive round trip")
        let textStyle = Date.FormatStyle(date: .numeric, time: .omitted, locale: Locale(identifier: "en_GB"), timeZone: newYork)
        expect(restored.checkIns[1].dayText(textStyle) == "02/11/2026", "Date-only text ignores the viewer's offset")
        expect(DayIdentity.key(for: DayIdentity.displayDate(key: "2026-11-02", rawDate: rawSecond, timeZone: newYork), timeZone: newYork) == "2026-11-02", "Display Date reconstructs the stored day in the viewer's calendar")

        let raw = try JSONSerialization.jsonObject(with: archive.encoded(now: now)) as! [String: Any]
        func changed(_ mutation: (inout [String: Any]) -> Void) throws -> Data {
            var value = raw; mutation(&value)
            return try JSONSerialization.data(withJSONObject: value)
        }
        func changedContent(_ mutation: (inout [String: Any]) -> Void) throws -> Data {
            try changed { value in var content = value["content"] as! [String: Any]; mutation(&content); value["content"] = content }
        }
        var legacy = journal
        for index in legacy.checkIns.indices { legacy.checkIns[index].dayKey = nil }
        for index in legacy.weights.indices { legacy.weights[index].dateKey = nil }
        for index in legacy.milestones.indices { legacy.milestones[index].dateKey = nil }
        legacy.normalizeDayKeys(sourceTimeZone: legacy.legacyDayTimeZone(fallback: newYork))
        expect(legacy.checkIns.map(\.dayKey) == ["2026-11-01", "2026-11-02"], "Native legacy migration prefers the saved ledger timezone")
        expect(legacy.pipProgress == oldLedger, "Normalizing legacy keys alone leaves the reward ledger untouched")
        let once = legacy
        legacy.normalizeDayKeys(sourceTimeZone: tokyo)
        expect(legacy == once, "A second migration in another timezone cannot reinterpret existing keys")
        let legacyData = try changed { value in
            value["schemaVersion"] = 1; value["timeZoneID"] = london.identifier
            var content = value["content"] as! [String: Any]
            for category in ["checkIns", "weights", "milestones"] {
                var entries = content[category] as! [[String: Any]]
                for index in entries.indices { entries[index].removeValue(forKey: category == "checkIns" ? "dayKey" : "dateKey") }
                content[category] = entries
            }
            value["content"] = content
        }
        let importedLegacy = try JournalBackup.decode(legacyData, now: now)
        expect(importedLegacy.schemaVersion == 2 && importedLegacy.content.checkIns.map(\.dayKey) == ["2026-11-01", "2026-11-02"], "Schema 1 source timezone is stamped before cross-timezone import")
        expect(importedLegacy.content.pipProgress == oldLedger, "Legacy archive import preserves existing credits exactly")
        rejects("Ambiguous legacy duplicate days are reported, never silently merged") {
            var ambiguous = try JSONSerialization.jsonObject(with: legacyData) as! [String: Any]
            ambiguous["timeZoneID"] = newYork.identifier
            _ = try JournalBackup.decode(JSONSerialization.data(withJSONObject: ambiguous), now: now)
        }

        for key in ["2026-2-03", "2026-02-30", "1900-02-29", "1899-12-31", "10000-01-01", "２０２６-11-01", "2026-11-01\n", "2026-00-01"] {
            expect(!DayIdentity.isValid(key), "Malformed/out-of-range civil date rejected: \(key)")
        }
        expect(DayIdentity.isValid("2000-02-29") && DayIdentity.isValid("2024-02-29"), "Valid leap days remain usable")
        for rawKey: Any in ["2026-02-30", "2026-11-12", 123, NSNull()] {
            rejects("Malformed or unrelated optional record key") {
                _ = try JournalBackup.decode(try changedContent {
                    var entries = $0["checkIns"] as! [[String: Any]]
                    entries[0]["dayKey"] = rawKey; $0["checkIns"] = entries
                }, now: now)
            }
        }
        rejects("Duplicate stable keys rejected despite different timestamps") {
            _ = try JournalBackup.decode(try changedContent {
                var entries = $0["checkIns"] as! [[String: Any]]
                entries[1]["dayKey"] = "2026-11-01"; $0["checkIns"] = entries
            }, now: now)
        }
        rejects("Unknown record field still rejected") {
            _ = try JournalBackup.decode(try changedContent {
                var entries = $0["checkIns"] as! [[String: Any]]
                entries[0]["extraDateKey"] = "2026-11-01"; $0["checkIns"] = entries
            }, now: now)
        }
        rejects("Future archive schema") { _ = try JournalBackup.decode(try changed { $0["schemaVersion"] = JournalBackup.currentSchema + 1 }, now: now) }

        for (early, late, key) in [
            ("2026-03-08T06:30:00Z", "2026-03-08T07:30:00Z", "2026-03-08"),
            ("2026-11-01T05:30:00Z", "2026-11-01T06:30:00Z", "2026-11-01")
        ] {
            var dst = Journal()
            dst.save(CheckIn(day: instant(early), mood: .steady, appetite: .comfortable, routines: [], note: "Early"), calendar: newYorkCalendar)
            dst.save(CheckIn(day: instant(late), mood: .bright, appetite: .comfortable, routines: [], note: "Late"), calendar: newYorkCalendar)
            expect(dst.checkIns.count == 1 && dst.checkIns[0].dayKey == key, "DST gap/fold remains one civil date")
            expect(DayIdentity.key(for: DayIdentity.date(for: key, timeZone: newYork)!, timeZone: newYork) == key, "Local-noon display survives DST transition")
        }
        expect(DayIdentity.formatted(key: "2011-12-30", rawDate: instant("2011-12-30T12:00:00Z"), style: .init(date: .numeric, time: .omitted, locale: Locale(identifier: "en_GB"), timeZone: TimeZone(identifier: "Pacific/Apia")!)) == "30/12/2011", "Text preserves a civil date skipped in the viewer's historical timezone")

        let travelNow = instant("2026-11-01T15:30:00Z") // Nov 2 in Tokyo; Nov 1 in New York.
        let tokyoKey = DayIdentity.key(for: travelNow, timeZone: tokyo)!
        expect(tokyoKey == "2026-11-02", "Date-line fixture is tomorrow relative to the viewer")
        var travelled = Journal(); travelled.startDate = travelNow
        travelled.pipProgress = PipProgress(timeZoneID: newYork.identifier)
        let travelEntry = CheckIn(day: travelNow, mood: .steady, appetite: .comfortable, routines: [], note: "Tokyo", dayKey: tokyoKey)
        travelled.save(travelEntry, calendar: DayIdentity.calendar(in: tokyo)); travelled.reconcileProgress(now: travelNow)
        expect(travelled.recordedDayCount == 1, "A legitimate ahead-of-viewer date earns once")
        let travelArchive = try JournalBackup.make(from: travelled, now: travelNow, timeZone: newYork)
        expect(try JournalBackup.decode(travelArchive.encoded(now: travelNow), now: travelNow).content.checkIns[0].dayKey == tokyoKey, "Ahead-of-viewer civil date exports and imports from New York")
        travelled.reconcileProgress(now: travelNow)
        expect(travelled.recordedDayCount == 1, "Reconciliation does not duplicate a date-line credit")
        expect(!JournalValidation.recordDate(DayIdentity.date(for: tokyoKey, timeZone: newYork)!, now: travelNow, calendar: newYorkCalendar), "New future date selection is still rejected in the viewer's zone")
        expect(JournalValidation.storedRecordDate(travelEntry.day, key: tokyoKey, now: travelNow, sourceTimeZone: newYork), "Existing date-line record remains editable through stored-record validation")
        var dateOnlyTravel = travelled
        dateOnlyTravel.checkIns[0].day = instant("2026-11-02T03:00:00Z") // Noon on the selected Tokyo day.
        let dateOnlyArchive = try JournalBackup.make(from: dateOnlyTravel, now: travelNow, timeZone: newYork)
        expect(try JournalBackup.decode(dateOnlyArchive.encoded(now: travelNow), now: travelNow).content.checkIns[0].dayKey == tokyoKey, "A date-only record can retain a later clock time without becoming invalid after travel")
        expect(!JournalValidation.storedRecordDate(instant("2026-11-02T12:00:00Z"), key: nil, now: travelNow, sourceTimeZone: newYork), "Timestamp-only legacy records still use their known source date")
        var previouslyCredited = travelled
        previouslyCredited.pipProgress?.recordedDays = ["2026-11-01"]
        previouslyCredited.reconcileProgress(now: travelNow)
        expect(previouslyCredited.pipProgress?.recordedDays == ["2026-11-01"], "Old credits never gain a second day when an already-credited ID has a different stable date")
        var futureProgress = PipProgress(timeZoneID: newYork.identifier)
        futureProgress.credit(id: UUID(), day: travelNow.addingTimeInterval(86400), now: travelNow, dayKey: "2026-11-03")
        expect(futureProgress.recordedDays.isEmpty, "A future date and timestamp cannot invent a credit")

        var routines = Journal(); routines.startDate = now
        routines.toggleRoutine(.movement, on: november2NY, calendar: newYorkCalendar)
        expect(routines.routineDays?.first?.dayKey == "2026-11-02", "Independent routine creation stamps its civil date")
        let sameDayTokyo = DayIdentity.date(for: "2026-11-02", timeZone: tokyo)!
        routines.toggleRoutine(.reflection, on: sameDayTokyo, calendar: DayIdentity.calendar(in: tokyo))
        expect(routines.routineDays?.count == 1 && routines.recordedRoutines(on: sameDayTokyo, calendar: DayIdentity.calendar(in: tokyo)) == [.movement, .reflection], "Routine upsert after travel still refers to the same date label")
        routines.reconcileProgress(now: now)
        let priorCredits = routines.pipProgress?.recordedDays
        routines.save(CheckIn(day: sameDayTokyo, mood: .steady, appetite: .comfortable, routines: [.movement, .reflection], note: ""), calendar: DayIdentity.calendar(in: tokyo))
        routines.reconcileProgress(now: now)
        expect(routines.routineDays?.isEmpty == true && routines.pipProgress?.recordedDays == priorCredits, "Routine-to-check-in consolidation does not award another day")
        var samples = Journal(); samples.hasSampleData = true
        samples.routineDays = [RoutineDay(day: first.day, routines: [.movement], isSample: true, dayKey: "2026-11-01")]
        samples.save(CheckIn(day: first.day, mood: .steady, appetite: .comfortable, routines: [.movement], note: "Edited example"), calendar: londonCalendar)
        samples.reconcileProgress(now: now)
        expect(samples.checkIns[0].isSample && samples.recordedDayCount == 0, "Consolidating a sample routine cannot erase provenance or earn progress")

        for date in [Date(timeIntervalSinceReferenceDate: .nan), Date(timeIntervalSinceReferenceDate: .infinity), instant("1800-01-01T12:00:00Z"), now.addingTimeInterval(86400)] {
            expect(!JournalValidation.recordDate(date, now: now, calendar: londonCalendar), "Unsupported new-record date rejected")
        }
        expect(JournalValidation.recordDate(instant("1900-01-01T12:00:00Z"), now: now, calendar: londonCalendar), "Supported lower date bound accepted")
        expect(JournalValidation.checkIn(note: "A\nB\tC", day: now, now: now) && JournalValidation.milestone(title: "A", note: "B\nC\tD"), "Journal text permits newline and tab")
        expect(!JournalValidation.checkIn(note: "A\u{0000}B", day: now, now: now) && !JournalValidation.milestone(title: "A\u{001B}", note: ""), "Journal text rejects other control characters before saving")
        print("Day identity checks passed: \(checks)")
    }
}
