import Foundation

/// A user-controlled, readable local archive. This format deliberately excludes
/// onboarding access flags, credentials and subscription/entitlement state.
struct JournalBackup: Codable, Equatable {
    static let maximumBytes = 5 * 1024 * 1024
    static let maximumRecords = 10_000
    static let maximumCredits = 50_000
    static let currentSchema = 2
    private static let signature = "along-local-journal"

    let format: String
    let schemaVersion: Int
    let exportedAt: Date
    let timeZoneID: String
    let content: Content

    struct Content: Codable, Equatable {
        var journalVersion: Int
        var name: String
        var companionName: String
        var routines: Set<Routine>
        var checkIns: [CheckIn]
        var milestones: [Milestone]
        var weights: [WeightEntry]
        var weightUnit: WeightUnit
        var showWeight: Bool
        var accessory: Accessory
        var unlockedAccessories: Set<Accessory>
        var hasSampleData: Bool
        var startDate: Date
        var onboardingPreferences: OnboardingDraft?
        var setupProfile: SetupDraft?
        var companionDiscoveries: [String: String]?
        var pipProgress: PipProgress?
        var routineDays: [RoutineDay]?
        var peptides: [TrackedPeptide]?
        var requestedPeptides: [String]?
        var doseLogs: [DoseLog]?

        init(_ journal: Journal) {
            journalVersion = journal.version
            name = journal.name; companionName = journal.companionName
            routines = journal.routines; checkIns = journal.checkIns
            milestones = journal.milestones; weights = journal.weights
            weightUnit = journal.weightUnit; showWeight = journal.showWeight
            accessory = journal.accessory; unlockedAccessories = journal.unlockedAccessories
            hasSampleData = journal.hasSampleData; startDate = journal.startDate
            onboardingPreferences = journal.onboardingPreferences
            setupProfile = journal.setupProfile
            companionDiscoveries = journal.companionDiscoveries
            pipProgress = journal.pipProgress; routineDays = journal.routineDays
            requestedPeptides = journal.requestedPeptides
            peptides = journal.peptides; doseLogs = journal.doseLogs
        }
    }

    enum Failure: Error { case invalidArchive, unsupportedVersion, tooLarge, sampleArchive, unreadableFile }

    static var allowsSamples: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    static func make(from journal: Journal, now: Date = .now, timeZone: TimeZone = .current) throws -> JournalBackup {
        var normalized = journal
        normalized.normalizeDayKeys(sourceTimeZone: journal.legacyDayTimeZone(fallback: timeZone))
        let backup = JournalBackup(format: signature, schemaVersion: currentSchema,
                                   exportedAt: now, timeZoneID: timeZone.identifier, content: Content(normalized))
        try backup.validate(now: now)
        return backup
    }

    func encoded(now: Date = .now) throws -> Data {
        try validate(now: now)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        // Foundation's default date representation retains subsecond precision
        // using the same date representation as the local journal format.
        let data = try encoder.encode(self)
        guard data.count <= Self.maximumBytes else { throw Failure.tooLarge }
        return data
    }

    static func decode(_ data: Data, now: Date = .now) throws -> JournalBackup {
        guard !data.isEmpty, data.count <= maximumBytes else { throw Failure.tooLarge }
        do {
            try validateShape(data)
            let backup = try JSONDecoder().decode(Self.self, from: data)
            try backup.validate(now: now)
            // Old archives have a known source timezone. Stamp missing keys
            // before the journal reaches a device with a different timezone.
            let normalized = try backup.restoring(into: Journal(), now: now)
            return Self(format: backup.format, schemaVersion: currentSchema, exportedAt: backup.exportedAt,
                        timeZoneID: backup.timeZoneID, content: Content(normalized))
        } catch let failure as Failure { throw failure }
        catch { throw Failure.invalidArchive }
    }

    /// Revalidate at the final confirmation, preserving the destination's access
    /// flags even if the archive came from a subscribed or development device.
    func restoring(into current: Journal, now: Date = .now) throws -> Journal {
        try validate(now: now)
        var restored = Journal()
        restored.version = content.journalVersion
        restored.name = content.name; restored.companionName = content.companionName
        restored.routines = content.routines; restored.checkIns = content.checkIns
        restored.milestones = content.milestones; restored.weights = content.weights
        restored.weightUnit = content.weightUnit; restored.showWeight = content.showWeight
        restored.accessory = content.accessory; restored.unlockedAccessories = content.unlockedAccessories
        restored.hasSampleData = content.hasSampleData; restored.startDate = content.startDate
        restored.onboardingPreferences = content.onboardingPreferences
        restored.setupProfile = content.setupProfile
        restored.companionDiscoveries = content.companionDiscoveries
        restored.pipProgress = content.pipProgress; restored.routineDays = content.routineDays
        restored.requestedPeptides = content.requestedPeptides
        restored.peptides = content.peptides; restored.doseLogs = content.doseLogs
        restored.hasOnboarded = current.hasOnboarded
        restored.isDesignPreview = current.isDesignPreview
        restored.normalizeDayKeys(sourceTimeZone: TimeZone(identifier: timeZoneID)!)
        return restored
    }

    /// Bounded even if file metadata is missing, stale or describes a provider.
    static func read(from url: URL, now: Date = .now) throws -> JournalBackup {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true else { throw Failure.unreadableFile }
            if let size = values.fileSize, size > maximumBytes { throw Failure.tooLarge }
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            var data = Data()
            while data.count <= maximumBytes {
                let remaining = maximumBytes + 1 - data.count
                guard let chunk = try handle.read(upToCount: min(65_536, remaining)), !chunk.isEmpty else { break }
                data.append(chunk)
            }
            return try decode(data, now: now)
        } catch let failure as Failure { throw failure }
        catch { throw Failure.unreadableFile }
    }

    private func validate(now: Date) throws {
        guard format == Self.signature else { throw Failure.invalidArchive }
        guard [1, Self.currentSchema].contains(schemaVersion), content.journalVersion == 1 else { throw Failure.unsupportedVersion }
        guard let timeZone = TimeZone(identifier: timeZoneID), timeZoneID.count <= 100 else { throw Failure.invalidArchive }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        // Earliest possible instant of the supported 1900-01-01 civil date.
        let lowerBound = Date(timeIntervalSince1970: -2_208_988_800 - 14 * 3600)
        guard now.timeIntervalSinceReferenceDate.isFinite,
              let upperBound = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else { throw Failure.invalidArchive }
        func validDate(_ date: Date) -> Bool {
            date.timeIntervalSinceReferenceDate.isFinite && date >= lowerBound && date < upperBound
        }
        func recordKey(_ stored: String?, _ date: Date) -> String? {
            guard let key = DayIdentity.resolved(stored, rawDate: date, sourceTimeZone: timeZone),
                  JournalValidation.storedRecordDate(date, key: stored, now: now, sourceTimeZone: timeZone) else { return nil }
            return key
        }
        func validText(_ value: String, limit: Int, required: Bool = false) -> Bool {
            JournalValidation.text(value, limit: limit, required: required)
        }
        guard validDate(exportedAt), exportedAt <= now.addingTimeInterval(300), validDate(content.startDate),
              validText(content.name, limit: 30), validText(content.companionName, limit: 24),
              content.unlockedAccessories.contains(.leaf), content.unlockedAccessories.contains(content.accessory),
              content.checkIns.count <= Self.maximumRecords, content.weights.count <= Self.maximumRecords,
              content.milestones.count <= Self.maximumRecords, (content.routineDays?.count ?? 0) <= Self.maximumRecords else { throw Failure.invalidArchive }

        if let requests = content.requestedPeptides {
            guard requests.count <= Self.maximumRecords,
                  requests.allSatisfy({ SetupDraft.validCompound($0) && $0 == $0.trimmingCharacters(in: .whitespacesAndNewlines) }),
                  Set(requests.map { $0.lowercased() }).count == requests.count else { throw Failure.invalidArchive }
        }
        var identifiers = Set<UUID>()
        var checkInDays = Set<String>(), weightDays = Set<String>(), routineDays = Set<String>()
        func unique(_ id: UUID) -> Bool { identifiers.insert(id).inserted }
        for entry in content.checkIns {
            guard unique(entry.id), let key = recordKey(entry.dayKey, entry.day), validText(entry.note, limit: 500),
                  checkInDays.insert(key).inserted else { throw Failure.invalidArchive }
        }
        for entry in content.weights {
            guard unique(entry.id), let key = recordKey(entry.dateKey, entry.date), JournalValidation.weight(entry.kilograms),
                  weightDays.insert(key).inserted else { throw Failure.invalidArchive }
        }
        for entry in content.milestones {
            guard unique(entry.id), recordKey(entry.dateKey, entry.date) != nil, validText(entry.title, limit: 80, required: true),
                  validText(entry.note, limit: 300) else { throw Failure.invalidArchive }
        }
        for entry in content.routineDays ?? [] {
            guard unique(entry.id), let key = recordKey(entry.dayKey, entry.day),
                  routineDays.insert(key).inserted else { throw Failure.invalidArchive }
        }
        guard checkInDays.isDisjoint(with: routineDays) else { throw Failure.invalidArchive }

        let peptides = content.peptides ?? [], doseLogs = content.doseLogs ?? []
        guard peptides.count <= TrackedPeptide.limit, doseLogs.count <= DoseLog.limit else { throw Failure.invalidArchive }
        var peptideIDs = Set<UUID>()
        for peptide in peptides {
            guard unique(peptide.id), peptide.isValid else { throw Failure.invalidArchive }
            peptideIDs.insert(peptide.id)
        }
        var answeredSlots = Set<String>()
        for log in doseLogs {
            guard unique(log.id), peptideIDs.contains(log.peptideID), log.isValid(now: now), validDate(log.takenAt) else { throw Failure.invalidArchive }
            if let time = log.scheduledTime {
                guard answeredSlots.insert("\(log.peptideID)|\(log.dayKey)|\(time.minutes)").inserted else { throw Failure.invalidArchive }
            }
        }

        let containsSamples = content.checkIns.contains(where: \.isSample) || content.weights.contains(where: \.isSample)
            || content.milestones.contains(where: \.isSample) || (content.routineDays ?? []).contains(where: \.isSample)
            || peptides.contains(where: \.isSample) || doseLogs.contains(where: \.isSample)
        guard !containsSamples || content.hasSampleData else { throw Failure.invalidArchive }
        guard Self.allowsSamples || (!content.hasSampleData && !containsSamples) else { throw Failure.sampleArchive }

        if let draft = content.onboardingPreferences {
            guard draft.isValidForPersistence, validDate(draft.startDate),
                  !draft.showWeight || draft.weightValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.baselineKilograms != nil else { throw Failure.invalidArchive }
        }
        if let profile = content.setupProfile {
            guard profile.isValid, validDate(profile.birthDate) else { throw Failure.invalidArchive }
        }
        if let discoveries = content.companionDiscoveries {
            guard discoveries.count <= PipStory.all.count else { throw Failure.invalidArchive }
            for (id, choice) in discoveries {
                guard PipStory.all.contains(where: { $0.id == id && $0.choices.contains(where: { $0.id == choice }) }) else { throw Failure.invalidArchive }
            }
        }
        if let progress = content.pipProgress {
            guard TimeZone(identifier: progress.timeZoneID) != nil, progress.timeZoneID.count <= 100,
                  progress.recordedDays.count <= Self.maximumRecords, progress.creditedEntries.count <= Self.maximumCredits,
                  progress.recordedDays.count <= progress.creditedEntries.count else { throw Failure.invalidArchive }
            for key in progress.recordedDays {
                guard DayIdentity.isNotFuture(key, now: now) else { throw Failure.invalidArchive }
            }
            // Legacy starter accessories are legitimate gifts, not earned days.
            for reward in progress.claimedRewards where progress.recordedDays.count < reward.requiredDays {
                guard let accessory = reward.accessory, content.unlockedAccessories.contains(accessory) else { throw Failure.invalidArchive }
            }
        }
    }

    /// Reject unknown fields rather than silently discarding a future format.
    /// Inspect sets before decoding because Codable Set would hide duplicates.
    private static func validateShape(_ data: Data) throws {
        guard let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Failure.invalidArchive }
        func object(_ value: Any?, required: Set<String>, optional: Set<String> = []) throws -> [String: Any] {
            guard let result = value as? [String: Any], required.isSubset(of: Set(result.keys)),
                  Set(result.keys).isSubset(of: required.union(optional)) else { throw Failure.invalidArchive }
            return result
        }
        func strings(_ value: Any?, lowercase: Bool = false) throws {
            guard let values = value as? [String], Set(values.map { lowercase ? $0.lowercased() : $0 }).count == values.count else { throw Failure.invalidArchive }
        }
        _ = try object(envelope, required: ["format", "schemaVersion", "exportedAt", "timeZoneID", "content"])
        let content = try object(envelope["content"], required: ["journalVersion", "name", "companionName", "routines", "checkIns", "milestones", "weights", "weightUnit", "showWeight", "accessory", "unlockedAccessories", "hasSampleData", "startDate"], optional: ["onboardingPreferences", "setupProfile", "companionDiscoveries", "pipProgress", "routineDays", "peptides", "doseLogs", "requestedPeptides"])
        try strings(content["routines"]); try strings(content["unlockedAccessories"])
        for (key, fields) in [
            ("checkIns", Set(["id", "day", "mood", "appetite", "routines", "note", "isSample"])),
            ("weights", Set(["id", "date", "kilograms", "isSample"])),
            ("milestones", Set(["id", "date", "title", "note", "kind", "isSample"])),
            ("routineDays", Set(["id", "day", "routines", "isSample"]))
        ] {
            if key == "routineDays" && content[key] == nil { continue }
            guard let entries = content[key] as? [Any], entries.count <= maximumRecords else { throw Failure.invalidArchive }
            for raw in entries {
                let dateField = fields.contains("day") ? "dayKey" : "dateKey"
                let entry = try object(raw, required: fields, optional: [dateField])
                if let rawKey = entry[dateField] {
                    guard let dateKey = rawKey as? String, DayIdentity.isValid(dateKey) else { throw Failure.invalidArchive }
                }
                if fields.contains("routines") { try strings(entry["routines"]) }
            }
        }
        if let raw = content["peptides"] {
            guard let entries = raw as? [Any], entries.count <= TrackedPeptide.limit else { throw Failure.invalidArchive }
            for entry in entries {
                let peptide = try object(entry, required: ["id", "name", "unit", "schedule", "startKey", "isPaused", "note", "isSample"], optional: ["amount", "batchExpiryKey", "colour"])
                if let rawKey = peptide["batchExpiryKey"] {
                    guard let key = rawKey as? String, DayIdentity.isValid(key) else { throw Failure.invalidArchive }
                }
                let schedule = try object(peptide["schedule"], required: ["kind", "weekdays", "intervalDays", "times"])
                guard let weekdays = schedule["weekdays"] as? [Int], Set(weekdays).count == weekdays.count,
                      let times = schedule["times"] as? [Any] else { throw Failure.invalidArchive }
                for time in times { _ = try object(time, required: ["hour", "minute"]) }
            }
        }
        if let raw = content["doseLogs"] {
            guard let entries = raw as? [Any], entries.count <= DoseLog.limit else { throw Failure.invalidArchive }
            for entry in entries {
                let log = try object(entry, required: ["id", "peptideID", "dayKey", "status", "takenAt", "unit", "note", "isSample"], optional: ["scheduledTime", "amount", "site", "spot"])
                if let time = log["scheduledTime"] { _ = try object(time, required: ["hour", "minute"]) }
                if let spot = log["spot"] {
                    guard let id = spot as? String, InjectionSpot(id: id) != nil else { throw Failure.invalidArchive }
                }
            }
        }
        if let raw = content["onboardingPreferences"] {
            let draft = try object(raw, required: ["step", "name", "stage", "hasStartDate", "startDate", "priority", "obstacle", "progressAreas", "intention", "showWeight", "weightValue", "weightUnit", "routines", "routineNames", "frequency", "reminder", "reflectionDay", "encouragement", "accessory", "companionName", "note", "plan"], optional: ["mood", "appetite"])
            try strings(draft["progressAreas"]); try strings(draft["routines"])
        }
        if let raw = content["setupProfile"] {
            let profile = try object(raw, required: [], optional: Set(SetupDraft.CodingKeys.allCases.map(\.rawValue)))
            if profile["goals"] != nil { try strings(profile["goals"]) }
            if profile["obstacles"] != nil { try strings(profile["obstacles"]) }
            if profile["compounds"] != nil { try strings(profile["compounds"], lowercase: true) }
        }
        if let raw = content["pipProgress"] {
            let progress = try object(raw, required: ["timeZoneID", "recordedDays", "creditedEntries", "claimedRewards"])
            try strings(progress["recordedDays"]); try strings(progress["creditedEntries"], lowercase: true); try strings(progress["claimedRewards"])
        }
    }
}
