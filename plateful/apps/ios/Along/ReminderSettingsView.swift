import SwiftUI

struct ReminderSettingsView: View {
    @Environment(ReminderStore.self) private var reminders
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    var onboardingChoice: String? = nil
    var reflectionDay: Int? = nil
    @State private var draft = ReminderPreferences()
    @State private var loaded = false

    var body: some View {
        AlongSection(title: "A little nudge, if you’d like") {
            Text("Choose when Along can invite you back. Notifications don’t include your name, health information or journal entries.")
                .font(.subheadline).foregroundStyle(Theme.secondaryInk)
            Toggle("Daily check-in reminder", isOn: $draft.dailyEnabled)
                .frame(minHeight: 44).accessibilityIdentifier("reminders.daily")
            if draft.dailyEnabled {
                DatePicker("Daily time", selection: dailyTime, displayedComponents: .hourAndMinute)
                    .frame(minHeight: 44).accessibilityIdentifier("reminders.dailyTime")
            }
            Divider()
            Toggle("Weekly reflection reminder", isOn: $draft.weeklyEnabled)
                .frame(minHeight: 44).accessibilityIdentifier("reminders.weekly")
            if draft.weeklyEnabled {
                Picker("Reflection day", selection: $draft.weeklyDay) {
                    ForEach(1...7, id: \.self) { day in Text(Calendar.current.weekdaySymbols[day - 1]).tag(day) }
                }.frame(minHeight: 44)
                DatePicker("Reflection time", selection: weeklyTime, displayedComponents: .hourAndMinute)
                    .frame(minHeight: 44)
            }
            if draft.dailyEnabled && draft.weeklyEnabled {
                Text("Your reflection reminder replaces the daily reminder on that day.")
                    .font(.caption).foregroundStyle(Theme.secondaryInk)
            }
            Text("Times follow your device’s local time. Focus and notification settings may quiet or delay delivery.")
                .font(.caption).foregroundStyle(Theme.secondaryInk)
            Label(reminders.statusText, systemImage: reminders.isScheduled ? "bell.badge" : "bell")
                .font(.subheadline).foregroundStyle(Theme.accent)
                .accessibilityIdentifier("reminders.status")
            if reminders.permission == .denied || reminders.permission == .quiet {
                Button("Open iOS notification settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }.frame(minHeight: 44)
            }
            PrimaryButton(title: reminders.isBusy ? "Saving…" : "Save reminders", symbol: "bell") {
                Task { await reminders.save(draft) }
            }.disabled(reminders.isBusy || !reminders.deliveryEnabled)
                .opacity(reminders.deliveryEnabled ? 1 : 0.5)
                .accessibilityIdentifier("reminders.save")
            if let message = reminders.message {
                Text(message).font(.caption).foregroundStyle(Theme.secondaryInk)
                    .accessibilityIdentifier("reminders.message")
            }
        }.disabled(reminders.isBusy)
            .task {
                if !loaded {
                    draft = reminders.suggestedPreferences(onboardingChoice: onboardingChoice, reflectionDay: reflectionDay)
                    loaded = true
                }
                await reminders.refresh()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await reminders.refresh() } }
            }
    }

    private var dailyTime: Binding<Date> {
        Binding(get: { time(hour: draft.dailyHour, minute: draft.dailyMinute) }, set: {
            let values = Calendar.current.dateComponents([.hour, .minute], from: $0)
            draft.dailyHour = values.hour ?? 9; draft.dailyMinute = values.minute ?? 0
        })
    }
    private var weeklyTime: Binding<Date> {
        Binding(get: { time(hour: draft.weeklyHour, minute: draft.weeklyMinute) }, set: {
            let values = Calendar.current.dateComponents([.hour, .minute], from: $0)
            draft.weeklyHour = values.hour ?? 19; draft.weeklyMinute = values.minute ?? 0
        })
    }
    private func time(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
    }
}
