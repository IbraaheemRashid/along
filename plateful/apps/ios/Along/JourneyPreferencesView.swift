import SwiftUI

/// Edits a local draft and merges only these preferences into the current
/// journal after Save. Cancelling never changes the journal or setup archive.
struct JourneyPreferencesView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var routineNames: [String: String] = [:]
    @State private var encouragement = "Gentle"
    @State private var intention = ""
    @State private var startDate = Date.now
    @State private var originalStartDate = Date.now
    @State private var loaded = false
    @State private var saveError: String?
    @FocusState private var focusedField: String?

    private let encouragementOptions = ["Gentle", "Straightforward", "Celebratory"]
    private var earliestStartDate: Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: 1900, month: 1, day: 1))!
    }
    private var validationMessage: String? {
        if !routineNames.values.allSatisfy({ JournalValidation.text($0, limit: 80) }) {
            return "Use up to 80 characters for each routine name."
        }
        if !JournalValidation.text(intention, limit: 300) {
            return "Use up to 300 characters for your intention."
        }
        if !encouragementOptions.contains(encouragement) {
            return "Choose the encouragement that feels right for you."
        }
        if !JournalValidation.recordDate(startDate) {
            return "Choose a journey start date between 1900 and today."
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    CompanionHeading(title: "Make this space yours.", detail: "The words and little choices that fit you.", accessory: store.journal.accessory)
                    AlongSection(title: "Your routines, in your words") {
                        Text("Leave a name blank to use Along’s wording. Choose which routines appear in your day from You.")
                            .font(.subheadline).foregroundStyle(Theme.secondaryInk)
                        ForEach(Routine.allCases) { routine in
                            VStack(alignment: .leading, spacing: 8) {
                                Label(routine.shortTitle, systemImage: routine.symbol)
                                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                                TextField(routine.title, text: routineBinding(routine), axis: .vertical)
                                    .focused($focusedField, equals: routine.rawValue)
                                    .lineLimit(1...3).alongField()
                                    .accessibilityLabel("\(routine.shortTitle) routine wording")
                                    .accessibilityIdentifier("preferences.routine.\(routine.rawValue)")
                                Text("\(routineNames[routine.rawValue, default: ""].count)/80")
                                    .font(.caption2).foregroundStyle(Theme.secondaryInk)
                            }
                        }
                    }
                    AlongSection(title: "A little encouragement") {
                        ForEach(encouragementOptions, id: \.self) { option in
                            SetupChoice(title: option, detail: encouragementDetail(option), symbol: "bubble.left",
                                        selected: encouragement == option,
                                        identifier: "preferences.encouragement.\(option.lowercased())") {
                                encouragement = option
                                saveError = nil
                            }
                        }
                    }
                    AlongSection(title: "Something to come back to") {
                        Text("An intention, in your own words. It can change as you do.")
                            .font(.subheadline).foregroundStyle(Theme.secondaryInk)
                        TextField("My intention (optional)", text: $intention, axis: .vertical)
                            .focused($focusedField, equals: "intention")
                            .lineLimit(3...6).alongField()
                            .accessibilityLabel("Your intention, optional")
                            .accessibilityIdentifier("preferences.intention")
                            .onChange(of: intention) { _, value in intention = String(value.prefix(300)); saveError = nil }
                        Text("\(intention.count)/300").font(.caption2).foregroundStyle(Theme.secondaryInk)
                    }
                    AlongSection(title: "Where your journey began") {
                        DatePicker("Journey start date", selection: $startDate, in: earliestStartDate...Date.now, displayedComponents: .date)
                            .datePickerStyle(.compact).frame(minHeight: 44)
                            .accessibilityIdentifier("preferences.startDate")
                            .onChange(of: startDate) { _, _ in saveError = nil }
                        Text("An approximate date is fine. This sets the days together shown on Today; changing it doesn’t add a record or move your existing moments.")
                            .font(.caption).foregroundStyle(Theme.secondaryInk)
                    }
                    if let message = saveError ?? validationMessage {
                        Text(message).font(.subheadline).foregroundStyle(Theme.secondaryInk)
                            .accessibilityIdentifier("preferences.error")
                    }
                    PrimaryButton(title: "Save preferences", symbol: "checkmark", action: save)
                        .disabled(!loaded || validationMessage != nil)
                        .opacity(loaded && validationMessage == nil ? 1 : 0.5)
                        .accessibilityIdentifier("preferences.save")
                }.padding(22).frame(maxWidth: 650)
            }.frame(maxWidth: .infinity).pageBackground().scrollDismissesKeyboard(.interactively)
                .navigationTitle("Your preferences").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focusedField = nil }.accessibilityIdentifier("preferences.keyboardDone") }
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }.accessibilityIdentifier("preferences.cancel")
                    }
                }
        }.onAppear {
            guard !loaded else { return }
            let preferences = store.journal.onboardingPreferences
            routineNames = preferences?.routineNames ?? [:]
            encouragement = preferences?.encouragement ?? "Gentle"
            intention = preferences?.intention ?? ""
            startDate = store.journal.startDate
            originalStartDate = store.journal.startDate
            loaded = true
        }
    }

    private func routineBinding(_ routine: Routine) -> Binding<String> {
        Binding(get: { routineNames[routine.rawValue] ?? "" }, set: {
            routineNames[routine.rawValue] = String($0.prefix(80))
            saveError = nil
        })
    }

    private func encouragementDetail(_ option: String) -> String {
        switch option {
        case "Straightforward": "Clear words and a little perspective."
        case "Celebratory": "A little more joy for the moments you keep."
        default: "A quiet, kind voice alongside your day."
        }
    }

    private func save() {
        guard loaded, validationMessage == nil else { return }
        let saved = store.updateJournal { journal in
            var preferences = journal.onboardingPreferences ?? OnboardingDraft()
            if journal.onboardingPreferences == nil { preferences.startDate = journal.startDate }
            for routine in Routine.allCases {
                let wording = routineNames[routine.rawValue] ?? ""
                if wording.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    preferences.routineNames.removeValue(forKey: routine.rawValue)
                } else { preferences.routineNames[routine.rawValue] = wording }
            }
            preferences.encouragement = encouragement
            preferences.intention = intention
            if startDate != originalStartDate {
                journal.startDate = startDate
                preferences.startDate = startDate
                preferences.hasStartDate = true
            }
            journal.onboardingPreferences = preferences
        }
        if saved { dismiss() }
        else { saveError = store.error ?? "Your preferences couldn’t be saved. Please try again." }
    }
}
