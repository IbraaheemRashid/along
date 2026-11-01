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
                        PipArtwork().frame(width: 80, height: 90)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("26 little steps.").alongTitle(25)
                            Text("Open any screen with example answers. Your own journal stays untouched.").font(.subheadline).foregroundStyle(Theme.secondaryInk)
                        }
                    }
                }
                Section("Onboarding screens") {
                    ForEach(0..<26, id: \.self) { step in
                        Button { selection = ReviewSelection(id: step) } label: {
                            HStack(spacing: 14) {
                                Text(String(format: "%02d", step + 1)).font(.caption.monospacedDigit()).foregroundStyle(Theme.accent).frame(width: 28)
                                Text(OnboardingView.titles[step].replacingOccurrences(of: "\n", with: " ")).font(.subheadline).foregroundStyle(.primary)
                                Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.secondaryInk)
                            }.padding(.vertical, 9)
                        }.accessibilityIdentifier("dev.onboarding.\(step + 1)").listRowBackground(Theme.card)
                    }
                }
            }.scrollContentBackground(.hidden).pageBackground().navigationTitle("Design review").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.accessibilityIdentifier("dev.onboarding.catalogue.close") } }
                .fullScreenCover(item: $selection) { selection in OnboardingScreenPreview(step: selection.id) }
        }
    }
    private struct ReviewSelection: Identifiable { var id: Int }
}

private struct OnboardingScreenPreview: View {
    @Environment(\.dismiss) private var dismiss
    @State private var previewStore: JournalStore
    init(step: Int) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AlongScreenReview-\(UUID().uuidString)", isDirectory: true)
        let store = JournalStore(directory: directory, arguments: [], clearCredentials: {})
        store.onboardingDraft = OnboardingView.exampleDraft(at: step)
        _previewStore = State(initialValue: store)
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("DESIGN REVIEW · EXAMPLE ANSWERS").font(.system(size: 9, weight: .bold)).tracking(0.8).foregroundStyle(Theme.secondaryInk)
                Spacer()
                Button("Done") { dismiss() }.font(.subheadline).accessibilityIdentifier("dev.onboarding.close")
            }.padding(.horizontal, 24).padding(.vertical, 10).background(Theme.paper)
            RootView(showsDevTools: false).environment(previewStore)
        }
    }
}
#endif
