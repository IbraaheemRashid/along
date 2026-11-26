import SwiftUI

#if DEBUG
struct OnboardingCatalogView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selection: ReviewSelection?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 15) {
                                                VStack(alignment: .leading, spacing: 6) {
                            Text("\(SetupStep.allCases.count) setup screens").font(.title3.weight(.bold))
                            Text("Open any screen with example answers. Your own data stays untouched.").font(.subheadline).foregroundStyle(Theme.secondaryInk)
                        }
                    }
                }
                Section("Onboarding screens") {
                    ForEach(Array(SetupStep.allCases.enumerated()), id: \.offset) { index, step in
                        Button { selection = ReviewSelection(id: step) } label: {
                            HStack(spacing: 14) {
                                Text(String(format: "%02d", index + 1)).font(.caption.monospacedDigit()).foregroundStyle(Theme.accent).frame(width: 28)
                                Text(step.reviewTitle).font(.subheadline).foregroundStyle(.primary)
                                Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.secondaryInk)
                            }.padding(.vertical, 9)
                        }.accessibilityIdentifier("dev.onboarding.\(step.rawValue)").listRowBackground(Theme.card)
                    }
                }
            }.scrollContentBackground(.hidden).pageBackground().navigationTitle("Design review").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.accessibilityIdentifier("dev.onboarding.catalogue.close") } }
                .fullScreenCover(item: $selection) { selection in OnboardingScreenPreview(step: selection.id) }
        }
    }
    private struct ReviewSelection: Identifiable { var id: SetupStep }
}

private struct OnboardingScreenPreview: View {
    @Environment(\.dismiss) private var dismiss
    @State private var previewStore: JournalStore
    @State private var billing = BillingStore(configuration: .unconfigured(["Isolated onboarding review"]))
    @State private var reminders = ReminderStore(deliveryEnabled: false)
    init(step: SetupStep) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AlongScreenReview-\(UUID().uuidString)", isDirectory: true)
        let store = JournalStore(directory: directory, arguments: [], clearCredentials: {})
        store.setup = step == .welcome ? SetupDraft() : SetupDraft.example(at: step)
        _previewStore = State(initialValue: store)
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("DESIGN REVIEW · EXAMPLE ANSWERS").font(.system(size: 9, weight: .bold)).tracking(0.8).foregroundStyle(Theme.secondaryInk)
                Spacer()
                Button("Done") { dismiss() }.font(.subheadline).accessibilityIdentifier("dev.onboarding.close")
            }.padding(.horizontal, 24).padding(.vertical, 10).background(Theme.paper)
            RootView(showsDevTools: false).environment(previewStore).environment(billing).environment(reminders)
                .environment(AuthStore()).environment(CloudSync())
        }
    }
}
extension SetupStep {
    var reviewTitle: String {
        switch self {
        case .welcome: "Welcome"
        case .experience: "Experience level"
        case .goals: "Goals"
        case .source: "Where did you hear about us"
        case .showcase: "Know what you took"
        case .pinMap: "Pin site body map"
        case .birthday: "Date of birth"
        case .weight: "Current weight (weight goals only)"
        case .target: "Goal weight (weight goals only)"
        case .commitment: "Consistency"
        case .compounds: "Peptide picker"
        case .frequency: "Dose frequency"
        case .doseTime: "Usual dose time"
        case .obstacles: "What gets in the way"
        case .trust: "Thank you for trusting us"
        case .reminders: "Dose reminders"
        case .referral: "Referral code"
        case .ready: "Time to build"
        case .building: "Building your protocol"
        case .plan: "Your protocol"
        case .account: "Create account"
        case .paywall: "Paywall"
        }
    }
}
#endif
