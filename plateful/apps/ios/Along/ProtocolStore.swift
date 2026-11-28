import Foundation

/// Protocol and dose actions. Every change goes through updateJournal so the
/// file is written before state is published.
extension JournalStore {
    var todayKey: String { DayIdentity.key(for: referenceDate) ?? "" }

    func slots(on dayKey: String) -> [DoseSlot] {
        ProtocolSchedule.slots(on: dayKey, peptides: journal.protocolPeptides, logs: journal.protocolLogs)
    }

    func peptide(_ id: UUID) -> TrackedPeptide? { journal.protocolPeptides.first { $0.id == id } }

    @discardableResult func savePeptide(_ peptide: TrackedPeptide, effectiveFrom: String? = nil) -> Bool {
        var item = peptide
        item.name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        item.note = item.note.trimmingCharacters(in: .whitespacesAndNewlines)
        item.schedule.times = Array(Set(item.schedule.times)).sorted()
        if item.schedule.kind != .weekdays { item.schedule.weekdays = [] }
        guard item.isValid else { error = "Add a name, a schedule with at least one time and, if you like, a dose above zero."; return false }
        let peptides = journal.protocolPeptides
        let existing = peptides.firstIndex { $0.id == item.id }
        if let existing {
            let old = peptides[existing]
            item.previousSchedules = old.previousSchedules
            if old.schedule != item.schedule || old.isPaused != item.isPaused || old.startKey != item.startKey {
                let day = effectiveFrom ?? todayKey
                var history = old.previousSchedules ?? []
                guard DayIdentity.isValid(day), day >= min(old.startKey, todayKey), day <= todayKey, history.last.map({ day >= $0.until }) ?? true else {
                    error = "Choose a date from the most recent schedule change through today."
                    return false
                }
                if history.last?.until != day {
                    guard history.count < 1024 else { error = "This protocol has reached its schedule history limit."; return false }
                    history.append(PreviousSchedule(until: day, startKey: old.startKey, schedule: old.schedule, isPaused: old.isPaused))
                }
                item.previousSchedules = history.isEmpty ? nil : history
                if old.schedule != item.schedule && item.schedule.kind == .interval && old.startKey == item.startKey && day >= old.startKey {
                    item.startKey = day
                }
            }
        }
        if peptides.contains(where: { $0.id != item.id && $0.name.caseInsensitiveCompare(item.name) == .orderedSame }) {
            error = "\(item.name) is already in your protocol."; return false
        }
        if existing == nil && peptides.count >= TrackedPeptide.limit {
            error = "A protocol can hold up to \(TrackedPeptide.limit) peptides."; return false
        }
        return updateJournal { value in
            var list = value.protocolPeptides
            if let existing { item.isSample = list[existing].isSample; list[existing] = item } else { list.append(item) }
            value.peptides = list
        }
    }

    @discardableResult func setPaused(_ id: UUID, _ paused: Bool) -> Bool {
        guard var item = peptide(id) else { return false }
        item.isPaused = paused
        return savePeptide(item)
    }

    /// Removes the peptide and its dose history. Pausing keeps history.
    @discardableResult func removePeptide(_ id: UUID) -> Bool {
        updateJournal { value in
            value.peptides?.removeAll { $0.id == id }
            value.doseLogs?.removeAll { $0.peptideID == id }
        }
    }

    /// One-tap answer to a scheduled slot, using the protocol's own amount.
    @discardableResult func logDose(_ slot: DoseSlot, status: DoseLog.Status = .taken, at moment: Date = .now) -> Bool {
        var log = slot.log ?? DoseLog(peptideID: slot.peptide.id, dayKey: slot.dayKey, scheduledTime: slot.time, takenAt: moment,
                                     amount: slot.peptide.amount, unit: slot.peptide.unit)
        log.status = status
        log.takenAt = min(moment, Date.now.addingTimeInterval(60))
        return saveDose(log)
    }

    @discardableResult func saveDose(_ log: DoseLog) -> Bool {
        var item = log
        item.note = item.note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard peptide(item.peptideID) != nil else { error = "This peptide is no longer in your protocol."; return false }
        guard item.isValid(now: .now) else { error = "Use a time no later than now and a note of up to \(DoseLog.noteLimit) characters."; return false }
        let logs = journal.protocolLogs
        if let time = item.scheduledTime,
           logs.contains(where: { $0.id != item.id && $0.peptideID == item.peptideID && $0.dayKey == item.dayKey && $0.scheduledTime == time }) {
            error = "That dose is already logged."; return false
        }
        if !logs.contains(where: { $0.id == item.id }) && logs.count >= DoseLog.limit {
            error = "Your dose history is full. Export a backup and remove older records to continue."; return false
        }
        return updateJournal { value in
            var list = value.protocolLogs
            if let index = list.firstIndex(where: { $0.id == item.id }) { item.isSample = list[index].isSample; list[index] = item } else { list.append(item) }
            value.doseLogs = list
        }
    }

    @discardableResult func removeDose(_ id: UUID) -> Bool {
        updateJournal { $0.doseLogs?.removeAll { $0.id == id } }
    }
}
