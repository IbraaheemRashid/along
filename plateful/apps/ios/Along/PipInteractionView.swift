import SwiftUI

/// Petting is always available and has no bearing on journal progress or unlocks.
struct PipPlayground: View {
    var name: String
    var accessory: Accessory
    var message = "A little company for today."
    var height: CGFloat = 250
    @Environment(\.alongReducedMotion) private var reduceMotion
    @State private var greetings = 0
    @State private var reacting = false
    var body: some View {
        VStack(spacing: 9) {
            Button(action: greet) {
                PipRoomView(accessory: accessory, pose: reacting ? .celebrate : .welcome,
                            message: reacting ? "Hello, little friend." : message, height: height)
                    .overlay(alignment: .trailing) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill").font(.title3)
                            Image(systemName: "heart.fill").font(.caption)
                        }.foregroundStyle(Theme.peach).padding(.trailing, 26)
                            .opacity(reacting ? 1 : 0)
                            .offset(y: reduceMotion ? 0 : (reacting ? -10 : 10))
                            .accessibilityHidden(true)
                    }.clipShape(RoundedRectangle(cornerRadius: 28))
            }.buttonStyle(.plain).accessibilityLabel("Say hello to \(name)")
                .accessibilityValue(reacting ? "Hello, little friend." : message)
                .accessibilityHint("Tap or hold to pet your companion")
                .accessibilityIdentifier("pet.greet")
                .onLongPressGesture(minimumDuration: 0.35, perform: greet)
                .sensoryFeedback(.selection, trigger: greetings)
            Text("Tap \(name) to say hello").font(.caption).foregroundStyle(Theme.secondaryInk)
        }.task(id: greetings) {
            guard greetings > 0 else { return }
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { reacting = false }
        }
    }
    private func greet() {
        greetings += 1
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { reacting = true }
    }
}

struct PipStoryView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let story: PipStory
    @State private var choice: PipStory.Choice?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PipRoomView(accessory: store.journal.accessory, pose: choice == nil ? .journal : .celebrate, height: 215)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                    Pill(text: "A little story with \(store.companionName)", symbol: story.symbol)
                    Text(choice == nil ? story.title : "Something to remember.").alongTitle(30)
                    Text(choice?.reply ?? story.prompt).font(.system(.body, design: .rounded)).lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading).card()
                    if let choice {
                        Label(choice.discovery, systemImage: story.symbol).font(.headline).foregroundStyle(Theme.accent)
                            .frame(maxWidth: .infinity, alignment: .leading).card()
                            .accessibilityIdentifier("pet.discovery.saved")
                        Text("Kept in \(store.companionName)’s little discoveries.").font(.caption).foregroundStyle(Theme.secondaryInk)
                        PrimaryButton(title: "Back to \(store.companionName)") { dismiss() }
                    } else {
                        ForEach(story.choices) { option in
                            SetupChoice(title: option.title, symbol: story.symbol, identifier: "pet.story.\(option.id)") {
                                if store.rememberPipStory(story, choice: option.id) { choice = option }
                            }
                        }
                    }
                    Text("A fictional story for a little company.").font(.caption).foregroundStyle(Theme.secondaryInk)
                }.padding(22).frame(maxWidth: 620)
            }.frame(maxWidth: .infinity).pageBackground().navigationTitle("A moment with \(store.companionName)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
        }
    }
}
