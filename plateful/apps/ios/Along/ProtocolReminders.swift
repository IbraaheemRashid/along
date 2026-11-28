import Foundation

extension TrackedPeptide {
    var reminderSource: DoseReminderSource? {
        guard !isPaused, schedule.isValid else { return nil }
        let cadence: DoseReminderSource.Cadence
        switch schedule.kind {
        case .unscheduled: return nil
        case .daily: cadence = .daily
        case .weekdays: cadence = .weekdays(schedule.weekdays)
        case .interval: cadence = .interval(days: schedule.intervalDays, startKey: startKey)
        }
        return DoseReminderSource(id: id.uuidString.lowercased(), name: name, amountText: amountText,
                                  cadence: cadence, times: schedule.sortedTimes.map { DoseReminderSource.Time(hour: $0.hour, minute: $0.minute) },
                                  startKey: startKey)
    }

    var batchExpiryReminderSource: BatchExpiryReminderSource? {
        guard let batchExpiryKey, DayIdentity.isValid(batchExpiryKey) else { return nil }
        return BatchExpiryReminderSource(id: id.uuidString.lowercased(), name: name, expiryKey: batchExpiryKey)
    }
}

extension Journal {
    var batchExpiryReminderSources: [BatchExpiryReminderSource] {
        protocolPeptides.compactMap(\.batchExpiryReminderSource)
    }
}

extension JournalStore {
    var reminderProfile: String { accountID == nil ? "device" : storageDirectory.lastPathComponent }

    var reminderSources: [DoseReminderSource] {
        let day = todayKey
        var answers: [UUID: [String: Set<Int>]] = [:]
        for log in journal.protocolLogs where log.dayKey >= day {
            if let time = log.scheduledTime {
                answers[log.peptideID, default: [:]][log.dayKey, default: []].insert(time.minutes)
            }
        }
        return journal.protocolPeptides.compactMap { peptide in
            guard var source = peptide.reminderSource else { return nil }
            source.id = "\(reminderProfile)_\(source.id)"
            source.answeredMinutes = answers[peptide.id] ?? [:]
            return source
        }
    }
}
