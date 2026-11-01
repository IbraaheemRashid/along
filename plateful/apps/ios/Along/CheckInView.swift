import SwiftUI

struct CheckInView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var entry: CheckIn?
    init(entry: CheckIn? = nil) { _entry = State(initialValue: entry) }
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.alongReducedMotion) private var reduceMotion
    @State private var day = Date()
    @State private var mood: Mood?
    @State private var appetite: Appetite?
    @State private var routines: Set<Routine> = []
    @State private var note = ""
    @State private var saved = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if saved {
                        PipRoomView(accessory: store.journal.accessory, pose: .celebrate, height: 235).clipShape(RoundedRectangle(cornerRadius: 28))
                        Text("A little moment.\nA part of your story.").alongTitle(34)
                        Text(mood == .tough ? "There’s room for the harder days here, too. Thank you for recording how today really felt." : "Your check-in is saved. You don’t have to do anything else to make today count.").foregroundStyle(Theme.secondaryInk).lineSpacing(4)
                        ViewThatFits(in: .horizontal) {
                            HStack { Pill(text: mood?.shortTitle ?? "", symbol: mood?.symbol); Pill(text: "Saved on this device", symbol: "checkmark") }
                            VStack(alignment: .leading) { Pill(text: mood?.shortTitle ?? "", symbol: mood?.symbol); Pill(text: "Saved on this device", symbol: "checkmark") }
                        }
                        PipProgressCard()
                        PrimaryButton(title: "Back to my day") { dismiss() }
                        Button("See my journey") { store.selectedTab = 1; dismiss() }.frame(maxWidth: .infinity, minHeight: 44)
                    } else {
                        CompanionHeading(title: "How are you, really?", detail: "No right answers. No perfect days.", accessory: store.journal.accessory, pose: .welcome)
                        if let entry { LabeledContent("This moment belongs to", value: entry.dayText()) }
                        else { DatePicker("This moment belongs to", selection: $day, in: DayIdentity.date(for: "1900-01-01")!...Date.now, displayedComponents: .date).font(.subheadline).datePickerStyle(.compact) }
                        VStack(spacing: 10) {
                            ForEach(Mood.allCases) { option in
                                SetupChoice(title: option.title, symbol: option.symbol, selected: mood == option) { mood = option }

                            }
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel(title: "How’s your appetite?")
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 8) { ForEach(Appetite.allCases) { option in appetiteButton(option) } }
                                VStack(spacing: 8) { ForEach(Appetite.allCases) { option in appetiteButton(option) } }
                            }
                            Text("Just a record of how you feel, not a target to hit.").font(.caption).foregroundStyle(Theme.secondaryInk)
                        }
                        if !store.journal.routines.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionLabel(title: "Anything you made room for?", subtitle: "Optional. Leave these blank if you like.")
                                ForEach(Routine.allCases.filter { store.journal.routines.contains($0) }) { routine in
                                    SetupChoice(title: store.routineTitle(routine), symbol: routine.symbol, selected: routines.contains(routine)) {
                                        if routines.contains(routine) { routines.remove(routine) } else { routines.insert(routine) }
                                    }

                                }
                            }
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(title: "A thought to keep", subtitle: "Something you noticed, enjoyed or found difficult.")
                            TextField("Today I noticed… (optional)", text: $note, axis: .vertical).lineLimit(3...6).alongField().onChange(of: note) { note = String(note.prefix(500)) }
                            Text("\(note.count)/500 · only on this device").font(.caption2).foregroundStyle(Theme.secondaryInk)
                        }
                        PrimaryButton(title: entry == nil ? "Save this moment" : "Update this moment", symbol: "checkmark") {
                            guard let mood, let appetite else { return }
                            if store.saveCheckIn(day: day, mood: mood, appetite: appetite, routines: routines, note: note, editing: entry?.id) { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { saved = true } }
                        }.disabled(mood == nil || appetite == nil).opacity(mood == nil || appetite == nil ? 0.5 : 1)
                        if mood == nil || appetite == nil { Text("Choose a feeling and appetite to save. Everything else is optional.").font(.caption).foregroundStyle(Theme.secondaryInk) }
                        Text("One check-in per day. Saving again for the same date updates that day’s entry.").font(.caption).foregroundStyle(Theme.secondaryInk)
                    }
                }.padding(24).frame(maxWidth: 620)
            }.frame(maxWidth: .infinity).pageBackground().scrollDismissesKeyboard(.interactively)
                .navigationTitle(saved ? "Moment saved" : "Your check-in").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
                .sensoryFeedback(.success, trigger: saved)
        }.onAppear {
            if let entry { day = entry.displayDay; mood = entry.mood; appetite = entry.appetite; routines = entry.routines; note = entry.note }
            else { routines = store.journal.recordedRoutines(on: day) }
        }
            .onChange(of: day) {
                if entry == nil, let existing = store.journal.checkIn(on: day) {
                    mood = existing.mood; appetite = existing.appetite; routines = existing.routines; note = existing.note
                } else if entry == nil {
                    mood = nil; appetite = nil; routines = store.journal.recordedRoutines(on: day); note = ""
                }
            }
    }
    private func appetiteButton(_ option: Appetite) -> some View {
        Button { appetite = option } label: {
            Text(option.title).font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 48).padding(.horizontal, 10).foregroundStyle(Theme.accent).background(appetite == option ? Theme.softAccent : Theme.card, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(appetite == option ? Theme.accent : Theme.line, lineWidth: appetite == option ? 2 : 1))
        }.buttonStyle(.plain).accessibilityAddTraits(appetite == option ? .isSelected : [])
    }
}
