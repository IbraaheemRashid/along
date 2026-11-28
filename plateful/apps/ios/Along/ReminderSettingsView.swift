import SwiftUI

struct ReminderSettingsView: View {
    @Environment(JournalStore.self) private var store
    @Environment(ReminderStore.self) private var reminders
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var draft = ReminderPreferences()
    @State private var loaded = false

    private var sources: [DoseReminderSource] { store.reminderSources }
    private var batches: [BatchExpiryReminderSource] { store.journal.batchExpiryReminderSources }
    private var planned: [ReminderSchedule] {
        ReminderPlanner.schedules(for: draft, sources: sources, batchExpiries: batches)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Along can remind you at each dose time and before a batch expiry you set. Notifications show the peptide name and amount only — never notes, sites, or dosing advice.")
                .font(.subheadline).foregroundStyle(SetupTheme.muted)

            Toggle(isOn: $draft.enabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dose & batch reminders").font(.system(.body, weight: .semibold)).foregroundStyle(SetupTheme.ink)
                    Text("Uses schedules and batch dates in your protocol.").font(.caption).foregroundStyle(SetupTheme.muted)
                }
            }
            .tint(SetupTheme.ink)
            .frame(minHeight: 44)
            .accessibilityIdentifier("reminders.enabled")

            if draft.enabled {
                if sources.isEmpty && batches.isEmpty {
                    Text("Add an active peptide in Protocol to choose reminder times.")
                        .font(.caption).foregroundStyle(SetupTheme.muted)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Will remind for").font(.caption.weight(.semibold)).foregroundStyle(SetupTheme.muted)
                        ForEach(sources, id: \.id) { source in
                            HStack {
                                Text(source.name).font(.subheadline.weight(.medium)).foregroundStyle(SetupTheme.ink)
                                Spacer()
                                Text(source.amountText ?? source.times.map(timeText).joined(separator: " · "))
                                    .font(.caption).foregroundStyle(SetupTheme.muted)
                            }
                        }
                        ForEach(batches, id: \.id) { batch in
                            HStack {
                                Text(batch.name).font(.subheadline.weight(.medium)).foregroundStyle(SetupTheme.ink)
                                Spacer()
                                Text("Batch · \(batch.expiryKey)").font(.caption).foregroundStyle(SetupTheme.muted)
                            }
                        }
                        if planned.count >= ReminderPlanner.maximumSchedules {
                            Text("Showing the first \(ReminderPlanner.maximumSchedules) reminders. iOS caps pending notifications.")
                                .font(.caption).foregroundStyle(SetupTheme.muted)
                        }
                    }
                    .padding(14)
                    .background(SetupTheme.tile, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }

            Text("Times follow your device’s local time. Focus and notification settings may quiet or delay delivery.")
                .font(.caption).foregroundStyle(SetupTheme.muted)

            Label(reminders.statusText, systemImage: reminders.isScheduled ? "bell.badge" : "bell")
                .font(.subheadline).foregroundStyle(SetupTheme.ink)
                .accessibilityIdentifier("reminders.status")

            if reminders.permission == .denied || reminders.permission == .quiet {
                Button("Open iOS notification settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
            }

            SetupPrimaryButton(title: reminders.isBusy ? "Saving…" : "Save reminders", symbol: "bell",
                               enabled: !reminders.isBusy && reminders.deliveryEnabled, identifier: "reminders.save") {
                Task { await reminders.save(draft, sources: sources, batchExpiries: batches) }
            }
            .opacity(reminders.deliveryEnabled ? 1 : 0.5)

            if let message = reminders.message {
                Text(message).font(.caption).foregroundStyle(SetupTheme.muted)
                    .accessibilityIdentifier("reminders.message")
            }
        }
        .disabled(reminders.isBusy)
        .task {
            if !loaded {
                draft = reminders.suggestedPreferences()
                loaded = true
            }
            await reminders.refresh()
            if reminders.preferences.isEnabled {
                _ = await reminders.sync(sources: sources, batchExpiries: batches)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await reminders.refresh()
                    if reminders.preferences.isEnabled {
                        _ = await reminders.sync(sources: sources, batchExpiries: batches)
                    }
                }
            }
        }
        .onChange(of: store.journal.protocolPeptides) { _, _ in
            Task {
                if reminders.preferences.isEnabled {
                    _ = await reminders.sync(sources: sources, batchExpiries: batches)
                }
            }
        }
    }

    private func timeText(_ time: DoseReminderSource.Time) -> String {
        let date = Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: .now) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}
