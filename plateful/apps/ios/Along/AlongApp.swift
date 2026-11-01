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
            #if DEBUG
                .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--ui-testing") && ProcessInfo.processInfo.arguments.contains("--dark-review") ? .dark : nil)
            #endif
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
                    TodayView().tabItem { Label("Today", systemImage: "sun.max") }.tag(0)
                    JourneyView().tabItem { Label("Journey", systemImage: "point.topleft.down.to.point.bottomright.curvepath") }.tag(1)
                    CompanionView().tabItem { Label(store.companionName, systemImage: "pawprint") }.tag(2)
                    SettingsView().tabItem { Label("You", systemImage: "person.crop.circle") }.tag(3)
                }
            } else if store.journal.hasOnboarded { MembershipView(canClose: false) }
            else { OnboardingView() }
        }
        .task(id: ObjectIdentifier(billing)) { await billing.start() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { store.referenceDate = .now; Task { await billing.refresh() } } }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in store.referenceDate = .now }
        #if DEBUG
        .safeAreaInset(edge: UIDevice.current.userInterfaceIdiom == .pad ? .bottom : .top, spacing: 0) {
            if showsDevTools {
                HStack {
                    Text("LOCAL DEVELOPMENT").font(.system(size: 9, weight: .semibold)).tracking(1)
                    Spacer()
                    Button { showDevLab = true } label: { Label("Dev Lab", systemImage: "wrench.and.screwdriver").font(.system(size: 12, weight: .semibold)).frame(minHeight: 44) }
                        .accessibilityIdentifier("dev.open")
                }.padding(.horizontal, 20).foregroundStyle(Theme.accent).background(Theme.paper)
                    .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
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
