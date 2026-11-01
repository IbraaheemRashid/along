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
        pending = []
        if pretendSuccessWithoutScheduling { return }
        for schedule in schedules {
            pending.insert(schedule.id)
            if failAfterFirstSchedule { throw Failure.expected }
        }
    }
    func removeAllAlongReminders() async { removeCount += 1; pending.subtract(ReminderPlanner.allIDs) }
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
        expect(ReminderPreferences.suggestion(onboardingChoice: "Morning", reflectionDay: 99).weeklyDay == 1, "Invalid suggested weekday falls back safely")
        preferences.dailyEnabled = true
        preferences.dailyHour = 7; preferences.dailyMinute = 35
        let daily = ReminderPlanner.schedules(for: preferences)
        expect(daily.count == 1 && daily[0].weekday == nil && daily[0].hour == 7 && daily[0].minute == 35, "Daily-only schedule uses a recurring local time")
        expect(daily[0].dateComponents.timeZone == nil && daily[0].dateComponents.year == nil, "Schedules do not pin a date or timezone")
        preferences.weeklyEnabled = true; preferences.weeklyDay = 3
        preferences.weeklyHour = 7; preferences.weeklyMinute = 35
        let both = ReminderPlanner.schedules(for: preferences)
        expect(both.count == 7 && Set(both.map(\.id)).count == 7, "Daily and weekly reminders create seven unique requests")
        expect(both.filter { $0.weekday == 3 }.count == 1 && both.first { $0.weekday == 3 }?.kind == .weekly, "Weekly reflection replaces the daily nudge even at the same time")
        expect(Set(both.compactMap(\.weekday)) == Set(1...7), "Each weekday has exactly one reminder")
        preferences.dailyEnabled = false
        expect(ReminderPlanner.schedules(for: preferences).count == 1, "Weekly-only reminders do not create daily requests")
        var invalid = preferences; invalid.weeklyMinute = 60
        expect(!invalid.isValid && ReminderPlanner.schedules(for: invalid).isEmpty, "Invalid persisted times never schedule")
        expect(try JSONDecoder().decode(ReminderPreferences.self, from: JSONEncoder().encode(preferences)) == preferences, "Valid preferences survive persistence")
        let allCopy = both.map { $0.title + " " + $0.body }.joined(separator: " ").lowercased()
        expect(!["glp", "weight", "medication", "streak", "missed"].contains(where: allCopy.contains), "Lock-screen copy contains no health details or guilt")

        // Validate wall-clock matching across a daylight-saving transition using
        // Foundation only; no OS notification request is created in these tests.
        var london = Calendar(identifier: .gregorian)
        london.timeZone = TimeZone(identifier: "Europe/London")!
        let beforeDST = ISO8601DateFormatter().date(from: "2026-03-28T20:00:00Z")!
        let next = london.nextDate(after: beforeDST, matching: daily[0].dateComponents, matchingPolicy: .nextTime)!
        expect(london.component(.hour, from: next) == 7 && london.component(.minute, from: next) == 35, "Local schedule preserves the chosen clock time after DST")

        let fake = FakeReminderClient()
        let store = ReminderStore(defaults: defaults, client: fake, arguments: [])
        expect(fake.requestCount == 0 && fake.replaceCount == 0, "Construction never asks permission or schedules")
        await store.refresh()
        expect(fake.requestCount == 0 && fake.replaceCount == 0 && !store.isScheduled, "Refresh is read-only")
        expect(await store.save(preferences), "Explicit save can request permission and schedule")
        expect(fake.requestCount == 1 && store.isScheduled && store.preferences == preferences, "Only a verified scheduled request is shown as active")
        let reloaded = ReminderStore(defaults: defaults, client: fake, arguments: [])
        expect(reloaded.preferences == preferences && reloaded.hasSavedPreferences, "Saved preferences survive restart")
        await reloaded.refresh()
        expect(reloaded.isScheduled && fake.requestCount == 1, "Reload confirms existing schedule without prompting")
        expect(await store.save(preferences) && fake.requestCount == 1, "A second save with authorization does not ask again")

        fake.failAfterFirstSchedule = true
        var bothPreferences = preferences; bothPreferences.dailyEnabled = true
        expect(!(await store.save(bothPreferences)), "Partial scheduling failures are reported")
        expect(fake.pending.isEmpty && !store.isScheduled && store.preferences == preferences && store.message != nil, "Partial schedules are removed and failed settings are not published")
        fake.failAfterFirstSchedule = false
        fake.pretendSuccessWithoutScheduling = true
        expect(!(await store.save(preferences)) && !store.isScheduled, "Reported success without pending requests is not mistaken for delivery readiness")
        fake.pretendSuccessWithoutScheduling = false
        fake.permission = .denied
        let requestCount = fake.requestCount
        expect(!(await store.save(preferences)) && fake.requestCount == requestCount, "Denied permission routes to Settings without repeated prompts")
        expect(await store.save(ReminderPreferences()) && fake.requestCount == requestCount, "Turning off never asks permission")
        expect(!store.preferences.isEnabled && fake.pending.isEmpty, "Off removes only Along reminders and updates preferences")
        fake.permission = .quiet
        expect(await store.save(preferences) && store.isScheduled && store.statusText.contains("quietly"), "Quiet authorization remains useful and is disclosed accurately")
        fake.pending.insert("unrelated.notification")
        expect(await store.reset() && !store.hasSavedPreferences && fake.pending == ["unrelated.notification"], "Deletion clears reminder preferences and Along requests without touching unrelated notifications")

        for flag in ["--ui-testing", "--onboarding-step", "--review-onboarding", "--sample-journey", "--reset-demo"] {
            let isolatedClient = FakeReminderClient()
            let disabled = ReminderStore(defaults: defaults, client: isolatedClient, arguments: [flag])
            await disabled.refresh()
            expect(!(await disabled.save(preferences)) && !disabled.deliveryEnabled && isolatedClient.requestCount == 0 && isolatedClient.replaceCount == 0, "\(flag) is unable to deliver real notifications")
        }
        let explicitDisabled = ReminderStore(defaults: defaults, client: fake, deliveryEnabled: false, arguments: [])
        expect(!explicitDisabled.deliveryEnabled && !explicitDisabled.hasSavedPreferences, "Dev sandbox can explicitly disable delivery without reading real preferences")
        defaults.set(Data("broken".utf8), forKey: "along.reminders.preferences.v1")
        let corrupt = ReminderStore(defaults: defaults, client: fake, arguments: [])
        let corruptSaved = await corrupt.save(preferences)
        expect(corrupt.message != nil && !corruptSaved, "Unreadable settings do not enable reminders")
        expect(await corrupt.save(ReminderPreferences()) && corrupt.message == "Reminders are off.", "Explicit off recovers unreadable reminder settings")
        print("PASS: \(checks) reminder checks; all system interactions mocked")
    }
}
