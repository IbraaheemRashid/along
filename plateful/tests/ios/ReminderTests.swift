import Foundation

@MainActor private final class FakeReminderClient: ReminderClient {
    var permission: ReminderPermission = .notDetermined
    var requestedPermission: ReminderPermission = .authorized
    var pending: Set<String> = []
    var requestCount = 0
    var replaceCount = 0
    var removeCount = 0
    var failPermission = false
    var failAfterFirstSchedule = false
    var pretendSuccessWithoutScheduling = false
    enum Failure: Error { case expected }
    func state() async -> ReminderSystemState { ReminderSystemState(permission: permission, pendingIDs: pending) }
    func requestPermission() async throws -> Bool {
        requestCount += 1
        if failPermission { throw Failure.expected }
        permission = requestedPermission
        return permission.canSchedule
    }
    func replace(with schedules: [ReminderSchedule]) async throws {
        replaceCount += 1
        pending = pending.filter { !ReminderStore.isAlongReminder($0) }
        if pretendSuccessWithoutScheduling { return }
        for schedule in schedules {
            pending.insert(schedule.id)
            if failAfterFirstSchedule { throw Failure.expected }
        }
    }
    func removeAllAlongReminders() async {
        removeCount += 1
        pending = pending.filter { !ReminderStore.isAlongReminder($0) }
    }
}

@main struct ReminderTests {
    @MainActor static func main() async throws {
        var checks = 0
        func expect(_ condition: Bool, _ name: String) { precondition(condition, name); checks += 1 }
        let suiteName = "along-reminder-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var preferences = ReminderPreferences()
        expect(!preferences.isEnabled && ReminderPlanner.schedules(for: preferences).isEmpty, "Reminders default off")
        let suggested = ReminderPreferences.suggestion(onboardingChoice: "Evening", reflectionDay: 4)
        expect(suggested.dailyHour == 19 && suggested.weeklyDay == 4 && !suggested.isEnabled, "Onboarding seeds time without granting consent")

        let daily = DoseReminderSource(id: "pep-a", name: "BPC-157", amountText: "250 mcg", cadence: .daily, times: [.init(hour: 8, minute: 0), .init(hour: 20, minute: 0)])
        let weekly = DoseReminderSource(id: "pep-b", name: "Tirzepatide", amountText: "2.5 mg", cadence: .weekdays([2, 4, 6]), times: [.init(hour: 8, minute: 0)])
        preferences.enabled = true
        let planned = ReminderPlanner.schedules(for: preferences, sources: [daily, weekly])
        expect(planned.count == 5, "Daily twice plus three weekday times")
        expect(planned.filter { $0.repeats }.count == 5, "Calendar-repeating schedules for daily and weekday cadences")
        expect(planned.allSatisfy { $0.id.hasPrefix(ReminderPlanner.idPrefix) }, "IDs stay in the Along dose namespace")
        expect(planned.allSatisfy { $0.dateComponents.timeZone == nil }, "Schedules do not pin a timezone")
        let copy = planned.map { $0.title + " " + $0.body }.joined(separator: " ").lowercased()
        expect(!["glp", "weight", "medication", "streak", "missed", "injection"].contains(where: copy.contains), "Lock-screen copy contains no guilt or clinical claims")
        expect(copy.contains("bpc-157") && copy.contains("250 mcg"), "Title names the peptide and amount the person set")

        let start = "2026-01-01"
        let interval = DoseReminderSource(id: "pep-c", name: "Custom", amountText: nil, cadence: .interval(days: 3, startKey: start), times: [.init(hour: 9, minute: 30)])
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 2, hour: 12))!
        let oneshots = ReminderPlanner.schedules(for: preferences, sources: [interval], now: now, calendar: calendar)
        expect(oneshots.count == ReminderPlanner.intervalHorizon && oneshots.allSatisfy { !$0.repeats }, "Interval peptides pre-schedule upcoming one-shot reminders")
        expect(oneshots.first?.dateComponents.hour == 9 && oneshots.first?.dateComponents.minute == 30, "Interval reminders keep the chosen clock time")

        // Cap under iOS's 64 pending-notification limit.
        let many = (0..<40).map { DoseReminderSource(id: "p\($0)", name: "P\($0)", amountText: nil, cadence: .weekdays(Set(1...7)), times: [.init(hour: 8, minute: 0)]) }
        expect(ReminderPlanner.schedules(for: preferences, sources: many).count == ReminderPlanner.maximumSchedules, "Planner never exceeds the reserved notification budget")

        var invalid = preferences; invalid.dailyMinute = 60
        expect(!invalid.isValid && ReminderPlanner.schedules(for: invalid, sources: [daily]).isEmpty, "Invalid persisted times never schedule")
        expect(try JSONDecoder().decode(ReminderPreferences.self, from: JSONEncoder().encode(preferences)) == preferences, "Valid preferences survive persistence")
        let legacy = try JSONDecoder().decode(ReminderPreferences.self, from: Data("{\"dailyEnabled\":true,\"dailyHour\":7,\"dailyMinute\":0,\"weeklyEnabled\":false,\"weeklyDay\":1,\"weeklyHour\":19,\"weeklyMinute\":0}".utf8))
        expect(legacy.enabled && legacy.dailyHour == 7, "Legacy daily toggle maps onto the dose reminder switch")

        var london = Calendar(identifier: .gregorian)
        london.timeZone = TimeZone(identifier: "Europe/London")!
        let beforeDST = ISO8601DateFormatter().date(from: "2026-03-28T20:00:00Z")!
        let dailyOnly = ReminderPlanner.schedules(for: preferences, sources: [DoseReminderSource(id: "d", name: "X", amountText: nil, cadence: .daily, times: [.init(hour: 7, minute: 35)])])
        let next = london.nextDate(after: beforeDST, matching: dailyOnly[0].dateComponents, matchingPolicy: .nextTime)!
        expect(london.component(.hour, from: next) == 7 && london.component(.minute, from: next) == 35, "Local schedule preserves the chosen clock time after DST")

        let fake = FakeReminderClient()
        let store = ReminderStore(defaults: defaults, client: fake, arguments: [])
        expect(fake.requestCount == 0 && fake.replaceCount == 0, "Construction never asks permission or schedules")
        await store.refresh()
        expect(fake.requestCount == 0 && fake.replaceCount == 0 && !store.isScheduled, "Refresh is read-only")
        expect(await store.save(preferences, sources: [daily, weekly]), "Explicit save can request permission and schedule")
        expect(fake.requestCount == 1 && store.isScheduled && store.preferences == preferences, "Only a verified scheduled request is shown as active")
        expect(fake.pending.count == 5, "Pending IDs match the planned dose reminders")
        let reloaded = ReminderStore(defaults: defaults, client: fake, arguments: [])
        expect(reloaded.preferences == preferences && reloaded.hasSavedPreferences, "Saved preferences survive restart")
        expect(await reloaded.sync(sources: [daily, weekly]) && reloaded.isScheduled && fake.requestCount == 1, "Sync reschedules without prompting again")
        expect(await store.save(preferences, sources: [daily, weekly]) && fake.requestCount == 1, "A second save with authorization does not ask again")

        fake.failAfterFirstSchedule = true
        expect(!(await store.save(preferences, sources: [daily, weekly])), "Partial scheduling failures are reported")
        expect(fake.pending.isEmpty && !store.isScheduled && store.preferences == preferences && store.message != nil, "Partial schedules are removed and failed settings are not published")
        fake.failAfterFirstSchedule = false
        fake.pretendSuccessWithoutScheduling = true
        expect(!(await store.save(preferences, sources: [daily])) && !store.isScheduled, "Reported success without pending requests is not mistaken for delivery readiness")
        fake.pretendSuccessWithoutScheduling = false
        fake.permission = .denied
        let requestCount = fake.requestCount
        expect(!(await store.save(preferences, sources: [daily])) && fake.requestCount == requestCount, "Denied permission routes to Settings without repeated prompts")
        expect(await store.save(ReminderPreferences()) && fake.requestCount == requestCount, "Turning off never asks permission")
        expect(!store.preferences.isEnabled && fake.pending.isEmpty, "Off removes only Along reminders and updates preferences")
        fake.permission = .quiet
        expect(await store.save(preferences, sources: [daily]) && store.isScheduled && store.statusText.contains("quietly"), "Quiet authorization remains useful and is disclosed accurately")
        fake.pending.insert("unrelated.notification")
        expect(await store.reset() && !store.hasSavedPreferences && fake.pending == ["unrelated.notification"], "Deletion clears reminder preferences and Along requests without touching unrelated notifications")

        for flag in ["--ui-testing", "--onboarding-step", "--review-onboarding", "--setup-step", "--setup-complete", "--sample-journey", "--reset-demo"] {
            let isolatedClient = FakeReminderClient()
            let disabled = ReminderStore(defaults: defaults, client: isolatedClient, arguments: [flag])
            await disabled.refresh()
            expect(!(await disabled.save(preferences, sources: [daily])) && !disabled.deliveryEnabled && isolatedClient.requestCount == 0 && isolatedClient.replaceCount == 0, "\(flag) is unable to deliver real notifications")
        }
        let explicitDisabled = ReminderStore(defaults: defaults, client: fake, deliveryEnabled: false, arguments: [])
        expect(!explicitDisabled.deliveryEnabled && !explicitDisabled.hasSavedPreferences, "Dev sandbox can explicitly disable delivery without reading real preferences")
        defaults.set(Data("broken".utf8), forKey: "along.reminders.preferences.v1")
        let corrupt = ReminderStore(defaults: defaults, client: fake, arguments: [])
        let corruptSaved = await corrupt.save(preferences, sources: [daily])
        expect(corrupt.message != nil && !corruptSaved, "Unreadable settings do not enable reminders")
        expect(await corrupt.save(ReminderPreferences()) && corrupt.message == "Dose reminders are off.", "Explicit off recovers unreadable reminder settings")
        print("PASS: \(checks) reminder checks; all system interactions mocked")
    }
}
