import SwiftUI

struct AddMilestoneView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var entry: Milestone?
    @State private var title = ""
    @State private var note = ""
    @State private var kind: MilestoneKind = .everyday
    @State private var date = Date()
    private enum Field { case title, note }
    @FocusState private var focusedField: Field?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    CompanionHeading(title: "That mattered. Let’s keep it.", detail: "Big or small, this moment belongs to you.", accessory: store.journal.accessory, pose: .celebrate)
                    VStack(alignment: .leading, spacing: 9) { Text("Your moment").font(.headline); TextField("e.g. Enjoyed a walk with a friend", text: $title, axis: .vertical).lineLimit(1...3).alongField().focused($focusedField, equals: .title).accessibilityIdentifier("milestone.title").onChange(of: title) { title = String(title.prefix(80)) } }
                    VStack(alignment: .leading, spacing: 9) { Text("A little more about it").font(.headline); TextField("What made it meaningful? (optional)", text: $note, axis: .vertical).lineLimit(3...5).alongField().focused($focusedField, equals: .note).onChange(of: note) { note = String(note.prefix(300)) } }
                    Picker("Kind of moment", selection: $kind) { ForEach(MilestoneKind.allCases) { Text($0.title).tag($0) } }.pickerStyle(.menu).frame(minHeight: 44)
                    DatePicker("When was it?", selection: $date, in: ...Date.now, displayedComponents: .date)
                    PrimaryButton(title: entry == nil ? "Keep this moment" : "Update this moment", symbol: "sparkles") { if store.addMilestone(title: title, note: note, kind: kind, date: date, editing: entry?.id) { dismiss() } }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).opacity(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                }.padding(24).frame(maxWidth: 620)
            }.frame(maxWidth: .infinity).pageBackground().scrollDismissesKeyboard(.interactively).navigationTitle("A personal milestone").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() } }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focusedField = nil }.accessibilityIdentifier("milestone.keyboardDone") }
                }
        }.onAppear { if let entry { title = entry.title; note = entry.note; kind = entry.kind; date = entry.date } }
    }
}

struct AddWeightView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var entry: WeightEntry?
    @State private var value = ""
    @State private var valueWasEdited = false
    @State private var unit: WeightUnit = .kg
    @State private var date = Date()
    private var parsed: Double? { Double(value.replacingOccurrences(of: ",", with: ".")) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    CompanionHeading(title: "One part of your story.", detail: "Weight is optional. This is a personal record, with no goal, prediction or judgement attached.", accessory: store.journal.accessory)
                    VStack(alignment: .leading, spacing: 14) {
                        SectionLabel(title: "Your record")
                        TextField("Weight", text: Binding(get: { value }, set: { value = $0; valueWasEdited = true })).font(.system(.largeTitle, design: .rounded)).keyboardType(.decimalPad).accessibilityLabel("Weight value").alongField()
                        Picker("Unit", selection: Binding(get: { unit }, set: { newUnit in
                            if let parsed { value = String(format: "%.1f", newUnit.display(unit.kilograms(parsed))) }
                            unit = newUnit
                        })) { ForEach(WeightUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                        DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date).frame(minHeight: 44).disabled(entry != nil)
                    }.card()
                    SetupNote(text: "One weight record per day. A new value for the same date replaces it.", symbol: "book.closed")
                    PrimaryButton(title: "Save weight record", symbol: "checkmark") {
                        if let entry, !valueWasEdited {
                            if store.addWeight(value: entry.kilograms, unit: .kg, date: date) { dismiss() }
                        } else if let parsed, store.addWeight(value: parsed, unit: unit, date: date) { dismiss() }
                    }.disabled(parsed == nil || !JournalValidation.weight(unit.kilograms(parsed ?? 0)))
                        .opacity(parsed == nil || !JournalValidation.weight(unit.kilograms(parsed ?? 0)) ? 0.5 : 1)
                }.padding(22).frame(maxWidth: 620)
            }.frame(maxWidth: .infinity).pageBackground().scrollDismissesKeyboard(.interactively).navigationTitle("Optional weight record").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() } } }
        }.onAppear {
            unit = store.journal.weightUnit
            if let entry { date = entry.date; value = String(format: "%.1f", unit.display(entry.kilograms)) }
        }
    }
}

struct RoutineRecordView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let entry: RoutineDay
    @State private var routines: Set<Routine> = []
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Little things you made room for.").alongTitle(28)
                    Text(entry.day.formatted(date: .complete, time: .omitted)).foregroundStyle(Theme.secondaryInk)
                    ForEach(Routine.allCases) { routine in
                        SetupChoice(title: store.routineTitle(routine), symbol: routine.symbol, selected: routines.contains(routine)) {
                            if routines.contains(routine) { routines.remove(routine) } else { routines.insert(routine) }
                        }
                    }
                    PrimaryButton(title: "Update routines", symbol: "checkmark") {
                        if store.saveRoutineDay(entry.id, routines: routines) { dismiss() }
                    }
                    Text("Updating this record never removes a keepsake you’ve earned.").font(.caption).foregroundStyle(Theme.secondaryInk)
                }.padding(22).frame(maxWidth: 620)
            }.frame(maxWidth: .infinity).pageBackground().navigationTitle("Your routines").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() } } }
        }.onAppear { routines = entry.routines }
    }
}
