import Foundation

extension TrackedPeptide {
    var reminderSource: DoseReminderSource? {
        guard !isPaused, schedule.isValid else { return nil }
        let cadence: DoseReminderSource.Cadence
        switch schedule.kind {
        case .daily: cadence = .daily
        case .weekdays: cadence = .weekdays(schedule.weekdays)
        case .interval: cadence = .interval(days: schedule.intervalDays, startKey: startKey)
        }
        return DoseReminderSource(id: id.uuidString.lowercased(), name: name, amountText: amountText,
                                  cadence: cadence, times: schedule.sortedTimes.map { DoseReminderSource.Time(hour: $0.hour, minute: $0.minute) })
    }
}

extension Journal {
    var reminderSources: [DoseReminderSource] { protocolPeptides.compactMap(\.reminderSource) }
}
