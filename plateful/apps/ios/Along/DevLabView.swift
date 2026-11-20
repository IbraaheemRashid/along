import SwiftUI

#if DEBUG
private enum DevSession {
    static var scope: String { ProcessInfo.processInfo.arguments.contains("--ui-testing") ? "AlongDevLabUITests" : "AlongDevLab" }
    static var lastIDKey: String { "\(scope).lastID" }
    static var lastScenarioKey: String { "\(scope).lastScenario" }
    static var root: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent(scope, isDirectory: true) }
    static var lastDirectory: URL? {
        guard let id = UserDefaults.standard.string(forKey: lastIDKey), UUID(uuidString: id) != nil else { return nil }
        let directory = root.appendingPathComponent(id, isDirectory: true)
        return FileManager.default.fileExists(atPath: directory.appendingPathComponent("journal-v1.json").path) ? directory : nil
    }
    static var lastScenario: DevScenario { DevScenario(rawValue: UserDefaults.standard.string(forKey: lastScenarioKey) ?? "") ?? .sample }
}

private enum DevAppearance: String, CaseIterable, Identifiable {
    case system = "System", light = "Light", dark = "Dark"
    var id: String { rawValue }
    var scheme: ColorScheme? { switch self { case .system: nil; case .light: .light; case .dark: .dark } }
}

private enum DevTextSize: String, CaseIterable, Identifiable {
    case system = "System", large = "Large", extraLarge = "Extra large", accessibility = "Accessibility XXXL"
    var id: String { rawValue }
    var size: DynamicTypeSize? { switch self { case .system: nil; case .large: .large; case .extraLarge: .xxxLarge; case .accessibility: .accessibility5 } }
}

private enum DevScenario: String, CaseIterable, Identifiable {
    case fresh, resume, paywall, empty, sample, sparse
    var id: String { rawValue }
    var title: String {
        switch self {
        case .fresh: "Fresh onboarding"
        case .resume: "Resume setup halfway"
        case .paywall: "No-trial paywall"
        case .empty: "Empty protocol"
        case .sample: "Sample protocol"
        case .sparse: "Sparse dose history"
        }
    }
    var detail: String {
        switch self {
        case .fresh: "Start at the welcome screen with no answers."
        case .resume: "The peptide picker with example answers already saved."
        case .paywall: "Try both plans, unavailable checkout, restore and close."
        case .empty: "Onboarded with no peptides — check empty states."
        case .sample: "Fictional peptides, doses, notes and weight. Clearly labelled."
        case .sparse: "One peptide and a couple of logs."
        }
    }
    var symbol: String {
        switch self {
        case .fresh: "sparkles"
        case .resume: "arrow.clockwise"
        case .paywall: "lock"
        case .empty: "tray"
        case .sample: "syringe"
        case .sparse: "calendar.badge.clock"
        }
    }

    @MainActor func makeStore(directory existingDirectory: URL? = nil) -> JournalStore {
        let directory = existingDirectory ?? DevSession.root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = JournalStore(directory: directory, arguments: [], clearCredentials: {})
        switch self {
        case .fresh: break
        case .resume: store.setup = SetupDraft.example(at: .compounds)
        case .paywall: store.setup = SetupDraft.example(at: .paywall)
        case .empty, .sample, .sparse:
            var journal = Journal()
            journal.name = "Alex"
            journal.hasOnboarded = true
            journal.isDesignPreview = true
            if self != .empty {
                journal.addSampleProtocol()
                journal.showWeight = true
                if self == .sparse {
                    journal.peptides = Array(journal.protocolPeptides.prefix(1))
                    let id = journal.protocolPeptides.first?.id
                    journal.doseLogs = journal.protocolLogs.filter { $0.peptideID == id }.suffix(3).map { $0 }
                    journal.weights = Array(journal.weights.suffix(1))
                }
            }
            store.journal = journal
        }
        if store.persist() {
            UserDefaults.standard.set(directory.lastPathComponent, forKey: DevSession.lastIDKey)
            UserDefaults.standard.set(rawValue, forKey: DevSession.lastScenarioKey)
        }
        return store
    }
}

private enum DevSheet: String, Identifiable {
    case membership, data, weight
    var id: String { rawValue }
}

private struct DevLaunch: Identifiable {
    let id = UUID()
    let scenario: DevScenario
    let tab: Int
    let sheet: DevSheet?
    let store: JournalStore

    @MainActor init(scenario: DevScenario, tab: Int = 0, sheet: DevSheet? = nil, restoreLast: Bool = false) {
        self.scenario = scenario
        self.tab = tab
        self.sheet = sheet
        if restoreLast, let directory = DevSession.lastDirectory { store = JournalStore(directory: directory, arguments: [], clearCredentials: {}) }
        else { store = scenario.makeStore() }
        store.selectedTab = tab
    }
}

struct DevLabView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var launch: DevLaunch?
    @State private var appearance: DevAppearance = .system
    @State private var textSize: DevTextSize = .system
    @State private var reduceMotion = false
    @State private var showCatalogue = false
    @AppStorage(DevSession.lastIDKey) private var lastSessionID = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Test the local peptide tracker", systemImage: "wrench.and.screwdriver").font(.headline)
                    Text("New scenarios create separate sandboxes. Resume last sandbox reopens your saved test session. Your normal data stays untouched; seeded records are fictional and labelled.")
                        .font(.subheadline).foregroundStyle(SetupTheme.muted)
                    Button("Resume last sandbox", systemImage: "clock.arrow.circlepath") {
                        launch = DevLaunch(scenario: DevSession.lastScenario, restoreLast: true)
                    }.disabled(lastSessionID.isEmpty || DevSession.lastDirectory == nil).accessibilityIdentifier("dev.resumeLast")
                }
                Section("Onboarding") {
                    Button { showCatalogue = true } label: {
                        Label("Browse all \(SetupStep.allCases.count) screens", systemImage: "rectangle.stack")
                    }.accessibilityIdentifier("dev.onboarding")
                    ForEach([DevScenario.fresh, .resume, .paywall]) { scenario in scenarioButton(scenario) }
                }
                Section("Protocol scenarios") {
                    ForEach([DevScenario.empty, .sample, .sparse]) { scenario in scenarioButton(scenario) }
                }
                Section("Jump to a feature · sample data") {
                    feature("Today", symbol: "house.fill", tab: 0)
                    feature("Protocol", symbol: "list.bullet.rectangle.portrait", tab: 1)
                    feature("Progress", symbol: "chart.bar.xaxis", tab: 2)
                    feature("Settings", symbol: "gearshape", tab: 3)
                    feature("Membership offer", symbol: "lock", sheet: .membership)
                    feature("Log weight", symbol: "scalemass", sheet: .weight)
                }
                Section("Preview settings") {
                    Picker("Appearance", selection: $appearance) { ForEach(DevAppearance.allCases) { Text($0.rawValue).tag($0) } }
                    Picker("Text size", selection: $textSize) { ForEach(DevTextSize.allCases) { Text($0.rawValue).tag($0) } }
                    Toggle("Force reduced motion", isOn: $reduceMotion)
                }
                Section("Connection status") {
                    status("Local persistence", value: "Active in sandbox", symbol: "internaldrive")
                    status("App Store / Superwall", value: "Not connected · no charges", symbol: "creditcard")
                    status("Accounts and cloud sync", value: "Not connected", symbol: "icloud")
                    status("Reminders", value: "Disabled in previews", symbol: "bell")
                    status("Analytics", value: "Not connected", symbol: "chart.xyaxis.line")
                }
            }
            .scrollContentBackground(.hidden)
            .background(SetupTheme.tile)
            .navigationTitle("Dev Lab").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.accessibilityIdentifier("dev.close") } }
            .sheet(isPresented: $showCatalogue) { OnboardingCatalogView() }
            .fullScreenCover(item: $launch) { launch in
                DevSandboxView(launch: launch, appearance: $appearance, textSize: $textSize, reduceMotion: $reduceMotion)
            }
        }.preferredColorScheme(appearance.scheme)
    }

    private func scenarioButton(_ scenario: DevScenario) -> some View {
        Button { launch = DevLaunch(scenario: scenario) } label: {
            Label {
                VStack(alignment: .leading, spacing: 5) {
                    Text(scenario.title).foregroundStyle(.primary)
                    Text(scenario.detail).font(.caption).foregroundStyle(SetupTheme.muted)
                }.padding(.vertical, 4)
            } icon: { Image(systemName: scenario.symbol).frame(width: 25) }
        }.accessibilityIdentifier("dev.scenario.\(scenario.rawValue)")
    }

    private func feature(_ title: String, symbol: String, tab: Int = 0, sheet: DevSheet? = nil) -> some View {
        Button { launch = DevLaunch(scenario: .sample, tab: tab, sheet: sheet) } label: { Label(title, systemImage: symbol) }
            .accessibilityIdentifier("dev.feature.\(sheet?.rawValue ?? "tab\(tab)")")
    }

    private func status(_ title: String, value: String, symbol: String) -> some View {
        Label { VStack(alignment: .leading, spacing: 4) { Text(title); Text(value).font(.caption).foregroundStyle(SetupTheme.muted) } } icon: { Image(systemName: symbol) }
    }
}

private struct DevSandboxView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var systemTextSize
    let launch: DevLaunch
    @Binding var appearance: DevAppearance
    @Binding var textSize: DevTextSize
    @Binding var reduceMotion: Bool
    @State private var store: JournalStore
    @State private var reminders = ReminderStore(deliveryEnabled: false)
    @State private var billing = BillingStore(configuration: .unconfigured(["Isolated development preview"]))
    @State private var sheet: DevSheet?
    @State private var presentedInitialFeature = false
    @State private var showReset = false

    init(launch: DevLaunch, appearance: Binding<DevAppearance>, textSize: Binding<DevTextSize>, reduceMotion: Binding<Bool>) {
        self.launch = launch
        _appearance = appearance
        _textSize = textSize
        _reduceMotion = reduceMotion
        _store = State(initialValue: launch.store)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Tools") { dismiss() }.accessibilityIdentifier("dev.sandbox.close")
                Spacer()
                VStack(spacing: 2) {
                    Text("DEV SANDBOX").font(.system(size: 10, weight: .bold)).tracking(1).accessibilityIdentifier("dev.sandbox.banner")
                    Text(launch.scenario.title).font(.system(size: 10)).foregroundStyle(SetupTheme.muted)
                }
                Spacer()
                Menu {
                    Picker("Appearance", selection: $appearance) { ForEach(DevAppearance.allCases) { Text($0.rawValue).tag($0) } }
                    Picker("Text size", selection: $textSize) { ForEach(DevTextSize.allCases) { Text($0.rawValue).tag($0) } }
                    Toggle("Force reduced motion", isOn: $reduceMotion)
                    Divider()
                    Button("Inspect sandbox JSON", systemImage: "curlybraces") { sheet = .data }
                    Button("Reload saved state from disk", systemImage: "internaldrive") {
                        let tab = store.selectedTab
                        store = JournalStore(directory: store.developmentStorageDirectory, arguments: [], clearCredentials: {})
                        store.selectedTab = tab
                    }.accessibilityIdentifier("dev.reloadSaved")
                    Button("Preview save-error alert", systemImage: "exclamationmark.triangle") {
                        store.error = "Simulated save-error preview. Close this alert to continue testing this sandbox."
                    }
                    Button("Reload this scenario", systemImage: "arrow.counterclockwise") { showReset = true }
                } label: { Image(systemName: "slider.horizontal.3").frame(width: 44, height: 36) }
                .accessibilityLabel("Sandbox controls").accessibilityIdentifier("dev.sandbox.controls")
            }.font(.system(size: 14, weight: .medium)).padding(.horizontal, 16).padding(.vertical, 5).background(SetupTheme.surface)
                .dynamicTypeSize(.large)
            RootView(showsDevTools: false).environment(store).environment(reminders).environment(billing)
                .environment(AttributionStore()).environment(AnalyticsClient())
                .id(ObjectIdentifier(store))
                .dynamicTypeSize(textSize.size ?? systemTextSize)
                .environment(\.alongForcedReducedMotion, reduceMotion)
        }.preferredColorScheme(appearance.scheme)
            .sheet(item: $sheet) { item in
                sandboxSheet(item).environment(store).environment(reminders).environment(billing)
                    .environment(AttributionStore()).environment(AnalyticsClient())
                    .dynamicTypeSize(textSize.size ?? systemTextSize)
                    .environment(\.alongForcedReducedMotion, reduceMotion)
                    .safeAreaInset(edge: .bottom) {
                        Text("DEV SANDBOX · SAMPLE DATA").font(.system(size: 10, weight: .semibold)).padding(8)
                            .frame(maxWidth: .infinity).background(SetupTheme.surface)
                    }
            }
            .confirmationDialog("Reload this sandbox?", isPresented: $showReset, titleVisibility: .visible) {
                Button("Discard sandbox edits and reload", role: .destructive) {
                    let directory = store.developmentStorageDirectory
                    store.clearJournal()
                    store = launch.scenario.makeStore(directory: directory)
                    store.selectedTab = launch.tab
                }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Only the edits in this test scenario are replaced. Your normal data is untouched.") }
            .onAppear {
                if !presentedInitialFeature { presentedInitialFeature = true; sheet = launch.sheet }
            }
    }

    @ViewBuilder private func sandboxSheet(_ item: DevSheet) -> some View {
        switch item {
        case .membership: MembershipView(canClose: true)
        case .weight: WeightLogSheet()
        case .data: DevJournalInspector(journal: store.journal, draft: store.onboardingDraft, setup: store.setup)
        }
    }
}

private struct DevJournalInspector: View {
    @Environment(\.dismiss) private var dismiss
    var journal: Journal
    var draft: OnboardingDraft
    var setup: SetupDraft
    private var text: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let record = (try? encoder.encode(journal)).flatMap { String(data: $0, encoding: .utf8) } ?? "Unable to encode journal."
        let onboarding = (try? encoder.encode(draft)).flatMap { String(data: $0, encoding: .utf8) } ?? "Unable to encode onboarding draft."
        let peptideSetup = (try? encoder.encode(setup)).flatMap { String(data: $0, encoding: .utf8) } ?? "Unable to encode setup."
        return "SANDBOX JOURNAL\n\n\(record)\n\nSETUP DRAFT\n\n\(peptideSetup)\n\nLEGACY ONBOARDING DRAFT\n\n\(onboarding)"
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Sandbox data only. This view never reads your normal journal.").font(.subheadline).foregroundStyle(SetupTheme.muted)
                    Text(text).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            }.background(SetupTheme.tile).navigationTitle("Sandbox data").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
#endif
