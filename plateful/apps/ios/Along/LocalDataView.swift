import SwiftUI

/// Data ownership and reminder controls remain available outside paid access.
struct LocalDataView: View {
    @Environment(JournalStore.self) private var store
    @Environment(ReminderStore.self) private var reminders
    @Environment(\.dismiss) private var dismiss
    @State private var backup = false
    @State private var privacy = false
    @State private var confirmDelete = false
    @State private var message: String?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Your protocol belongs to you.")
                        .font(.system(size: 29, weight: .bold)).tracking(-0.5).foregroundStyle(SetupTheme.ink)
                    Text("You can keep a copy, manage reminders or clear this device without a membership.")
                        .foregroundStyle(SetupTheme.muted)
                    AlongSection(title: "Your data") {
                        ShareLink(item: store.exportText) { Label("Export readable copy", systemImage: "square.and.arrow.up").frame(minHeight: 44) }
                        SettingsAction(title: "Backup & restore", symbol: "externaldrive") { backup = true }
                        SettingsAction(title: "Privacy & your data", symbol: "lock") { privacy = true }
                        SettingsAction(title: "Delete all local data", symbol: "trash", destructive: true) { confirmDelete = true }
                    }
                    ReminderSettingsView()
                    if let message { Text(message).font(.subheadline).foregroundStyle(SetupTheme.muted) }
                }.padding(22).frame(maxWidth: 620)
            }.frame(maxWidth: .infinity).background(SetupTheme.tile)
                .navigationTitle("Your data & reminders").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
                .sheet(isPresented: $backup) { JournalBackupView(journal: { store.journal }, replace: store.restoreJournal) }
                .sheet(isPresented: $privacy) { PrivacyView() }
                .confirmationDialog("Delete all local data?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Delete all local data", role: .destructive) {
                        Task {
                            if reminders.deliveryEnabled, !(await reminders.reset()) {
                                message = "Reminders could not be removed. Your protocol has been kept. Please try again."
                                return
                            }
                            if store.clearJournal() { dismiss() }
                            else { message = store.error }
                        }
                    }
                } message: { Text("This removes this device’s protocol, setup and reminders. Save a backup first if you want to keep them. It does not cancel a subscription or delete exported copies.") }
        }
    }
}
