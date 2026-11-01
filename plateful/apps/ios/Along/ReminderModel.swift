import Foundation

struct ReminderPreferences: Codable, Equatable {
    var dailyEnabled = false
    var dailyHour = 9
    var dailyMinute = 0
    var weeklyEnabled = false
    /// Foundation weekday values: 1 is Sunday, 7 is Saturday.
    var weeklyDay = 1
    var weeklyHour = 19
    var weeklyMinute = 0

    var isEnabled: Bool { dailyEnabled || weeklyEnabled }
    var isValid: Bool {
        (0...23).contains(dailyHour) && (0...59).contains(dailyMinute) &&
        (0...23).contains(weeklyHour) && (0...59).contains(weeklyMinute) &&
        (1...7).contains(weeklyDay)
    }

    static func suggestion(onboardingChoice: String?, reflectionDay: Int?) -> ReminderPreferences {
        var value = ReminderPreferences()
        if onboardingChoice == "Evening" { value.dailyHour = 19 }
        if let reflectionDay, (1...7).contains(reflectionDay) { value.weeklyDay = reflectionDay }
        // Setup expressed a preference, not permission to deliver notifications.
        // Both controls remain off until the person explicitly enables and saves.
        return value
    }
}

struct ReminderSchedule: Equatable, Identifiable {
    enum Kind: String { case daily, weekly }
    var id: String
    var kind: Kind
    var weekday: Int?
    var hour: Int
    var minute: Int

    var title: String { "A little space for you" }
    var body: String {
        kind == .daily ? "A moment to notice today, whenever it suits you." : "Your week is here to revisit, whenever you’re ready."
    }
    var dateComponents: DateComponents {
        // No absolute date or fixed timezone. iOS matches local wall-clock time.
        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = minute
        return components
    }
}

enum ReminderPlanner {
    static let dailyID = "along.reminder.daily"
    static let weeklyID = "along.reminder.weekly"
    static let allIDs = [dailyID, weeklyID] + (1...7).map { "along.reminder.daily.\($0)" }

    static func schedules(for preferences: ReminderPreferences) -> [ReminderSchedule] {
        guard preferences.isValid else { return [] }
        var result: [ReminderSchedule] = []
        if preferences.dailyEnabled {
            if preferences.weeklyEnabled {
                // One reminder per day. The reflection replaces that day's nudge,
                // even when the two chosen times are different.
                for weekday in 1...7 where weekday != preferences.weeklyDay {
                    result.append(ReminderSchedule(id: "\(dailyID).\(weekday)", kind: .daily,
                                                   weekday: weekday, hour: preferences.dailyHour, minute: preferences.dailyMinute))
                }
            } else {
                result.append(ReminderSchedule(id: dailyID, kind: .daily, hour: preferences.dailyHour, minute: preferences.dailyMinute))
            }
        }
        if preferences.weeklyEnabled {
            result.append(ReminderSchedule(id: weeklyID, kind: .weekly, weekday: preferences.weeklyDay,
                                           hour: preferences.weeklyHour, minute: preferences.weeklyMinute))
        }
        return result
    }
}

enum ReminderPermission: Equatable {
    case notDetermined, denied, authorized, quiet
    var canSchedule: Bool { self == .authorized || self == .quiet }
}

struct ReminderSystemState: Equatable {
    var permission: ReminderPermission
    var pendingIDs: Set<String>
}

/// The system adapter is injected so verification never requests permission or
/// schedules a notification on the developer's machine or a simulator.
@MainActor protocol ReminderClient {
    func state() async -> ReminderSystemState
    func requestPermission() async throws -> Bool
    func replace(with schedules: [ReminderSchedule]) async throws
    func removeAllAlongReminders() async
}
