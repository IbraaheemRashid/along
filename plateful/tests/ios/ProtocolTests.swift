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

        // Colours
        expect((8...10).contains(PeptideColor.allCases.count), "A small, distinct set of swatches")
        expect(Set(PeptideColor.allCases.map { "\($0.rgb)" }).count == PeptideColor.allCases.count, "Every swatch is a different colour")
        // The exact tints PeptideBadge.tint(for:) used before colours were editable.
        let legacyTints: [(String, (Double, Double, Double))] = [
            ("GLP-1", (0.42, 0.62, 0.93)), ("GLP-1 / GIP", (0.42, 0.62, 0.93)), ("Recovery", (0.36, 0.72, 0.56)),
            ("Skin", (0.93, 0.55, 0.62)), ("GH secretagogue", (0.66, 0.55, 0.85)), ("Longevity", (0.93, 0.65, 0.36)),
            ("Metabolic", (0.93, 0.65, 0.36)), ("Cognitive", (0.45, 0.52, 0.85)), ("Sleep", (0.45, 0.52, 0.85)),
            ("Immune", (0.6, 0.6, 0.65)), ("Custom", (0.6, 0.6, 0.65)),
        ]
        for (category, tint) in legacyTints {
            let rgb = PeptideColor.default(for: category).rgb
            expect(rgb.red == tint.0 && rgb.green == tint.1 && rgb.blue == tint.2, "\(category) keeps its original tint")
        }
        expect(PeptideColor.default(for: "Unknown") == .graphite, "Uncategorised peptides default to graphite")
        let legacyJSON = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"BPC-157","unit":"mcg","schedule":{"kind":"daily","weekdays":[],"intervalDays":2,"times":[{"hour":8,"minute":0}]},"startKey":"2026-11-01","isPaused":false,"note":"","isSample":false}"#
        let legacyPeptide = try JSONDecoder().decode(TrackedPeptide.self, from: Data(legacyJSON.utf8))
        expect(legacyPeptide.color == nil && legacyPeptide.displayColor == .green, "Peptides saved before colours keep their category colour")
        var tealPeptide = TrackedPeptide(name: "BPC-157", startKey: "2026-11-01"); tealPeptide.color = .teal
        let tealRoundTrip = try JSONDecoder().decode(TrackedPeptide.self, from: JSONEncoder().encode(tealPeptide))
        expect(tealRoundTrip.color == .teal && tealRoundTrip.displayColor == .teal && tealRoundTrip.isValid, "A chosen colour survives a round trip and wins over the default")

        // Slots, adherence and next dose
        let peptides = [daily, weekly, interval, paused]
        var logs = [
            DoseLog(peptideID: daily.id, dayKey: "2026-11-04", scheduledTime: morning, takenAt: now.addingTimeInterval(-4 * 3600), amount: 250, unit: .mcg, site: .abdomenLeft, spot: InjectionSpot(id: "abdomen.left.lower.2")),
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

        // Exact spots from the 3D picker
        expect(InjectionSpot.all.count == 52, "The picker offers 16 abdomen spots and 36 sided spots")
        expect(Set(InjectionSpot.all.map(\.id)).count == InjectionSpot.all.count, "Spot ids are unique")
        expect(InjectionSpot.all.allSatisfy { InjectionSpot(id: $0.id) == $0 }, "Every spot id round-trips")
        for bad in ["", "abdomen.left.3", "abdomen.left.middle.1", "ventroglute.left.lower.1", "ventroglute.up.1", "ventroglute.left.4",
                    "ventroglute.left.0", "ventroglute.left.02", "elbow.left.1", "delt.left.1.extra"] {
            expect(InjectionSpot(id: bad) == nil, "Rejects spot id '\(bad)'")
        }
        let lowerLeft = InjectionSpot(id: "abdomen.left.lower.3")!
        expect(lowerLeft.title == "Abdomen · Lower left · Spot 3" && lowerLeft.shortTitle == "L abdomen, lower #3", "Abdomen spots name their quadrant")
        let vg = InjectionSpot(id: "ventroglute.right.2")!
        expect(vg.title == "Ventroglute · Right · Spot 2" && vg.shortTitle == "R ventroglute #2" && vg.areaID == "ventroglute.right", "Sided spots name their side")
        expect(lowerLeft.legacySite == .abdomenLeft && vg.legacySite == .gluteRight && InjectionSpot(id: "tricep.left.1")!.legacySite == .armLeft,
               "Spots map onto the original eight sites")
        expect(try JSONDecoder().decode(InjectionSpot.self, from: try JSONEncoder().encode(vg)) == vg, "Spots encode as their id")
        expect(ProtocolSchedule.lastSpot(for: daily.id, logs: logs)?.id == "abdomen.left.lower.2", "The last exact spot is remembered")
        let spotHeat = ProtocolSchedule.spotHeat(logs: logs, peptideID: daily.id)
        expect(spotHeat.count(for: InjectionSpot(id: "abdomen.left.lower.2")!) == 1 && spotHeat.count(for: lowerLeft) == 0, "Spot heat counts exact spots")
        expect(spotHeat.historyText(for: lowerLeft, now: now) == "Not in your recent logs", "Unused spots read as not recent, never as advice")

        // Health analytics (pure; no HealthKit)
        expect(HealthAnalytics.recoveryScore(sleep: 8, hrv: 80, resting: 50) == 100, "Ideal recovery inputs saturate at 100")
        expect(HealthAnalytics.activityScore(steps: 5_000, energy: 250, exercise: 15).map { abs($0 - 50) < 0.1 } == true, "Half-target activity lands near 50")
        let rising = HealthAnalytics.project([40, 50, 60, 70], startKey: "2026-11-04", days: 3)
        expect(rising.end.map { $0 > 70 } == true && rising.points.count == 3, "Projection continues an upward series")
        let preview = HealthAnalytics.previewSnapshot(todayKey: "2026-11-22", days: 14)
        expect(preview.days.count == 14 && preview.hasAnyMetric, "Preview Health snapshots fill wearable-style series")
        let insight = HealthAnalytics.insight(from: preview, goals: [.weightLoss], window: 14, todayKey: "2026-11-22")
        expect(insight.overallScore != nil && !insight.series.isEmpty, "Insights blend activity and recovery into chart series")
        expect(insight.headline.lowercased().contains("weight") || insight.detail.lowercased().contains("preview"), "Goal-aware copy stays non-clinical")

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
        let archivedPeptides = ((try JSONSerialization.jsonObject(with: data) as! [String: Any])["content"] as! [String: Any])["peptides"] as! [[String: Any]]
        expect(archivedPeptides.allSatisfy { $0["color"] == nil } && restored.peptides?.allSatisfy { $0.color == nil } == true,
               "A backup without colours (as made before this change) imports and keeps following defaults")
        var coloured = journal; coloured.peptides?[1].color = .yellow
        let colouredRestored = try JournalBackup.decode(try JournalBackup.make(from: coloured, now: now, timeZone: zone).encoded(now: now), now: now)
            .restoring(into: Journal(), now: now)
        expect(colouredRestored.peptides?[1].color == .yellow && colouredRestored.peptides?[0].color == nil, "Backups preserve chosen colours")

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
        rejectContent("unknown peptide colour", editPeptide { $0["color"] = "chartreuse" })
        rejectContent("non-string peptide colour", editPeptide { $0["color"] = 3 })
        rejectContent("orphaned dose", editLog { $0["peptideID"] = UUID().uuidString })
        rejectContent("unknown injection site", editLog { $0["site"] = "elbow" })
        rejectContent("unknown injection spot", editLog { $0["spot"] = "abdomen.left.middle.1" })
        rejectContent("non-string injection spot", editLog { $0["spot"] = 4 })
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
