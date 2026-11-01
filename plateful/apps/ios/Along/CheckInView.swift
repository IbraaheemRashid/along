import SwiftUI

struct CheckInView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var entry: CheckIn?
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
                        MeadowView(accessory: store.journal.accessory).frame(height: 270).clipShape(RoundedRectangle(cornerRadius: 28))
                        Text("A little moment.\nA part of your story.").alongTitle(34)
                        Text(mood == .tough ? "There’s room for the harder days here, too. Thank you for recording how today really felt." : "Your check-in is saved. You don’t have to do anything else to make today count.").foregroundStyle(.secondary).lineSpacing(4)
                        HStack { Pill(text: mood?.shortTitle ?? "", symbol: mood?.symbol); Pill(text: "Saved on this device", symbol: "checkmark") }
                        PrimaryButton(title: "Back to my day") { dismiss() }
                        Button("See my journey") { store.selectedTab = 1; dismiss() }.frame(maxWidth: .infinity, minHeight: 44)
                    } else {
                        HStack { VStack(alignment: .leading, spacing: 8) { Text("How are you, really?").alongTitle(31); Text("No right answers. No perfect days.").font(.subheadline).foregroundStyle(.secondary) }; Spacer(minLength: 0); PipView(wave: true).frame(width: 70, height: 85) }
                        DatePicker("This moment belongs to", selection: $day, in: ...Date.now, displayedComponents: .date).font(.subheadline).datePickerStyle(.compact).disabled(entry != nil)
                        VStack(spacing: 10) {
                            ForEach(Mood.allCases) { option in
                                Button { mood = option } label: {
                                    HStack(spacing: 14) { Image(systemName: option.symbol).font(.title2).frame(width: 29); Text(option.title).font(.headline); Spacer(minLength: 0); Image(systemName: mood == option ? "checkmark.circle.fill" : "circle").font(.title3) }
                                        .padding(18).foregroundStyle(mood == option ? Theme.ink : .primary).background(mood == option ? Theme.lilac : Theme.card, in: RoundedRectangle(cornerRadius: 18))
                                }.buttonStyle(.plain).accessibilityAddTraits(mood == option ? .isSelected : [])
                            }
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel(title: "How’s your appetite?")
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 8) { ForEach(Appetite.allCases) { option in appetiteButton(option) } }
                                VStack(spacing: 8) { ForEach(Appetite.allCases) { option in appetiteButton(option) } }
                            }
                            Text("Just a record of how you feel, not a target to hit.").font(.caption).foregroundStyle(.secondary)
                        }
                        if !store.journal.routines.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionLabel(title: "Anything you made room for?", subtitle: "Optional. Leave these blank if you like.")
                                ForEach(Routine.allCases.filter { store.journal.routines.contains($0) }) { routine in
                                    Button { if routines.contains(routine) { routines.remove(routine) } else { routines.insert(routine) } } label: {
                                        HStack(spacing: 14) { Image(systemName: routine.symbol).frame(width: 24); Text(routine.title).font(.subheadline); Spacer(); Image(systemName: routines.contains(routine) ? "checkmark.circle.fill" : "circle").font(.title3) }.padding(17).background(Theme.card, in: RoundedRectangle(cornerRadius: 17))
                                    }.buttonStyle(.plain).accessibilityAddTraits(routines.contains(routine) ? .isSelected : [])
                                }
                            }
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(title: "A thought to keep", subtitle: "Something you noticed, enjoyed or found difficult.")
                            TextField("Today I noticed… (optional)", text: $note, axis: .vertical).lineLimit(3...6).padding(17).background(Theme.card, in: RoundedRectangle(cornerRadius: 17)).onChange(of: note) { note = String(note.prefix(500)) }
                            Text("\(note.count)/500 · only on this device").font(.caption2).foregroundStyle(.secondary)
                        }
                        PrimaryButton(title: entry == nil ? "Save this moment" : "Update this moment", symbol: "checkmark") {
                            guard let mood, let appetite else { return }
                            if store.saveCheckIn(day: day, mood: mood, appetite: appetite, routines: routines, note: note) { withAnimation { saved = true } }
                        }.disabled(mood == nil || appetite == nil).opacity(mood == nil || appetite == nil ? 0.5 : 1)
                        if mood == nil || appetite == nil { Text("Choose a feeling and appetite to save. Everything else is optional.").font(.caption).foregroundStyle(.secondary) }
                        Text("One check-in per day. Saving again for the same date updates that day’s entry.").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(24).frame(maxWidth: 620)
            }.frame(maxWidth: .infinity).pageBackground().scrollDismissesKeyboard(.interactively)
                .navigationTitle(saved ? "Moment saved" : "Your check-in").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
                .sensoryFeedback(.success, trigger: saved)
        }.onAppear { if let entry { day = entry.day; mood = entry.mood; appetite = entry.appetite; routines = entry.routines; note = entry.note } }
            .onChange(of: day) {
                if entry == nil, let existing = store.journal.checkIns.first(where: { Calendar.current.isDate($0.day, inSameDayAs: day) }) {
                    mood = existing.mood; appetite = existing.appetite; routines = existing.routines; note = existing.note
                }
            }
    }
    private func appetiteButton(_ option: Appetite) -> some View {
        Button { appetite = option } label: {
            Text(option.title).font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 48).padding(.horizontal, 10).foregroundStyle(appetite == option ? Theme.ink : .primary).background(appetite == option ? Theme.sage : Theme.card, in: RoundedRectangle(cornerRadius: 15))
        }.buttonStyle(.plain).accessibilityAddTraits(appetite == option ? .isSelected : [])
    }
}
