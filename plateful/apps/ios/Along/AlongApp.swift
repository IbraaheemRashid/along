import SwiftUI
import UserNotifications
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@MainActor @Observable final class ReminderInbox {
    static let shared = ReminderInbox()
    var pending: ReminderDestination?
}

final class AlongNotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
              let destination = ReminderDestination(identifier: response.notification.request.identifier,
                                                    deliveredAt: response.notification.date) else { return }
        await MainActor.run { ReminderInbox.shared.pending = destination }
    }
}

@main struct AlongApp: App {
    @UIApplicationDelegateAdaptor(AlongNotificationDelegate.self) private var notificationDelegate
    @State private var journals: AccountJournals
    @State private var reminders: ReminderStore
    @State private var previewReminders: ReminderStore
    @State private var billing: BillingStore
    @State private var previewBilling: BillingStore
    @State private var attribution: AttributionStore
    @State private var analytics: AnalyticsClient
    @State private var auth: AuthStore

    private struct ReminderSelection: Equatable {
        let profile: ObjectIdentifier
        let sources: [DoseReminderSource]
        let batches: [BatchExpiryReminderSource]
        let enabledForProfile: Bool
    }

    init() {
        // Firebase must configure before any Auth/Firestore-touching state inits.
        CrashReporting.start()
        FirebaseBootstrap.configureIfNeeded()
        let profiles = AccountJournals(device: JournalStore())
        let identity = AuthStore(journals: profiles)
        identity.start()
        _journals = State(initialValue: profiles)
        _auth = State(initialValue: identity)
        _reminders = State(initialValue: ReminderStore())
        _previewReminders = State(initialValue: ReminderStore(deliveryEnabled: false))
        _billing = State(initialValue: BillingStore(configuration: BillingConfiguration.forCurrentLaunch()))
        _previewBilling = State(initialValue: BillingStore(configuration: .unconfigured(["Local billing preview"])))
        _attribution = State(initialValue: AttributionStore())
        _analytics = State(initialValue: AnalyticsClient())
    }

    var body: some Scene {
        WindowGroup {
            let store = journals.active
            let ownsReminders = !journals.deletionPending && !journals.chooseDeviceJournal && store.journal.isDesignPreview != true && !store.journal.hasSampleData
            Group {
                if journals.deletionPending { AccountDeletionView() }
                else if journals.chooseDeviceJournal {
                    DeviceJournalChoice(openLocal: journals.openDeviceJournal)
                } else { RootView() }
            }
                .id(ObjectIdentifier(store))
                .environment(store)
                .environment(store.journal.isDesignPreview == true || store.journal.hasSampleData ? previewReminders : reminders)
                .environment(store.journal.isDesignPreview == true || store.journal.hasSampleData ? previewBilling : billing)
                .environment(attribution)
                .environment(analytics)
                .environment(auth)
                .environment(journals.sync)
                .tint(Theme.accent)
                .task(id: ReminderSelection(profile: ObjectIdentifier(store), sources: store.reminderSources,
                                            batches: store.journal.batchExpiryReminderSources, enabledForProfile: ownsReminders)) {
                    guard !Task.isCancelled, !journals.deletionPending else { return }
                    _ = await reminders.sync(sources: ownsReminders ? store.reminderSources : [],
                                             batchExpiries: ownsReminders ? store.journal.batchExpiryReminderSources : [])
                }
                .onOpenURL { url in
                    #if canImport(GoogleSignIn)
                    _ = GIDSignIn.sharedInstance.handle(url)
                    #endif
                }
                .task {
                    await attribution.start()
                    analytics.track(.init(name: "app_opened", feature: "app", surface: "launch", result: "success"))
                }
        }
    }
}
private struct DeviceJournalChoice: View {
    var openLocal: () -> Void
    @State private var showSignIn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Open a journal").font(.largeTitle.bold())
            Text("Sign in for your account history, or open the separate journal saved on this iPhone.")
                .foregroundStyle(.secondary)
            SetupPrimaryButton(title: "Sign in", identifier: "account.choose-sign-in") { showSignIn = true }
            Button("Open journal on this iPhone", action: openLocal)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(24)
        .sheet(isPresented: $showSignIn) { SetupSignInSheet(restoreBackup: nil) }
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
    @State private var reminderSheet: DoseSheet.Mode?
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
            if (!billing.hasCheckedEntitlements && !previewAccess) || (cloudSync.isSyncing && !store.hasPersonalRecords) {
                ProgressView("Opening your space…").frame(maxWidth: .infinity, maxHeight: .infinity).pageBackground()
            } else if store.journal.hasOnboarded && (billing.isEntitled || previewAccess) {
                VStack(spacing: 0) {
                    if previewAccess {
                        Text(store.journal.hasSampleData ? "Design preview · sample records" : "Design preview · local journal")
                            .font(.caption.weight(.medium))
                            .frame(maxWidth: .infinity).padding(.vertical, 4)
                            .background(SetupTheme.tile)
                            .accessibilityIdentifier("journal.preview")
                    }
                    TabView(selection: $store.selectedTab) {
                        HomeView().tabItem { Label("Today", systemImage: "house.fill") }.tag(0)
                        ProgressScreen().tabItem { Label("Progress", systemImage: "chart.bar.xaxis") }.tag(1)
                        SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }.tag(2)
                    }
                }
                .tint(SetupTheme.ink)
                .sheet(item: $reminderSheet) { DoseSheet(mode: $0) }
                .onChange(of: ReminderInbox.shared.pending, initial: true) { _, destination in
                    guard let destination else { return }
                    ReminderInbox.shared.pending = nil
                    guard let slot = store.slot(for: destination) else { return }
                    store.selectedTab = 0
                    reminderSheet = .slot(slot)
                }
            } else if store.journal.hasOnboarded { MembershipView(canClose: false) }
            else { SetupFlowView() }
        }
        .safeAreaInset(edge: .top) {
            if cloudSync.conflict != nil && !store.journal.hasOnboarded {
                AccountBackupChoice().padding(.horizontal)
            }
        }
        .preferredColorScheme(colorScheme)
        .task(id: ObjectIdentifier(billing)) { await billing.start() }
        .task(id: store.journal.hasOnboarded) {
            if store.journal.hasOnboarded {
                _ = await attribution.capture(from: store.journal.setupProfile ?? store.setup)
            }
        }
        .task(id: ObjectIdentifier(cloudSync)) { await cloudSync.prepare() }
        .onChange(of: store.journal) { _, _ in cloudSync.changed() }
        .onChange(of: store.setup) { _, _ in cloudSync.changed() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.referenceDate = .now
                Task {
                    await cloudSync.prepare()
                    await billing.refresh()
                    await reminders.refresh()
                    guard auth.journals == nil || auth.journals?.active === store else { return }
                    if reminders.preferences.isEnabled {
                        _ = await reminders.sync(sources: store.reminderSources,
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
                    .accessibilityIdentifier("journal.toast")
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

}
