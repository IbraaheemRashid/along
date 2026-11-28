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
    private var resyncAfterSave = false
    /// Last peptide sources used for scheduling, so protocol edits can refresh.
    private var sources: [DoseReminderSource] = []
    private var batchExpiries: [BatchExpiryReminderSource] = []

    init(defaults: UserDefaults = .standard, client: (any ReminderClient)? = nil,
         deliveryEnabled: Bool = true, arguments: [String] = ProcessInfo.processInfo.arguments) {
        let reviewFlags = ["--ui-testing", "--onboarding-step", "--review-onboarding", "--setup-step", "--setup-complete", "--sample-journey", "--reset-demo"]
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
                message = "Your reminder preferences couldn’t be opened. Turn reminders off to reset only these settings. Your protocol is unchanged."
            }
        }
    }

    var isScheduled: Bool {
        let expected = Set(ReminderPlanner.schedules(for: preferences, sources: sources).map(\.id))
        return deliveryEnabled && permission.canSchedule && !expected.isEmpty && expected == scheduledIDs
    }

    var statusText: String {
        if !deliveryEnabled { return "Reminders are disabled in this development preview." }
        if !readablePreferences { return "Reminder settings need attention." }
        if !preferences.isEnabled { return "Dose reminders are off." }
        if sources.isEmpty { return "Add a peptide to your protocol to schedule dose reminders." }
        if permission == .denied { return "Notifications are off in iOS Settings." }
        if !hasRefreshed { return "Checking notification settings…" }
        if isScheduled {
            let count = scheduledIDs.count
            let quiet = permission == .quiet ? " iOS is delivering them quietly." : ""
            return "\(count) dose reminder\(count == 1 ? "" : "s") scheduled.\(quiet)"
        }
        return "Your dose reminders aren’t scheduled. Save your choices to try again."
    }

    /// Read-only. Safe on app activation; never prompts for permission.
    func refresh() async {
        guard deliveryEnabled, !isBusy else { return }
        let revision = stateRevision
        let state = await client.state()
        guard revision == stateRevision, !isBusy else { return }
        permission = state.permission
        scheduledIDs = state.pendingIDs.filter(Self.isAlongReminder)
        hasRefreshed = true
    }

    /// Update the peptide sources used for planning. When reminders are already
    /// on, reschedules without prompting again.
    @discardableResult func sync(sources: [DoseReminderSource],
                                 batchExpiries: [BatchExpiryReminderSource] = []) async -> Bool {
        self.sources = sources
        self.batchExpiries = batchExpiries
        guard deliveryEnabled, readablePreferences else { return preferences.isEnabled }
        if isBusy {
            resyncAfterSave = true
            return false
        }
        guard preferences.isEnabled else { return false }
        return await save(preferences, sources: sources, batchExpiries: batchExpiries)
    }

    /// Invoke only from an explicit user action, such as Save reminders.
    @discardableResult func save(_ requested: ReminderPreferences, sources: [DoseReminderSource]? = nil,
                                 batchExpiries: [BatchExpiryReminderSource]? = nil) async -> Bool {
        if let sources { self.sources = sources }
        if let batchExpiries { self.batchExpiries = batchExpiries }
        guard deliveryEnabled else {
            message = "This preview cannot request permission or deliver reminders. Your device’s existing reminders are unchanged."
            return false
        }
        guard !isBusy else { return false }
        guard requested.isValid else { message = "Choose a valid reminder setting."; return false }
        guard readablePreferences || !requested.isEnabled else {
            message = "Turn reminders off first to reset unreadable reminder settings. Your protocol is unchanged."
            return false
        }
        isBusy = true
        stateRevision += 1
        defer {
            isBusy = false
            if resyncAfterSave {
                resyncAfterSave = false
                Task { await sync(sources: self.sources, batchExpiries: self.batchExpiries) }
            }
        }
        message = nil
        if !requested.isEnabled {
            await client.removeAllAlongReminders()
            let state = await client.state()
            permission = state.permission
            scheduledIDs = state.pendingIDs.filter(Self.isAlongReminder)
            hasRefreshed = true
            guard scheduledIDs.isEmpty else { message = "Reminders couldn’t be removed. Please try turning them off again."; return false }
            persist(requested)
            message = "Dose reminders are off."
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
            scheduledIDs = state.pendingIDs.filter(Self.isAlongReminder)
            message = "Notifications are off. You can allow them in iOS Settings, then return here and save your choices."
            return false
        }
        let schedules = ReminderPlanner.schedules(for: requested, sources: self.sources, batchExpiries: self.batchExpiries)
        guard !schedules.isEmpty else {
            await client.removeAllAlongReminders()
            scheduledIDs = []
            persist(requested)
            message = self.sources.isEmpty && self.batchExpiries.isEmpty
                ? "Reminders are on. Add a peptide to your protocol and they’ll schedule themselves."
                : "No upcoming dose times or batch dates could be scheduled."
            return true
        }
        do {
            try await client.replace(with: schedules)
            state = await client.state()
            permission = state.permission
            scheduledIDs = state.pendingIDs.filter(Self.isAlongReminder)
            guard scheduledIDs == Set(schedules.map(\.id)), state.permission.canSchedule else {
                throw ReminderSchedulingError.incomplete
            }
            persist(requested)
            message = "Your dose reminders are saved. You can change them or turn them off here at any time."
            return true
        } catch {
            // Scheduling several requests is not atomic. Never leave an unknown
            // partial set active or claim the previous schedule still works.
            await client.removeAllAlongReminders()
            scheduledIDs = (await client.state()).pendingIDs.filter(Self.isAlongReminder)
            message = "Your reminders couldn’t be scheduled. Please save again to retry. Your protocol is unchanged."
            return false
        }
    }

    /// Call when the person explicitly deletes all local app data.
    @discardableResult func reset() async -> Bool {
        sources = []
        batchExpiries = []
        let succeeded = await save(ReminderPreferences())
        if succeeded { defaults.removeObject(forKey: storageKey); hasSavedPreferences = false }
        return succeeded
    }

    func suggestedPreferences(onboardingChoice: String? = nil, reflectionDay: Int? = nil) -> ReminderPreferences {
        hasSavedPreferences ? preferences : .suggestion(onboardingChoice: onboardingChoice, reflectionDay: reflectionDay)
    }

    private func persist(_ value: ReminderPreferences) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: storageKey)
        preferences = value
        hasSavedPreferences = true
        readablePreferences = true
    }

    static func isAlongReminder(_ id: String) -> Bool {
        id.hasPrefix(ReminderPlanner.idPrefix) || id.hasPrefix(ReminderPlanner.batchPrefix)
            || ReminderPlanner.legacyIDs.contains(id)
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
        await removeAllAlongReminders()
        for schedule in schedules {
            let content = UNMutableNotificationContent()
            content.title = schedule.title
            content.body = schedule.body
            content.sound = .default
            content.threadIdentifier = "along.reminders"
            let trigger = UNCalendarNotificationTrigger(dateMatching: schedule.dateComponents, repeats: schedule.repeats)
            guard trigger.nextTriggerDate() != nil else { throw ReminderSchedulingError.incomplete }
            try await center.add(UNNotificationRequest(identifier: schedule.id, content: content, trigger: trigger))
        }
    }
    func removeAllAlongReminders() async {
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter(ReminderStore.isAlongReminder)
        center.removePendingNotificationRequests(withIdentifiers: ours + ReminderPlanner.legacyIDs)
        let delivered = await center.deliveredNotifications().map { $0.request.identifier }.filter(ReminderStore.isAlongReminder)
        center.removeDeliveredNotifications(withIdentifiers: delivered)
    }
}

@MainActor private final class DisabledReminderClient: ReminderClient {
    func state() async -> ReminderSystemState { ReminderSystemState(permission: .notDetermined, pendingIDs: []) }
    func requestPermission() async throws -> Bool { false }
    func replace(with schedules: [ReminderSchedule]) async throws {}
    func removeAllAlongReminders() async {}
}
