import SwiftUI

struct OnboardingView: View {
    @Environment(JournalStore.self) private var store
    @State private var step = 0
    @State private var name = ""
    @State private var companion = "Pip"
    @State private var routines: Set<Routine> = [.nutrition, .movement, .reflection]
    @State private var sample = true
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("along").font(.system(size: 30, weight: .semibold, design: .serif)).foregroundStyle(Theme.accent)
                    Spacer()
                    Text("\(step + 1) OF 3").font(.caption2.weight(.semibold)).tracking(1.6).foregroundStyle(.secondary)
                }.padding(.top, 15)
                HStack(spacing: 6) { ForEach(0..<3) { i in Capsule().fill(i <= step ? Theme.accent : .primary.opacity(0.08)).frame(height: 3) } }
                if step == 0 {
                    MeadowView().frame(height: 270).clipShape(RoundedRectangle(cornerRadius: 32))
                    Text("A little company.\nA journey that’s yours.").alongTitle(35).fixedSize(horizontal: false, vertical: true)
                    Text("Your GLP-1 journey is more than a number. Keep the moments, find your rhythm, and meet a little companion along the way.").foregroundStyle(.secondary).lineSpacing(3)
                    PrimaryButton(title: "Meet your companion") { withAnimation { step = 1 } }
                    Text("For adults • local prototype • no account needed").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                } else if step == 1 {
                    HStack(spacing: 15) { PipView(wave: true).frame(width: 100, height: 110); Text("Hi, I’m Pip.\nWe’ll take it one day at a time.").alongTitle(24) }
                    Text("Make this your space.").alongTitle(30)
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 9) { Text("What should we call you?").font(.subheadline.weight(.semibold)); TextField("Your first name (optional)", text: $name).textContentType(.givenName).padding(15).background(Theme.paper, in: RoundedRectangle(cornerRadius: 14)).onChange(of: name) { name = String(name.prefix(30)) } }
                        VStack(alignment: .leading, spacing: 9) { Text("Your companion’s name").font(.subheadline.weight(.semibold)); TextField("Pip", text: $companion).padding(15).background(Theme.paper, in: RoundedRectangle(cornerRadius: 14)).onChange(of: companion) { companion = String(companion.prefix(24)) } }
                    }.card()
                    Text("What would you like to make room for?").font(.headline)
                    ForEach(Routine.allCases) { routine in
                        Button { if routines.contains(routine) { routines.remove(routine) } else { routines.insert(routine) } } label: {
                            HStack(spacing: 14) {
                                Image(systemName: routine.symbol).font(.title3).frame(width: 24).foregroundStyle(Theme.accent)
                                VStack(alignment: .leading, spacing: 4) { Text(routine.shortTitle).font(.headline); Text(routine.description).font(.caption).foregroundStyle(.secondary) }
                                Spacer(minLength: 0); Image(systemName: routines.contains(routine) ? "checkmark.circle.fill" : "circle").foregroundStyle(Theme.accent)
                            }.card(padding: 17)
                        }.buttonStyle(.plain).accessibilityAddTraits(routines.contains(routine) ? .isSelected : [])
                    }
                    PrimaryButton(title: "Continue") { withAnimation { step = 2 } }
                    Button("Back") { withAnimation { step = 0 } }.frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    Text("A gentle beginning.").alongTitle(34)
                    Text("Explore what your journal could become, or start with a clean page.").foregroundStyle(.secondary)
                    ForEach([true, false], id: \.self) { option in
                        Button { sample = option } label: {
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: sample == option ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(Theme.accent)
                                VStack(alignment: .leading, spacing: 7) { Text(option ? "Explore a sample journey" : "Start my own journal").font(.headline); Text(option ? "Two weeks of fictional entries and milestones. Clearly labelled, easy to clear." : "No sample entries. Your first check-in starts the story.").font(.subheadline).foregroundStyle(.secondary) }
                            }.frame(maxWidth: .infinity, alignment: .leading).card()
                        }.buttonStyle(.plain).accessibilityAddTraits(sample == option ? .isSelected : [])
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Private by default", systemImage: "lock").font(.headline)
                        Text("This prototype saves entries only on this device. Nothing is sent to an AI service or analytics provider. Export or delete your journal in You.").font(.subheadline).foregroundStyle(.secondary)
                        Text("Along is a reflection and routine tool, not medical advice. It doesn’t guide medication, diagnose symptoms, or assess whether you’re eating enough.").font(.caption).foregroundStyle(.secondary)
                    }.card()
                    PrimaryButton(title: "Begin with \(companion.isEmpty ? "Pip" : companion)") { store.onboard(name: name, companion: companion, routines: routines, sample: sample) }
                    Button("Back") { withAnimation { step = 1 } }.frame(maxWidth: .infinity, minHeight: 44)
                }
            }.padding(24).frame(maxWidth: 620)
        }.frame(maxWidth: .infinity).pageBackground().scrollDismissesKeyboard(.interactively)
    }
}
