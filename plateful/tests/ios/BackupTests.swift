import Foundation

@main struct BackupTests {
    static func main() throws {
        let now = ISO8601DateFormatter().date(from: "2026-11-01T12:00:00Z")!
        let zone = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = zone
        var checks = 0
        func expect(_ condition: Bool, _ message: String) { precondition(condition, message); checks += 1 }
        func rejects(_ name: String, _ action: () throws -> Void) {
            do { try action(); preconditionFailure("Expected rejection: \(name)") }
            catch { checks += 1 }
        }
        var original = Journal()
        original.startDate = now.addingTimeInterval(-86400 * 30)
        original.name = "Alex"; original.companionName = "Pip"
        original.hasOnboarded = true; original.isDesignPreview = true
        original.checkIns = [CheckIn(day: now, mood: .steady, appetite: .comfortable, routines: [.nutrition], note: "Private note 🌿\nA second line.")]
        original.weights = [WeightEntry(date: now, kilograms: 80.125)]
        original.milestones = [Milestone(date: now, title: "A walk with a friend", note: "At my own pace", kind: .everyday)]
        original.routineDays = [RoutineDay(day: now.addingTimeInterval(-86400), routines: [.movement])]
        original.companionDiscoveries = ["window": "rain"]
        var preferences = OnboardingDraft()
        preferences.startDate = now; preferences.name = "Alex"; preferences.note = "My first page"
        preferences.routineNames = ["movement": "My own movement"]
        original.onboardingPreferences = preferences
        original.reconcileProgress(now: now)
        original.pipProgress?.timeZoneID = zone.identifier
        original.pipProgress?.claimedRewards.insert(.notebook)
        let archive = try JournalBackup.make(from: original, now: now, timeZone: zone)
        let data = try archive.encoded(now: now)
        let decoded = try JournalBackup.decode(data, now: now)
        expect(decoded == archive, "All archive values survive encode/decode, including exact dates and Unicode")
        var destination = Journal(); destination.hasOnboarded = false; destination.isDesignPreview = nil
        let restored = try decoded.restoring(into: destination, now: now)
        expect(!restored.hasOnboarded && restored.isDesignPreview == nil, "Import cannot grant onboarding or development access")
        expect(restored.checkIns == original.checkIns && restored.weights == original.weights && restored.milestones == original.milestones, "Restore preserves records and identity")
        expect(restored.routineDays == original.routineDays && restored.pipProgress == original.pipProgress && restored.companionDiscoveries == original.companionDiscoveries, "Restore preserves routines and cumulative pet history")
        expect(restored.onboardingPreferences == preferences, "Restore preserves routine wording and preferences")
        destination.hasOnboarded = true; destination.isDesignPreview = false
        let completedDestination = try decoded.restoring(into: destination, now: now)
        expect(completedDestination.hasOnboarded && completedDestination.isDesignPreview == false, "Import preserves the destination's existing access flags")

        let raw = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let payload = raw["content"] as! [String: Any]
        expect(payload["hasOnboarded"] == nil && payload["isDesignPreview"] == nil && payload["entitlements"] == nil && payload["token"] == nil, "Export format contains no access flags or credentials")
        func modified(_ change: (inout [String: Any]) -> Void) throws -> Data {
            var value = raw; change(&value)
            return try JSONSerialization.data(withJSONObject: value)
        }
        func modifiedContent(_ change: (inout [String: Any]) -> Void) throws -> Data {
            try modified { value in var body = value["content"] as! [String: Any]; change(&body); value["content"] = body }
        }
        func rejectContent(_ name: String, _ change: (inout [String: Any]) -> Void) {
            rejects(name) { _ = try JournalBackup.decode(try modifiedContent(change), now: now) }
        }
        rejects("unsupported envelope schema") { _ = try JournalBackup.decode(try modified { $0["schemaVersion"] = 2 }, now: now) }
        rejects("incorrect archive signature") { _ = try JournalBackup.decode(try modified { $0["format"] = "other-app" }, now: now) }
        rejects("invalid timezone") { _ = try JournalBackup.decode(try modified { $0["timeZoneID"] = "not/a/timezone" }, now: now) }
        rejects("future export time") { _ = try JournalBackup.decode(try modified { $0["exportedAt"] = now.addingTimeInterval(86400).timeIntervalSinceReferenceDate }, now: now) }
        rejects("unknown top-level field") { _ = try JournalBackup.decode(try modified { $0["entitlements"] = ["active": true] }, now: now) }
        rejectContent("unknown access-grant field") { $0["hasOnboarded"] = true }
        rejectContent("unsupported journal version") { $0["journalVersion"] = 2 }
        rejectContent("oversized name") { $0["name"] = String(repeating: "a", count: 31) }
        rejectContent("control character in name") { $0["name"] = "Alex\u{0000}" }
        rejectContent("unknown enum") { $0["weightUnit"] = "stone" }
        rejectContent("duplicate set values") { $0["routines"] = ["nutrition", "nutrition"] }
        rejectContent("wearing a locked item") { $0["accessory"] = "flower" }
        rejectContent("missing field") { $0.removeValue(forKey: "checkIns") }
        rejectContent("unknown story choice") { $0["companionDiscoveries"] = ["window": "unknown"] }
        rejectContent("unknown story") { $0["companionDiscoveries"] = ["unrecognised": "rain"] }
        rejectContent("duplicate record IDs") {
            var weights = $0["weights"] as! [[String: Any]]
            weights[0]["id"] = original.checkIns[0].id.uuidString
            $0["weights"] = weights
        }
        rejectContent("duplicate check-in date with different IDs") {
            var entries = $0["checkIns"] as! [[String: Any]]
            var duplicate = entries[0]; duplicate["id"] = UUID().uuidString
            duplicate["day"] = now.addingTimeInterval(3600).timeIntervalSinceReferenceDate
            entries.append(duplicate); $0["checkIns"] = entries
        }
        rejectContent("duplicate weight day") {
            var entries = $0["weights"] as! [[String: Any]]
            var duplicate = entries[0]; duplicate["id"] = UUID().uuidString
            entries.append(duplicate); $0["weights"] = entries
        }
        rejectContent("routine day collides with a check-in") {
            var entries = $0["routineDays"] as! [[String: Any]]
            entries[0]["day"] = now.timeIntervalSinceReferenceDate; $0["routineDays"] = entries
        }
        rejectContent("duplicate routine-only day") {
            var entries = $0["routineDays"] as! [[String: Any]]
            var duplicate = entries[0]; duplicate["id"] = UUID().uuidString
            entries.append(duplicate); $0["routineDays"] = entries
        }
        rejectContent("future record") {
            var entries = $0["checkIns"] as! [[String: Any]]
            entries[0]["day"] = now.addingTimeInterval(86400).timeIntervalSinceReferenceDate; $0["checkIns"] = entries
        }
        rejectContent("extreme date") {
            var entries = $0["checkIns"] as! [[String: Any]]
            entries[0]["day"] = 1e100; $0["checkIns"] = entries
        }
        rejectContent("oversized note") {
            var entries = $0["checkIns"] as! [[String: Any]]
            entries[0]["note"] = String(repeating: "a", count: 501); $0["checkIns"] = entries
        }
        rejectContent("negative weight") {
            var entries = $0["weights"] as! [[String: Any]]
            entries[0]["kilograms"] = -1; $0["weights"] = entries
        }
        rejectContent("invalid milestone") {
            var entries = $0["milestones"] as! [[String: Any]]
            entries[0]["title"] = "   "; $0["milestones"] = entries
        }
        rejectContent("unknown mood") {
            var entries = $0["checkIns"] as! [[String: Any]]
            entries[0]["mood"] = "perfect"; $0["checkIns"] = entries
        }
        rejectContent("invalid preference range") {
            var draft = $0["onboardingPreferences"] as! [String: Any]
            draft["reflectionDay"] = 8; $0["onboardingPreferences"] = draft
        }
        rejectContent("impossible progress day") {
            var ledger = $0["pipProgress"] as! [String: Any]
            ledger["recordedDays"] = ["2026-02-30"]; $0["pipProgress"] = ledger
        }
        rejectContent("future progress day") {
            var ledger = $0["pipProgress"] as! [String: Any]
            ledger["recordedDays"] = ["2026-11-02"]; $0["pipProgress"] = ledger
        }
        rejectContent("invalid progress timezone") {
            var ledger = $0["pipProgress"] as! [String: Any]
            ledger["timeZoneID"] = "unknown"; $0["pipProgress"] = ledger
        }
        rejectContent("invalid ledger UUID") {
            var ledger = $0["pipProgress"] as! [String: Any]
            ledger["creditedEntries"] = ["not-a-uuid"]; $0["pipProgress"] = ledger
        }
        rejectContent("duplicate progress day") {
            var ledger = $0["pipProgress"] as! [String: Any]
            ledger["recordedDays"] = ["2026-11-01", "2026-11-01"]; $0["pipProgress"] = ledger
        }
        rejectContent("duplicate ledger UUID with different casing") {
            var ledger = $0["pipProgress"] as! [String: Any]
            let id = UUID().uuidString; ledger["creditedEntries"] = [id, id.lowercased()]; $0["pipProgress"] = ledger
        }
        rejectContent("claimed room reward before its threshold") {
            var ledger = $0["pipProgress"] as! [String: Any]
            ledger["claimedRewards"] = ["stars"]; $0["pipProgress"] = ledger
        }
        rejectContent("sample records hidden by outer flag") {
            var entries = $0["checkIns"] as! [[String: Any]]
            entries[0]["isSample"] = true; $0["checkIns"] = entries
        }
        rejectContent("record count bound") {
            $0["checkIns"] = Array(repeating: (payload["checkIns"] as! [[String: Any]])[0], count: JournalBackup.maximumRecords + 1)
        }
        rejects("oversized raw archive") { _ = try JournalBackup.decode(Data(repeating: 32, count: JournalBackup.maximumBytes + 1), now: now) }
        rejects("empty file") { _ = try JournalBackup.decode(Data(), now: now) }
        rejects("truncated archive") { _ = try JournalBackup.decode(data.prefix(data.count / 2), now: now) }
        rejects("raw local journal is not a backup") { _ = try JournalBackup.decode(JSONEncoder().encode(original), now: now) }
        rejects("nonfinite weight") {
            let invalid = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "80.125", with: "1e309")
            _ = try JournalBackup.decode(Data(invalid.utf8), now: now)
        }

        var legacy = Journal(); legacy.startDate = now
        let legacyArchive = try JournalBackup.make(from: legacy, now: now, timeZone: zone)
        let legacyRestored = try JournalBackup.decode(legacyArchive.encoded(now: now), now: now).restoring(into: destination, now: now)
        expect(legacyRestored.pipProgress == nil && legacyRestored.routineDays == nil, "Optional legacy fields remain valid without fabricating progress")
        var gifted = original; gifted.unlockedAccessories.insert(.flower); gifted.pipProgress?.claimedRewards.insert(.flower)
        expect(try JournalBackup.make(from: gifted, now: now, timeZone: zone).content.unlockedAccessories.contains(.flower), "A legacy starter gift remains usable without enough earned days")
        var removedRecords = original; removedRecords.checkIns = []; removedRecords.routineDays = []
        let retainedLedger = try JournalBackup.make(from: removedRecords, now: now, timeZone: zone)
        expect(retainedLedger.content.pipProgress == original.pipProgress, "Deleting source records does not make permanent earned progress unrestorable")
        var largeJournal = Journal(); largeJournal.startDate = now
        largeJournal.checkIns = (0..<3000).map { offset in
            CheckIn(day: now.addingTimeInterval(-86400 * Double(offset)), mood: .steady, appetite: .comfortable,
                    routines: [], note: String(repeating: "🌿", count: 500))
        }
        rejects("export size limit includes multibyte text") {
            _ = try JournalBackup.make(from: largeJournal, now: now, timeZone: zone).encoded(now: now)
        }
        let sample = Journal.sample(now: now, calendar: calendar)
        #if DEBUG
        let sampleArchive = try JournalBackup.make(from: sample, now: now, timeZone: zone)
        expect(try JournalBackup.decode(sampleArchive.encoded(now: now), now: now).content.hasSampleData, "Debug sample archives retain their sample flag")
        #else
        rejects("Release cannot export sample history") { _ = try JournalBackup.make(from: sample, now: now, timeZone: zone) }
        rejects("Release cannot import sample history") { _ = try JournalBackup.decode(try modifiedContent { $0["hasSampleData"] = true }, now: now) }
        #endif

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("along-backup-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("backup.json")
        try data.write(to: file)
        expect(try JournalBackup.read(from: file, now: now) == archive, "Bounded file reader accepts a saved archive")
        rejects("directory cannot be imported") { _ = try JournalBackup.read(from: folder, now: now) }
        try Data().write(to: file)
        let handle = try FileHandle(forWritingTo: file)
        try handle.truncate(atOffset: UInt64(JournalBackup.maximumBytes + 1)); try handle.close()
        rejects("oversized file is rejected before full read") { _ = try JournalBackup.read(from: file, now: now) }
        print("Backup checks passed: \(checks) (samples allowed: \(JournalBackup.allowsSamples))")
    }
}
