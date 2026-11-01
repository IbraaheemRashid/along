import Foundation

@main struct CoreTests {
    static func main() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = ISO8601DateFormatter().date(from: "2026-11-01T12:00:00Z")!
        var checks = 0
        func expect(_ condition: Bool, _ name: String) { precondition(condition, name); checks += 1 }
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
        expect(sample.checkIns.allSatisfy { !calendar.isDate($0.day, inSameDayAs: now) }, "Demo begins with today available for user's first action")
        expect(sample.checkIns.allSatisfy(\.isSample) && sample.milestones.allSatisfy(\.isSample) && sample.weights.allSatisfy(\.isSample), "Sample provenance survives mixed user/demo history")
        var editedSample = sample
        editedSample.save(CheckIn(day: sample.checkIns[0].day, mood: .bright, appetite: .hungry, routines: [], note: "Updated"), calendar: calendar)
        expect(editedSample.checkIns[0].isSample, "Editing a fictional example doesn't silently turn it into genuine history")
        let data = try JSONEncoder().encode(sample)
        expect(try JSONDecoder().decode(Journal.self, from: data) == sample, "Journal survives persistence round trip")
        print("PASS: \(checks) meaningful Along domain checks")
    }
}
