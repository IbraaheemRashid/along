import SwiftUI

struct SettingsView: View {
    @Environment(JournalStore.self) private var store
    @State private var showPrivacy = false
    @State private var showPaywall = false
    @State private var resetAction: String?
    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) { PipView(accessory: store.journal.accessory).frame(width: 75, height: 90); VStack(alignment: .leading, spacing: 8) { Text(store.journal.name.isEmpty ? "Your little space" : "\(store.journal.name)’s little space").font(.title3.weight(.semibold)); DemoBadge(); Text("Everything here stays on this device.").font(.caption).foregroundStyle(.secondary) } }.padding(.vertical, 8)
                }
                Section("Make it yours") {
                    TextField("Your first name", text: $store.journal.name).onChange(of: store.journal.name) { store.journal.name = String(store.journal.name.prefix(30)); store.persist() }
                    TextField("Companion name", text: $store.journal.companionName).onChange(of: store.journal.companionName) { store.journal.companionName = String(store.journal.companionName.prefix(24)); store.persist() }
                    ForEach(Routine.allCases) { routine in
                        Toggle(isOn: Binding(get: { store.journal.routines.contains(routine) }, set: { if $0 { store.journal.routines.insert(routine) } else { store.journal.routines.remove(routine) }; store.persist() })) { Label(routine.shortTitle, systemImage: routine.symbol) }
                    }
                }
                Section {
                    Toggle("Show weight in my journey", isOn: $store.journal.showWeight).onChange(of: store.journal.showWeight) { store.persist() }
                    Picker("Weight display", selection: $store.journal.weightUnit) { ForEach(WeightUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.onChange(of: store.journal.weightUnit) { store.persist() }
                } header: { Text("Optional records") } footer: { Text("Hiding weight leaves your records intact. It never changes your companion’s progress.") }
                Section("Your data") {
                    Button { showPrivacy = true } label: { Label("Privacy & your journal", systemImage: "lock") }
                    ShareLink(item: store.exportText, preview: SharePreview("Along journal export")) { Label("Export my journal", systemImage: "square.and.arrow.up") }
                    Button { resetAction = "blank" } label: { Label("Start a blank journal", systemImage: "book") }
                    Button { resetAction = "sample" } label: { Label("Load the sample journey", systemImage: "sparkles") }
                    Button(role: .destructive) { resetAction = "all" } label: { Label("Delete all local data", systemImage: "trash") }
                }
                Section {
                    Button { showPaywall = true } label: { Label("Explore Along Plus — preview", systemImage: "star") }
                    LabeledContent("Version", value: "0.1 · prototype")
                    LabeledContent("Storage", value: "This device only")
                    LabeledContent("AI & cloud services", value: "Not connected")
                } footer: { Text("Along is an adult GLP-1 journey and routine prototype. It doesn’t prescribe, diagnose, evaluate nutrition adequacy or guide medication. Along and Pip are working names.") }
            }.scrollContentBackground(.hidden).pageBackground().navigationTitle("You").navigationBarTitleDisplayMode(.large)
                .sheet(isPresented: $showPrivacy) { PrivacyView() }
                .sheet(isPresented: $showPaywall) { PaywallPreview() }
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
            List {
                Section("This prototype") { Text("Your name, check-ins, notes, milestones and optional weight records are saved to a file in this app’s private device storage. The file uses iOS file protection and is excluded from device backups."); Text("No account is created. No entries go to an AI service, analytics provider or cloud server. Deleting the app removes this local journal; it cannot currently be recovered or synced.") }
                Section("You’re in control") { Text("Export creates a readable copy containing your notes, mood, appetite and any weight records. Review what you share and who receives it. Deleting data in Along does not delete copies you already exported."); Text("Use Delete all local data in You to clear your entries and preferences. Sample records are fictional and labelled throughout.") }
                Section("Before a public release") { Text("Account, sync, privacy terms, clinical content review, analytics consent and billing are not connected. Any future cloud processing will need clear disclosures and appropriate permissions before activation.") }
            }.navigationTitle("Privacy & your journal").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

struct PaywallPreview: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showRestoreInfo = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PipView(accessory: .flower, wave: true).frame(height: 200).frame(maxWidth: .infinity).background(Theme.lilac.opacity(0.35), in: RoundedRectangle(cornerRadius: 28))
                    Pill(text: "PRICING CONCEPT · NO PURCHASE", symbol: "info.circle")
                    Text("More room\nfor your journey.").alongTitle(35)
                    Text("Along Plus is a proposed future plan. The local prototype is fully available without paying.").foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 18) {
                        Label("Richer weekly reflections", systemImage: "book.pages")
                        Label("More companion stories & looks", systemImage: "pawprint")
                        Label("Private backup & sync", systemImage: "icloud")
                    }.font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, alignment: .leading).card()
                    VStack(alignment: .leading, spacing: 8) { Text("$29.99 / year").font(.title2.weight(.semibold)); Text("Illustrative US price. No subscription, trial or charge starts here. These future features are not connected.").font(.caption).foregroundStyle(.secondary) }.card()
                    PrimaryButton(title: "Keep exploring for free", symbol: "arrow.right") { dismiss() }
                    Button("Restore purchases") { showRestoreInfo = true }.frame(maxWidth: .infinity, minHeight: 44)
                }.padding(24).frame(maxWidth: 620)
            }.frame(maxWidth: .infinity).pageBackground().navigationTitle("Along Plus preview").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
                .alert("No store is connected", isPresented: $showRestoreInfo) { Button("OK", role: .cancel) {} } message: { Text("This prototype cannot make or restore purchases. No subscription has been created.") }
        }
    }
}
