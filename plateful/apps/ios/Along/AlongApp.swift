import SwiftUI

@main struct AlongApp: App {
    @State private var store = JournalStore()
    var body: some Scene {
        WindowGroup {
            RootView().environment(store).tint(Theme.accent)
            #if DEBUG
                .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--ui-testing") && ProcessInfo.processInfo.arguments.contains("--dark-review") ? .dark : nil)
            #endif
        }
    }
}
struct RootView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.alongReducedMotion) private var reduceMotion
    var showsDevTools = true
    #if DEBUG
    @State private var showDevLab = false
    #endif
    var body: some View {
        @Bindable var store = store
        Group {
            if store.journal.hasOnboarded {
                TabView(selection: $store.selectedTab) {
                    TodayView().tabItem { Label("Today", systemImage: "sun.max") }.tag(0)
                    JourneyView().tabItem { Label("Journey", systemImage: "point.topleft.down.to.point.bottomright.curvepath") }.tag(1)
                    CompanionView().tabItem { Label(store.companionName, systemImage: "pawprint") }.tag(2)
                    SettingsView().tabItem { Label("You", systemImage: "person.crop.circle") }.tag(3)
                }
            } else { OnboardingView() }
        }
        #if DEBUG
        .safeAreaInset(edge: .top, spacing: 0) {
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
                Button("Try saving again") { store.error = nil; store.persist() }
                if !store.journal.hasOnboarded {
                    Button("Restart setup") { store.error = nil; store.resetOnboarding() }
                }
                Button("Close", role: .cancel) { store.error = nil }
            } message: { Text(store.error ?? "") }
    }
}
