import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@main struct AlongApp: App {
    @State private var store: JournalStore
    @State private var reminders: ReminderStore
    @State private var previewReminders: ReminderStore
    @State private var billing: BillingStore
    @State private var previewBilling: BillingStore
    @State private var attribution: AttributionStore
    @State private var analytics: AnalyticsClient
    @State private var health: HealthKitStore
    @State private var auth: AuthStore
    @State private var cloudSync: CloudSync

    init() {
        // Firebase must configure before any Auth/Firestore-touching state inits.
        CrashReporting.start()
        FirebaseBootstrap.configureIfNeeded()
        _store = State(initialValue: JournalStore())
        _reminders = State(initialValue: ReminderStore())
        _previewReminders = State(initialValue: ReminderStore(deliveryEnabled: false))
        _billing = State(initialValue: BillingStore(configuration: BillingConfiguration.forCurrentLaunch()))
        _previewBilling = State(initialValue: BillingStore(configuration: .unconfigured(["Local design preview"])))
        _attribution = State(initialValue: AttributionStore())
        _analytics = State(initialValue: AnalyticsClient())
        _health = State(initialValue: HealthKitStore())
        _auth = State(initialValue: AuthStore())
        _cloudSync = State(initialValue: CloudSync())
    }

    var body: some Scene {
        WindowGroup {
            RootView().environment(store)
                .environment(store.journal.isDesignPreview == true || store.journal.hasSampleData ? previewReminders : reminders)
                .environment(store.journal.isDesignPreview == true || store.journal.hasSampleData ? previewBilling : billing)
                .environment(attribution)
                .environment(analytics)
                .environment(health)
                .environment(auth)
                .environment(cloudSync)
                .tint(Theme.accent)
                .onOpenURL { url in
                    #if canImport(GoogleSignIn)
                    _ = GIDSignIn.sharedInstance.handle(url)
                    #endif
                }
                .task {
                    auth.start()
                    await attribution.start()
                    analytics.track(.init(name: "app_opened", feature: "settings", surface: "welcome", result: "success"))
                }
        }
    }
}
struct RootView: View {
    @Environment(JournalStore.self) private var store
    @Environment(ReminderStore.self) private var reminders
    @Environment(BillingStore.self) private var billing
    @Environment(AttributionStore.self) private var attribution
    @Environment(AuthStore.self) private var auth
    @Environment(CloudSync.self) private var cloudSync
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.alongReducedMotion) private var reduceMotion
    var showsDevTools = true
    #if DEBUG
    @State private var showDevLab = false
    #endif
    private var colorScheme: ColorScheme? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--ui-testing") && arguments.contains("--dark-review") { return .dark }
        #endif
        return nil
    }
    private var previewAccess: Bool {
        #if DEBUG
        store.journal.isDesignPreview == true
        #else
        false
        #endif
    }
    var body: some View {
        @Bindable var store = store
        Group {
            if !billing.hasCheckedEntitlements && !previewAccess {
                ProgressView("Opening your space…").frame(maxWidth: .infinity, maxHeight: .infinity).pageBackground()
            } else if store.journal.hasOnboarded && (billing.isEntitled || previewAccess) {
                TabView(selection: $store.selectedTab) {
                    HomeView().tabItem { Label("Today", systemImage: "house.fill") }.tag(0)
                    HealthDashboardView().tabItem { Label("Health", systemImage: "heart.text.square.fill") }.tag(1)
                    ProgressScreen().tabItem { Label("Progress", systemImage: "chart.bar.xaxis") }.tag(2)
                    SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }.tag(3)
                }
                .tint(SetupTheme.ink)
            } else if store.journal.hasOnboarded { MembershipView(canClose: false) }
            else { SetupFlowView() }
        }
        .preferredColorScheme(colorScheme)
        .task(id: ObjectIdentifier(billing)) { await billing.start() }
        .task(id: store.journal.hasOnboarded) {
            if store.journal.hasOnboarded {
                _ = await attribution.capture(from: store.journal.setupProfile ?? store.setup)
            }
        }
        .task(id: store.journal.protocolPeptides.map { "\($0.id.uuidString)|\($0.batchExpiryKey ?? "")|\($0.isPaused)" }) {
            if reminders.preferences.isEnabled {
                _ = await reminders.sync(sources: store.journal.reminderSources,
                                        batchExpiries: store.journal.batchExpiryReminderSources)
            }
        }
        .task(id: auth.user?.id) {
            await restoreCloudIfNeeded()
        }
        .onChange(of: store.journal) { _, _ in
            if let id = auth.user?.id {
                cloudSync.schedulePush(journal: store.journal, setup: store.setup, userID: id)
            }
        }
        .onChange(of: store.setup) { _, _ in
            if let id = auth.user?.id {
                cloudSync.schedulePush(journal: store.journal, setup: store.setup, userID: id)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.referenceDate = .now
                Task {
                    await billing.refresh()
                    await reminders.refresh()
                    if reminders.preferences.isEnabled {
                        _ = await reminders.sync(sources: store.journal.reminderSources,
                                                batchExpiries: store.journal.batchExpiryReminderSources)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in store.referenceDate = .now }
        #if DEBUG
        .overlay(alignment: .topTrailing) {
            if showsDevTools && !store.journal.hasOnboarded && store.setup.step == .welcome {
                Button { showDevLab = true } label: {
                    Image(systemName: "wrench.and.screwdriver").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SetupTheme.muted).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Dev Lab").accessibilityIdentifier("dev.open").padding(.trailing, 12)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if showsDevTools && store.journal.hasOnboarded {
                Button { showDevLab = true } label: {
                    Image(systemName: "wrench.and.screwdriver").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SetupTheme.muted).frame(width: 36, height: 36)
                        .background(.regularMaterial, in: Circle()).overlay(Circle().strokeBorder(SetupTheme.border))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Dev Lab").accessibilityIdentifier("dev.open")
                .padding(.leading, 6).padding(.bottom, 92)
            }
        }
        .sheet(isPresented: $showDevLab) { DevLabView() }
        #endif
        .overlay(alignment: .top) {
            if let toast = store.toast {
                Label(toast, systemImage: "checkmark.circle.fill").font(.subheadline.weight(.medium)).padding(15).background(.regularMaterial, in: Capsule()).padding(.horizontal, 20).padding(.top, 5).transition(.move(edge: .top).combined(with: .opacity)).accessibilityAddTraits(.updatesFrequently)
            }
        }.animation(reduceMotion ? nil : .spring(response: 0.35), value: store.toast)
            .alert("Something needs attention", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                Button("OK") { store.error = nil }
                if !store.journal.hasOnboarded {
                    Button("Restart setup") { store.error = nil; store.resetOnboarding() }
                }
                Button("Close", role: .cancel) { store.error = nil }
            } message: { Text(store.error ?? "") }
    }

    /// Returning members (local setup not finished) restore from the cloud.
    /// Once this device has finished onboarding, local answers win and we upload —
    /// so pay/preview sign-in never wipes the protocol just created.
    private func restoreCloudIfNeeded() async {
        guard let id = auth.user?.id else { return }
        if store.journal.hasOnboarded {
            await cloudSync.push(journal: store.journal, setup: store.setup, userID: id)
            return
        }
        if let remote = await cloudSync.pull(userID: id), remote.journal.hasOnboarded {
            _ = store.updateJournal { $0 = remote.journal }
            store.setup = remote.setup
            store.showToast("Restored from your account")
        }
    }
}
