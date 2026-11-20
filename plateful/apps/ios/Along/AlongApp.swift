import SwiftUI

@main struct AlongApp: App {
    @State private var store = JournalStore()
    @State private var reminders = ReminderStore()
    @State private var previewReminders = ReminderStore(deliveryEnabled: false)
    @State private var billing = BillingStore(configuration: BillingConfiguration.forCurrentLaunch())
    @State private var previewBilling = BillingStore(configuration: .unconfigured(["Local design preview"]))
    var body: some Scene {
        WindowGroup {
            RootView().environment(store)
                .environment(store.journal.isDesignPreview == true || store.journal.hasSampleData ? previewReminders : reminders)
                .environment(store.journal.isDesignPreview == true || store.journal.hasSampleData ? previewBilling : billing).tint(Theme.accent)
        }
    }
}
struct RootView: View {
    @Environment(JournalStore.self) private var store
    @Environment(BillingStore.self) private var billing
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
                    ProtocolView().tabItem { Label("Protocol", systemImage: "list.bullet.rectangle.portrait") }.tag(1)
                    JourneyView().tabItem { Label("Progress", systemImage: "chart.bar.xaxis") }.tag(2)
                    SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }.tag(3)
                }
                .tint(SetupTheme.ink)
            } else if store.journal.hasOnboarded { MembershipView(canClose: false) }
            else { SetupFlowView() }
        }
        .preferredColorScheme(colorScheme)
        .task(id: ObjectIdentifier(billing)) { await billing.start() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { store.referenceDate = .now; Task { await billing.refresh() } } }
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
}
