import Foundation
import Observation
import UserNotifications

@MainActor @Observable final class ReminderStore {
    private(set) var preferences = ReminderPreferences()
    private(set) var hasSavedPreferences = false
    private(set) var permission: ReminderPermission = .notDetermined
    private(set) var scheduledIDs: Set<String> = []
    private(set) var isBusy = false
    private(set) var hasRefreshed = false
    var message: String?
    let deliveryEnabled: Bool
    private let client: any ReminderClient
    private let defaults: UserDefaults
    private let storageKey = "along.reminders.preferences.v1"
    private var readablePreferences = true
    private var stateRevision = 0

    init(defaults: UserDefaults = .standard, client: (any ReminderClient)? = nil,
         deliveryEnabled: Bool = true, arguments: [String] = ProcessInfo.processInfo.arguments) {
        let reviewFlags = ["--ui-testing", "--onboarding-step", "--review-onboarding", "--setup-step", "--sample-journey", "--reset-demo"]
        self.deliveryEnabled = deliveryEnabled && !arguments.contains(where: reviewFlags.contains)
        self.defaults = defaults
        // A disabled instance never instantiates or calls UNUserNotificationCenter.
        self.client = self.deliveryEnabled ? (client ?? SystemReminderClient()) : DisabledReminderClient()
        guard self.deliveryEnabled else { return }
        if let data = defaults.data(forKey: storageKey) {
            if data.count <= 4096, let decoded = try? JSONDecoder().decode(ReminderPreferences.self, from: data), decoded.isValid {
                preferences = decoded
                hasSavedPreferences = true
            } else {
                readablePreferences = false
                message = "Your reminder preferences couldn’t be opened. Turn reminders off to reset only these settings. Your journal is unchanged."
            }
        }
    }

    var isScheduled: Bool {
        let expected = Set(ReminderPlanner.schedules(for: preferences).map(\.id))
        return deliveryEnabled && permission.canSchedule && !expected.isEmpty && expected == scheduledIDs
    }
    var statusText: String {
        if !deliveryEnabled { return "Reminders are disabled in this development preview." }
        if !readablePreferences { return "Reminder settings need attention." }
        if !preferences.isEnabled { return "Reminders are off." }
        if permission == .denied { return "Notifications are off in iOS Settings." }
        if !hasRefreshed { return "Checking notification settings…" }
        if isScheduled { return permission == .quiet ? "Scheduled. iOS is delivering notifications quietly." : "Your reminders are scheduled." }
        return "Your reminders aren’t scheduled. Save your choices to try again."
    }

    /// Read-only. Safe on app activation; never prompts for permission.
    func refresh() async {
        guard deliveryEnabled, !isBusy else { return }
        let revision = stateRevision
        let state = await client.state()
        guard revision == stateRevision, !isBusy else { return }
        permission = state.permission
        scheduledIDs = state.pendingIDs.intersection(ReminderPlanner.allIDs)
        hasRefreshed = true
    }

    /// Invoke only from an explicit user action, such as Save reminders.
    @discardableResult func save(_ requested: ReminderPreferences) async -> Bool {
        guard deliveryEnabled else {
            message = "This preview cannot request permission or deliver reminders. Your device’s existing reminders are unchanged."
            return false
        }
        guard !isBusy else { return false }
        guard requested.isValid else { message = "Choose a valid reminder time and day."; return false }
        guard readablePreferences || !requested.isEnabled else {
            message = "Turn reminders off first to reset unreadable reminder settings. Your journal is unchanged."
            return false
        }
        isBusy = true
        stateRevision += 1
        defer { isBusy = false }
        message = nil
        if !requested.isEnabled {
            await client.removeAllAlongReminders()
            let state = await client.state()
            permission = state.permission
            scheduledIDs = state.pendingIDs.intersection(ReminderPlanner.allIDs)
            hasRefreshed = true
            guard scheduledIDs.isEmpty else { message = "Reminders couldn’t be removed. Please try turning them off again."; return false }
            persist(requested)
            message = "Reminders are off."
            return true
        }
        var state = await client.state()
        if state.permission == .notDetermined {
            do { _ = try await client.requestPermission() }
            catch { message = "iOS couldn’t open the notification permission request. Please try again."; return false }
            state = await client.state()
        }
        permission = state.permission
        hasRefreshed = true
        guard state.permission.canSchedule else {
            scheduledIDs = state.pendingIDs.intersection(ReminderPlanner.allIDs)
            message = "Notifications are off. You can allow them in iOS Settings, then return here and save your choices."
            return false
        }
        let schedules = ReminderPlanner.schedules(for: requested)
        do {
            try await client.replace(with: schedules)
            state = await client.state()
            permission = state.permission
            scheduledIDs = state.pendingIDs.intersection(ReminderPlanner.allIDs)
            guard scheduledIDs == Set(schedules.map(\.id)), state.permission.canSchedule else {
                throw ReminderSchedulingError.incomplete
            }
            persist(requested)
            message = "Your reminders are saved. You can change them or turn them off here at any time."
            return true
        } catch {
            // Scheduling several requests is not atomic. Never leave an unknown
            // partial set active or claim the previous schedule still works.
            await client.removeAllAlongReminders()
            scheduledIDs = (await client.state()).pendingIDs.intersection(ReminderPlanner.allIDs)
            message = "Your reminders couldn’t be scheduled. Please save again to retry. Your journal is unchanged."
            return false
        }
    }

    /// Call when the person explicitly deletes all local app data.
    @discardableResult func reset() async -> Bool {
        let succeeded = await save(ReminderPreferences())
        if succeeded { defaults.removeObject(forKey: storageKey); hasSavedPreferences = false }
        return succeeded
    }

    func suggestedPreferences(onboardingChoice: String?, reflectionDay: Int?) -> ReminderPreferences {
        hasSavedPreferences ? preferences : .suggestion(onboardingChoice: onboardingChoice, reflectionDay: reflectionDay)
    }

    private func persist(_ value: ReminderPreferences) {
        // The only Codable fields are bounded Bool/Int values, so encoding is
        // total. UserDefaults contains scheduling choices, never health entries.
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: storageKey)
        preferences = value
        hasSavedPreferences = true
        readablePreferences = true
    }
}

private enum ReminderSchedulingError: Error { case incomplete }

@MainActor private final class SystemReminderClient: ReminderClient {
    private let center = UNUserNotificationCenter.current()
    func state() async -> ReminderSystemState {
        let settings = await center.notificationSettings()
        let permission: ReminderPermission
        switch settings.authorizationStatus {
        case .notDetermined: permission = .notDetermined
        case .denied: permission = .denied
        case .provisional: permission = .quiet
        #if os(iOS)
        case .ephemeral: permission = .quiet
        #endif
        case .authorized: permission = settings.alertSetting == .enabled ? .authorized : .quiet
        @unknown default: permission = .denied
        }
        let pending = await center.pendingNotificationRequests()
        return ReminderSystemState(permission: permission, pendingIDs: Set(pending.map(\.identifier)))
    }
    func requestPermission() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }
    func replace(with schedules: [ReminderSchedule]) async throws {
        center.removePendingNotificationRequests(withIdentifiers: ReminderPlanner.allIDs)
        for schedule in schedules {
            let content = UNMutableNotificationContent()
            content.title = schedule.title
            content.body = schedule.body
            content.sound = .default
            content.threadIdentifier = "along.reminders"
            let trigger = UNCalendarNotificationTrigger(dateMatching: schedule.dateComponents, repeats: true)
            guard trigger.nextTriggerDate() != nil else { throw ReminderSchedulingError.incomplete }
            try await center.add(UNNotificationRequest(identifier: schedule.id, content: content, trigger: trigger))
        }
    }
    func removeAllAlongReminders() async {
        center.removePendingNotificationRequests(withIdentifiers: ReminderPlanner.allIDs)
        center.removeDeliveredNotifications(withIdentifiers: ReminderPlanner.allIDs)
    }
}

@MainActor private final class DisabledReminderClient: ReminderClient {
    func state() async -> ReminderSystemState { ReminderSystemState(permission: .notDetermined, pendingIDs: []) }
    func requestPermission() async throws -> Bool { false }
    func replace(with schedules: [ReminderSchedule]) async throws {}
    func removeAllAlongReminders() async {}
}
