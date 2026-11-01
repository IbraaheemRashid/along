import SwiftUI

struct AddMilestoneView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
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
                    Image(systemName: "sparkles").font(.system(size: 34)).foregroundStyle(Theme.ink).frame(width: 78, height: 78).background(Theme.gold.opacity(0.7), in: RoundedRectangle(cornerRadius: 23))
                    Text("That mattered.\nLet’s keep it.").alongTitle(34)
                    Text("Big or small, this moment belongs to you.").foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 9) { Text("Your moment").font(.headline); TextField("e.g. Enjoyed a walk with a friend", text: $title, axis: .vertical).lineLimit(1...3).padding(17).background(Theme.card, in: RoundedRectangle(cornerRadius: 17)).focused($focusedField, equals: .title).accessibilityIdentifier("milestone.title").onChange(of: title) { title = String(title.prefix(80)) } }
                    VStack(alignment: .leading, spacing: 9) { Text("A little more about it").font(.headline); TextField("What made it meaningful? (optional)", text: $note, axis: .vertical).lineLimit(3...5).padding(17).background(Theme.card, in: RoundedRectangle(cornerRadius: 17)).focused($focusedField, equals: .note).onChange(of: note) { note = String(note.prefix(300)) } }
                    Picker("Kind of moment", selection: $kind) { ForEach(MilestoneKind.allCases) { Text($0.title).tag($0) } }.pickerStyle(.menu).frame(minHeight: 44)
                    DatePicker("When was it?", selection: $date, in: ...Date.now, displayedComponents: .date)
                    PrimaryButton(title: "Keep this moment", symbol: "sparkles") { if store.addMilestone(title: title, note: note, kind: kind, date: date) { dismiss() } }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).opacity(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                }.padding(24).frame(maxWidth: 620)
            }.frame(maxWidth: .infinity).pageBackground().scrollDismissesKeyboard(.interactively).navigationTitle("A personal milestone").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() } }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focusedField = nil }.accessibilityIdentifier("milestone.keyboardDone") }
                }
        }
    }
}

struct AddWeightView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var value = ""
    @State private var unit: WeightUnit = .kg
    @State private var date = Date()
    private var parsed: Double? { Double(value.replacingOccurrences(of: ",", with: ".")) }
    var body: some View {
        NavigationStack {
            Form {
                Section { Text("Weight is optional. This is a personal record, with no goal, prediction or judgement attached.").foregroundStyle(.secondary) }
                Section {
                    TextField("Weight", text: $value).keyboardType(.decimalPad).accessibilityLabel("Weight value")
                    Picker("Unit", selection: $unit) { ForEach(WeightUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.onChange(of: unit) { oldValue, newValue in if let parsed { value = newValue.display(oldValue.kilograms(parsed)).formatted(.number.precision(.fractionLength(1))).replacingOccurrences(of: ",", with: ".") } }
                    DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date)
                } header: { Text("Your record") } footer: { Text("One weight record per day. A new value for the same date replaces it.") }
                Section {
                    Button("Save weight record") {
                        if let parsed, store.addWeight(value: parsed, unit: unit, date: date) { store.journal.showWeight = true; store.persist(); dismiss() }
                    }.disabled(parsed == nil || !JournalValidation.weight(unit.kilograms(parsed ?? 0)))
                }
            }.scrollContentBackground(.hidden).pageBackground().navigationTitle("Optional weight record").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() } } }
        }.onAppear { unit = store.journal.weightUnit }
    }
}
