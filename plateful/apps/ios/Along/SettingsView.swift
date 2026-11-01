import SwiftUI

struct SettingsView: View {
    @Environment(JournalStore.self) private var store
    @Environment(ReminderStore.self) private var reminders
    @Environment(BillingStore.self) private var billing
    @State private var showPrivacy = false
    @State private var showBackup = false
    @State private var showPaywall = false
    @State private var showOnboardingReview = false
    @State private var resetAction: String?
    var body: some View {
        @Bindable var store = store
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    DemoBadge()
                    CompanionHeading(title: store.journal.name.isEmpty ? "Your little space" : "\(store.journal.name)’s little space", detail: "Everything here stays on this device.", accessory: store.journal.accessory)
                    AlongSection(title: "Make it yours") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your first name").font(.caption).foregroundStyle(Theme.secondaryInk)
                            TextField("Your first name", text: Binding(get: { store.journal.name }, set: { value in store.updateJournal { $0.name = String(value.prefix(30)) } })).frame(minHeight: 44)
                            Divider()
                            Text("Companion name").font(.caption).foregroundStyle(Theme.secondaryInk)
                            TextField("Companion name", text: Binding(get: { store.journal.companionName }, set: { value in store.updateJournal { $0.companionName = String(value.prefix(24)) } })).frame(minHeight: 44)
                        }
                        Divider()
                        ForEach(Routine.allCases) { routine in
                            Toggle(isOn: Binding(get: { store.journal.routines.contains(routine) }, set: { enabled in store.updateJournal { if enabled { $0.routines.insert(routine) } else { $0.routines.remove(routine) } } })) { Label(routine.shortTitle, systemImage: routine.symbol).font(.subheadline) }.frame(minHeight: 44)
                        }
                    }
                    AlongSection(title: "Optional records") {
                        Toggle("Show weight in my journey", isOn: Binding(get: { store.journal.showWeight }, set: { value in store.updateJournal { $0.showWeight = value } })).frame(minHeight: 44).accessibilityIdentifier("settings.showWeight")
                        Picker("Weight display", selection: Binding(get: { store.journal.weightUnit }, set: { value in store.updateJournal { $0.weightUnit = value } })) { ForEach(WeightUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.frame(minHeight: 44).accessibilityIdentifier("settings.weightUnit")
                        Text("Hiding weight leaves your records intact. It never changes your companion’s progress.").font(.caption).foregroundStyle(Theme.secondaryInk)
                    }
                    ReminderSettingsView(onboardingChoice: store.journal.onboardingPreferences?.reminder, reflectionDay: store.journal.onboardingPreferences?.reflectionDay)
                    AlongSection(title: "Your data") {
                        SettingsAction(title: "Privacy & your journal", symbol: "lock") { showPrivacy = true }
                        ShareLink(item: store.exportText, preview: SharePreview("Along journal export")) {
                            HStack(spacing: 12) { AlongIcon(symbol: "square.and.arrow.up", apricot: true); Text("Export my journal").font(.subheadline.weight(.medium)); Spacer() }.frame(minHeight: 48)
                        }
                        SettingsAction(title: "Backup & restore", symbol: "externaldrive") { showBackup = true }
                        #if DEBUG
                        SettingsAction(title: "Start a blank journal", symbol: "book") { resetAction = "blank" }
                        SettingsAction(title: "Load the sample journey", symbol: "sparkles") { resetAction = "sample" }
                        #endif
                        SettingsAction(title: "Delete all local data", symbol: "trash", destructive: true) { resetAction = "all" }
                    }
                    AlongSection(title: "About Along") {
                        SettingsAction(title: "Membership & purchases", symbol: "star") { showPaywall = true }
                        #if DEBUG
                        SettingsAction(title: "Review all 26 onboarding screens", symbol: "rectangle.stack") { showOnboardingReview = true }
                        #endif
                        LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development")
                        LabeledContent("Storage", value: "This device only")
                        LabeledContent("Journal processing", value: "On this device")
                    }
                    Text("Along is a personal GLP-1 journey and routine companion for adults. It doesn’t prescribe, diagnose, evaluate nutrition adequacy or guide medication. ").font(.caption).foregroundStyle(Theme.secondaryInk)
                }.padding(22).frame(maxWidth: 650)
            }.frame(maxWidth: .infinity).pageBackground().scrollDismissesKeyboard(.interactively).navigationTitle("You").navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showPrivacy) { PrivacyView() }
                .sheet(isPresented: $showBackup) { JournalBackupView(journal: { store.journal }, replace: store.restoreJournal) }
                .sheet(isPresented: $showPaywall) { PaywallPreview() }
                #if DEBUG
                .sheet(isPresented: $showOnboardingReview) { OnboardingCatalogView() }
                #endif
                .confirmationDialog(resetAction == "all" ? "Delete your local journal?" : resetAction == "sample" ? "Replace your journal with sample data?" : "Start a blank journal?", isPresented: Binding(get: { resetAction != nil }, set: { if !$0 { resetAction = nil } }), titleVisibility: .visible) {
                    Button(resetAction == "all" ? "Delete all local data" : "Replace journal", role: .destructive) {
                        let action = resetAction; resetAction = nil
                        #if DEBUG
                        if action == "sample" { store.loadSample(); return }
                        if action == "blank" { store.startBlank(); return }
                        #endif
                        Task {
                            if reminders.deliveryEnabled, !(await reminders.reset()) {
                                store.error = "Reminders could not be removed. Your journal has been kept. Please try deleting again."
                                return
                            }
                            store.clearJournal()
                        }
                    }
                } message: { Text("This replaces entries on this device and cannot be undone. Export first if you want to keep a copy.") }
        }
    }
}

struct PrivacyView: View {
    @Environment(BillingStore.self) private var billing
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                AlongSection(title: "Your journal stays with you") {
                    Text("Your name, check-ins, notes, milestones, routines, fictional pet discoveries and optional weight records are stored in this app’s private device storage, protected by iOS file protection. Along marks the journal folder to be excluded from automatic backups; iOS ultimately controls device backup behaviour.")
                    Text("No journal entries are sent to an AI service, analytics provider or Along cloud server. Deleting the app removes the local journal. Use Backup & restore to keep a recoverable copy in a place you choose.")
                }
                AlongSection(title: "Copies you choose to save") {
                    Text("A readable export contains your notes, mood, appetite, routines and any weight records. A restorable backup also contains preferences and Pip’s progress. Backup files are unencrypted. Review the contents and destination before sharing or saving them.")
                    Text("Delete all local data clears the journal, setup and reminder preferences on this device. It does not delete copies you exported, cancel an App Store subscription or delete records Apple retains for purchases.")
                }
                AlongSection(title: "Reminders & membership") {
                    Text("Reminders are optional local notifications. They contain no journal or health details. Notification times are stored in this app’s preferences; iOS controls permission and delivery.")
                    Text(billing.isConfigured ? "Apple processes subscriptions. Superwall supports membership purchases and configuration. Event analytics are disabled, and Along sends no journal, health or profile attributes to Superwall. Purchase and device information may still be processed to provide billing." : "Membership purchases are not configured in this build. No Superwall service is started without complete billing configuration.")
                    if let config = billing.configuration.value { Link("Read the full privacy policy", destination: config.privacyURL) }
                }
                }.padding(22).frame(maxWidth: 650)
            }.frame(maxWidth: .infinity).pageBackground().navigationTitle("Privacy & your journal").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
