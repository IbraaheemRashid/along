import SwiftUI

struct SettingsView: View {
    @Environment(JournalStore.self) private var store
    @State private var showPrivacy = false
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
                            TextField("Your first name", text: $store.journal.name).frame(minHeight: 44).onChange(of: store.journal.name) { store.journal.name = String(store.journal.name.prefix(30)); store.persist() }
                            Divider()
                            Text("Companion name").font(.caption).foregroundStyle(Theme.secondaryInk)
                            TextField("Companion name", text: $store.journal.companionName).frame(minHeight: 44).onChange(of: store.journal.companionName) { store.journal.companionName = String(store.journal.companionName.prefix(24)); store.persist() }
                        }
                        Divider()
                        ForEach(Routine.allCases) { routine in
                            Toggle(isOn: Binding(get: { store.journal.routines.contains(routine) }, set: { if $0 { store.journal.routines.insert(routine) } else { store.journal.routines.remove(routine) }; store.persist() })) { Label(routine.shortTitle, systemImage: routine.symbol).font(.subheadline) }.frame(minHeight: 44)
                        }
                    }
                    AlongSection(title: "Optional records") {
                        Toggle("Show weight in my journey", isOn: $store.journal.showWeight).onChange(of: store.journal.showWeight) { store.persist() }.frame(minHeight: 44)
                        Picker("Weight display", selection: $store.journal.weightUnit) { ForEach(WeightUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.onChange(of: store.journal.weightUnit) { store.persist() }.frame(minHeight: 44)
                        Text("Hiding weight leaves your records intact. It never changes your companion’s progress.").font(.caption).foregroundStyle(Theme.secondaryInk)
                    }
                    AlongSection(title: "Your data") {
                        SettingsAction(title: "Privacy & your journal", symbol: "lock") { showPrivacy = true }
                        ShareLink(item: store.exportText, preview: SharePreview("Along journal export")) {
                            HStack(spacing: 12) { AlongIcon(symbol: "square.and.arrow.up", apricot: true); Text("Export my journal").font(.subheadline.weight(.medium)); Spacer() }.frame(minHeight: 48)
                        }
                        SettingsAction(title: "Start a blank journal", symbol: "book") { resetAction = "blank" }
                        SettingsAction(title: "Load the sample journey", symbol: "sparkles") { resetAction = "sample" }
                        SettingsAction(title: "Delete all local data", symbol: "trash", destructive: true) { resetAction = "all" }
                    }
                    AlongSection(title: "About Along") {
                        SettingsAction(title: "Explore Along Plus — preview", symbol: "star") { showPaywall = true }
                        #if DEBUG
                        SettingsAction(title: "Review all 26 onboarding screens", symbol: "rectangle.stack") { showOnboardingReview = true }
                        #endif
                        LabeledContent("Version", value: "0.3 · design preview")
                        LabeledContent("Storage", value: "This device only")
                        LabeledContent("AI & cloud services", value: "Not connected")
                    }
                    Text("Along is an adult GLP-1 journey and routine prototype. It doesn’t prescribe, diagnose, evaluate nutrition adequacy or guide medication. Along and Pip are working names.").font(.caption).foregroundStyle(Theme.secondaryInk)
                }.padding(22).frame(maxWidth: 650)
            }.frame(maxWidth: .infinity).pageBackground().scrollDismissesKeyboard(.interactively).navigationTitle("You").navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showPrivacy) { PrivacyView() }
                .sheet(isPresented: $showPaywall) { PaywallPreview() }
                #if DEBUG
                .sheet(isPresented: $showOnboardingReview) { OnboardingCatalogView() }
                #endif
                .confirmationDialog(resetAction == "all" ? "Delete your local journal?" : resetAction == "sample" ? "Replace your journal with sample data?" : "Start a blank journal?", isPresented: Binding(get: { resetAction != nil }, set: { if !$0 { resetAction = nil } }), titleVisibility: .visible) {
                    Button(resetAction == "all" ? "Delete all local data" : "Replace journal", role: .destructive) {
                        switch resetAction { case "sample": store.loadSample(); case "blank": store.startBlank(); default: store.clearJournal() }; resetAction = nil
                    }
                } message: { Text("This replaces entries on this device and cannot be undone. Export first if you want to keep a copy.") }
        }
    }
}

struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                AlongSection(title: "This prototype") { Text("Your name, check-ins, notes, milestones, fictional pet-story choices and optional weight records are saved to a file in this app’s private device storage. The file uses iOS file protection and is excluded from device backups."); Text("No account is created. No entries go to an AI service, analytics provider or cloud server. Deleting the app removes this local journal; it cannot currently be recovered or synced.") }
                AlongSection(title: "You’re in control") { Text("Export creates a readable copy containing your notes, mood, appetite and any weight records. Review what you share and who receives it. Deleting data in Along does not delete copies you already exported."); Text("Use Delete all local data in You to clear your entries and preferences. Sample records are fictional and labelled throughout.") }
                AlongSection(title: "Before a public release") { Text("Account, sync, privacy terms, clinical content review, analytics consent and billing are not connected. Any future cloud processing will need clear disclosures and appropriate permissions before activation.") }
                }.padding(22).frame(maxWidth: 650)
            }.frame(maxWidth: .infinity).pageBackground().navigationTitle("Privacy & your journal").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

struct PaywallPreview: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var plan: OnboardingPlan = .annual
    @State private var showStoreInfo = false
    @State private var showTerms = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SetupHero(pose: .journal, accessory: store.journal.accessory, height: 200)
                    Text("Keep your story growing.").alongTitle(34)
                    Text("Your personal record, weekly reflections and a little company along the way.").foregroundStyle(Theme.secondaryInk)
                    Pill(text: "No free trial", symbol: "checkmark")
                    MembershipPlans(selection: $plan)
                    MembershipDisclosure(plan: plan)
                    PrimaryButton(title: plan == .annual ? "Subscribe for $29.99 / year" : "Subscribe for $5.99 / month", symbol: "lock.open") { showStoreInfo = true }
                    Text("DESIGN PREVIEW · BILLING NOT CONNECTED").font(.caption2.weight(.medium)).foregroundStyle(Theme.secondaryInk)
                    Text("No charge can be made in this local build.").font(.caption).foregroundStyle(Theme.secondaryInk)
                    HStack { Button("Restore purchases") { showStoreInfo = true }; Spacer(); Button("Terms") { showTerms = true } }.font(.subheadline).frame(minHeight: 44)
                }.padding(24).frame(maxWidth: 560)
            }.frame(maxWidth: .infinity).pageBackground().navigationTitle("Along membership").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
                .sheet(isPresented: $showTerms) { MembershipTermsView() }
                .alert("Purchases aren’t connected", isPresented: $showStoreInfo) { Button("OK", role: .cancel) {} } message: { Text("This preview cannot make or restore purchases. No subscription has been created.") }
                .onAppear { plan = store.journal.onboardingPreferences?.plan ?? .annual }
        }
    }
}
