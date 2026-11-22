import Foundation

@main struct ProtocolTests {
    static func main() throws {
        let zone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2026-11-04T12:00:00Z")! // Wednesday
        var checks = 0
        func expect(_ condition: Bool, _ name: String) { precondition(condition, name); checks += 1 }
        func rejects(_ name: String, _ action: () throws -> Void) {
            do { try action(); preconditionFailure("Expected rejection: \(name)") } catch { checks += 1 }
        }
        let morning = DoseTime(hour: 8, minute: 0), evening = DoseTime(hour: 20, minute: 30)

        // Schedules
        expect(ProtocolSchedule.weekday(of: "2026-11-04") == 4, "Day keys resolve to the right weekday")
        expect(ProtocolSchedule.days(from: "2026-10-30", to: "2026-11-04") == 5, "Day differences cross month boundaries")
        expect(ProtocolSchedule.key("2026-12-31", adding: 1) == "2027-01-01", "Day keys roll over the year")
        var daily = TrackedPeptide(name: "BPC-157", amount: 250, unit: .mcg, schedule: .daily(at: morning), startKey: "2026-11-01")
        daily.schedule.times = [evening, morning]
        expect(ProtocolSchedule.isDue(daily, on: "2026-11-04") && !ProtocolSchedule.isDue(daily, on: "2026-10-31"), "Daily peptides are due from their start date only")
        let weekly = TrackedPeptide(name: "Tirzepatide", amount: 2.5, unit: .mg, schedule: .on([4], at: morning), startKey: "2026-10-01")
        expect(ProtocolSchedule.isDue(weekly, on: "2026-11-04") && !ProtocolSchedule.isDue(weekly, on: "2026-11-05"), "Weekday schedules follow the chosen days")
        let interval = TrackedPeptide(name: "TB-500", schedule: .every(3, at: morning), startKey: "2026-11-01")
        expect(ProtocolSchedule.isDue(interval, on: "2026-11-04") && !ProtocolSchedule.isDue(interval, on: "2026-11-05") && ProtocolSchedule.isDue(interval, on: "2026-11-07"), "Interval schedules count from the start date")
        var paused = daily; paused.id = UUID(); paused.isPaused = true
        expect(!ProtocolSchedule.isDue(paused, on: "2026-11-04"), "Paused peptides are never due")

        expect(DoseSchedule.on([2, 4, 6], at: morning).isValid && !DoseSchedule.on([], at: morning).isValid, "Specific-day schedules need at least one day")
        expect(!DoseSchedule.every(1, at: morning).isValid && !DoseSchedule(kind: .daily, times: []).isValid, "Schedules need a time and a real interval")
        expect(!DoseSchedule(kind: .daily, times: [morning, morning]).isValid, "Duplicate dose times are rejected")
        expect(!DoseSchedule.daily(at: DoseTime(hour: 24, minute: 0)).isValid, "Impossible times are rejected")
        expect(DoseSchedule.on(Set(1...7), at: morning).summary == "Every day", "Seven chosen days read as every day")

        expect(TrackedPeptide(name: "Custom blend", startKey: "2026-11-01").isValid, "A dose amount is optional: the app never fills one in")
        expect(!TrackedPeptide(name: "  ", startKey: "2026-11-01").isValid, "Blank names are rejected")
        expect(!TrackedPeptide(name: "X", amount: -1, startKey: "2026-11-01").isValid && !TrackedPeptide(name: "X", amount: .nan, startKey: "2026-11-01").isValid, "Invalid amounts are rejected")
        expect(!TrackedPeptide(name: "X", startKey: "2026-13-01").isValid, "Invalid start dates are rejected")
        var withBatch = TrackedPeptide(name: "BPC-157", startKey: "2026-11-01")
        withBatch.batchExpiryKey = "2026-12-01"
        expect(withBatch.isValid && withBatch.batchExpiryOffset(from: "2026-11-04") == 27, "Batch expiry is tracked as a civil day offset")
        withBatch.batchExpiryKey = "2026-13-40"
        expect(!withBatch.isValid, "Invalid batch expiry keys are rejected")
        let ref = Peptide.reference(for: "Semaglutide")
        expect(ref.researchAttention >= 90 && Peptide.reference(for: "Unknown blend").practicalUse <= 40, "Reference bands cover known and custom peptides")
        expect(PeptideReference.disclaimer.lowercased().contains("not medical advice"), "Reference copy stays non-clinical")

        // Slots, adherence and next dose
        let peptides = [daily, weekly, interval, paused]
        var logs = [
            DoseLog(peptideID: daily.id, dayKey: "2026-11-04", scheduledTime: morning, takenAt: now.addingTimeInterval(-4 * 3600), amount: 250, unit: .mcg, site: .abdomenLeft),
            DoseLog(peptideID: weekly.id, dayKey: "2026-11-04", scheduledTime: morning, status: .skipped, takenAt: now.addingTimeInterval(-3 * 3600)),
            DoseLog(peptideID: interval.id, dayKey: "2026-11-04", takenAt: now.addingTimeInterval(-3600)),
        ]
        let today = ProtocolSchedule.slots(on: "2026-11-04", peptides: peptides, logs: logs)
        expect(today.count == 5, "Today lists every scheduled time plus extra doses")
        expect(today.filter(\.isExtra).count == 1 && today.first(where: \.isExtra)?.peptide.id == interval.id, "An unscheduled log appears as an extra dose")
        expect(today.first { $0.peptide.id == interval.id && !$0.isExtra }?.log == nil, "An extra dose does not answer a scheduled slot")
        expect(today.first?.time == morning && today.last?.time == evening, "Slots are ordered by time")
        expect(today.first { $0.peptide.id == daily.id && $0.time == morning }?.isTaken == true, "Logs match their scheduled slot")

        let week = ProtocolSchedule.adherence(from: "2026-11-01", to: "2026-11-04", peptides: peptides, logs: logs, now: now, timeZone: zone)
        // Daily: 3 days × 2 times + today's morning = 7; weekly: Wednesday morning = 1; interval: 1st and 4th = 2.
        expect(week.due == 10 && week.taken == 1 && week.skipped == 1 && week.unlogged == 8, "Adherence counts only slots whose time has passed")
        expect(ProtocolSchedule.adherence(from: "2026-11-05", to: "2026-11-01", peptides: peptides, logs: logs, now: now).due == 0, "An inverted range counts nothing")
        expect(Adherence().fraction == nil, "No due doses means no adherence score, not zero")

        let next = ProtocolSchedule.nextDose(after: now, peptides: peptides, logs: logs, timeZone: zone)
        expect(next?.slot.peptide.id == daily.id && next?.slot.time == evening, "The next dose is the first unanswered future slot")
        logs.append(DoseLog(peptideID: daily.id, dayKey: "2026-11-04", scheduledTime: evening, takenAt: now))
        let tomorrow = ProtocolSchedule.nextDose(after: now, peptides: peptides, logs: logs, timeZone: zone)
        expect(tomorrow?.slot.dayKey == "2026-11-05" && tomorrow?.slot.time == morning, "An early log moves the next dose to tomorrow")
        expect(ProtocolSchedule.nextDose(after: now, peptides: [paused], logs: [], timeZone: zone) == nil, "A paused protocol has no next dose")

        expect(ProtocolSchedule.lastSite(for: daily.id, logs: logs) == .abdomenLeft, "The last injection site is remembered")
        expect(ProtocolSchedule.suggestedSite(after: .abdomenLeft) == .abdomenRight && ProtocolSchedule.suggestedSite(after: .gluteRight) == .abdomenLeft, "Site rotation cycles through every site")
        expect(ProtocolSchedule.suggestedSite(after: nil) == .abdomenLeft, "The first site defaults to the start of the cycle")
        let heat = ProtocolSchedule.siteHeat(logs: logs, peptideID: daily.id)
        expect(heat.count(for: .abdomenLeft) == 1 && heat.intensity(for: .abdomenLeft) == 1, "Site heat reflects logged pin locations")
        expect(InjectionSite.gluteLeft.isBack && !InjectionSite.abdomenLeft.isBack, "Glute sites sit on the back face of the body map")

        expect(!DoseLog(peptideID: daily.id, dayKey: "2026-11-09", takenAt: now).isValid(now: now), "Future dose days are rejected")
        expect(!DoseLog(peptideID: daily.id, dayKey: "2026-11-04", takenAt: now, note: String(repeating: "a", count: 501)).isValid(now: now), "Oversized dose notes are rejected")

        // Persistence and backup
        var journal = Journal()
        journal.startDate = now.addingTimeInterval(-86400 * 10)
        journal.peptides = [daily, weekly, interval]
        journal.doseLogs = logs
        let stored = try JSONDecoder().decode(Journal.self, from: try JSONEncoder().encode(journal))
        expect(stored.peptides == journal.peptides && stored.doseLogs == journal.doseLogs, "Protocols survive the journal file round trip")
        let legacy = try JSONDecoder().decode(Journal.self, from: try JSONEncoder().encode(Journal()))
        expect(legacy.peptides == nil && legacy.doseLogs == nil, "Journals saved before the tracker still open")

        let archive = try JournalBackup.make(from: journal, now: now, timeZone: zone)
        let data = try archive.encoded(now: now)
        let restored = try JournalBackup.decode(data, now: now).restoring(into: Journal(), now: now)
        expect(restored.peptides == journal.peptides && restored.doseLogs == journal.doseLogs, "Backups preserve peptides and every dose")

        let raw = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        func rejectContent(_ name: String, _ change: (inout [String: Any]) -> Void) {
            rejects(name) {
                var value = raw, body = value["content"] as! [String: Any]
                change(&body); value["content"] = body
                _ = try JournalBackup.decode(try JSONSerialization.data(withJSONObject: value), now: now)
            }
        }
        func editPeptide(_ change: @escaping (inout [String: Any]) -> Void) -> (inout [String: Any]) -> Void {
            { body in var list = body["peptides"] as! [[String: Any]]; change(&list[0]); body["peptides"] = list }
        }
        func editLog(_ change: @escaping (inout [String: Any]) -> Void) -> (inout [String: Any]) -> Void {
            { body in var list = body["doseLogs"] as! [[String: Any]]; change(&list[0]); body["doseLogs"] = list }
        }
        rejectContent("unknown peptide field", editPeptide { $0["recommendedDose"] = 5 })
        rejectContent("unknown schedule field", editPeptide { var s = $0["schedule"] as! [String: Any]; s["cycle"] = 8; $0["schedule"] = s })
        rejectContent("invalid schedule", editPeptide { var s = $0["schedule"] as! [String: Any]; s["times"] = []; $0["schedule"] = s })
        rejectContent("duplicate weekdays", editPeptide { var s = $0["schedule"] as! [String: Any]; s["weekdays"] = [2, 2]; $0["schedule"] = s })
        rejectContent("unknown dose unit", editPeptide { $0["unit"] = "drops" })
        rejectContent("negative amount", editPeptide { $0["amount"] = -2 })
        rejectContent("orphaned dose", editLog { $0["peptideID"] = UUID().uuidString })
        rejectContent("unknown injection site", editLog { $0["site"] = "elbow" })
        rejectContent("future dose", editLog { $0["dayKey"] = "2026-12-01" })
        rejectContent("duplicate dose ID") { body in
            var list = body["doseLogs"] as! [[String: Any]]
            list[1]["id"] = list[0]["id"]; body["doseLogs"] = list
        }
        rejectContent("a slot answered twice") { body in
            var list = body["doseLogs"] as! [[String: Any]]
            var copy = list[0]; copy["id"] = UUID().uuidString; list.append(copy); body["doseLogs"] = list
        }
        rejectContent("sample doses in a real archive") { body in
            var list = body["doseLogs"] as! [[String: Any]]
            list[0]["isSample"] = true; body["doseLogs"] = list
        }
        print("PASS: \(checks) protocol checks")
    }
}
