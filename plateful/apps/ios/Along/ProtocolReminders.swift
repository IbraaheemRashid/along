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
    var reminderSources: [DoseReminderSource] { protocolPeptides.compactMap(\.reminderSource) }
    var batchExpiryReminderSources: [BatchExpiryReminderSource] {
        protocolPeptides.compactMap(\.batchExpiryReminderSource)
    }
}
