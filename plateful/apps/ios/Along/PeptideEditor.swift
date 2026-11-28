import SwiftUI

/// Add or edit one peptide in the protocol. Amounts and schedules come from the
/// person; Along never proposes a dose.
struct PeptideEditor: View {
    enum Mode: Identifiable {
        case add
        case edit(TrackedPeptide)
        var id: String {
            switch self {
            case .add: "add"
            case .edit(let peptide): peptide.id.uuidString
            }
        }
    }

    var mode: Mode
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var search = ""
    @State private var amountText = ""
    @State private var unit: DoseUnit = .mg
    @State private var kind: DoseSchedule.Kind = .unscheduled
    @State private var weekdays: Set<Int> = []
    @State private var intervalDays = 2
    @State private var times: [DoseTime] = [DoseTime(hour: 8, minute: 0)]
    @State private var startDate = Date.now
    @State private var tracksBatchExpiry = false
    @State private var batchExpiryDate = Date.now
    @State private var note = ""
    @State private var isPaused = false
    /// Nil until the person taps a swatch, so the peptide keeps following its
    /// category default (and a renamed new peptide follows its new name).
    @State private var pickedColor: PeptideColor?
    @State private var confirmRemove = false
    @FocusState private var focused: Field?

    private enum Field { case name, search, amount, note }

    private var editing: TrackedPeptide? { if case .edit(let peptide) = mode { return peptide }; return nil }
    private var amount: Double? {
        let trimmed = amountText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        return trimmed.isEmpty ? nil : Double(trimmed)
    }
    private var amountIsValid: Bool {
        amountText.trimmingCharacters(in: .whitespaces).isEmpty
            || (amount.map { $0.isFinite && $0 > 0 && $0 <= TrackedPeptide.maximumAmount } ?? false)
    }
    private var schedule: DoseSchedule {
        kind == .unscheduled ? .unscheduled : DoseSchedule(kind: kind, weekdays: kind == .weekdays ? weekdays : [], intervalDays: intervalDays, times: times)
    }
    private var startKey: String { DayIdentity.key(for: startDate) ?? store.todayKey }
    private var canSave: Bool {
        SetupDraft.validCompound(name.trimmingCharacters(in: .whitespacesAndNewlines))
            && amountIsValid && schedule.isValid && note.count <= TrackedPeptide.noteLimit
    }
    private var matches: [Peptide] { Peptide.matches(search) }
    private var displayColor: PeptideColor { pickedColor ?? .default(for: Peptide.category(for: name)) }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if editing == nil { namePicker } else { nameField }
                    amountField
                    scheduleKind
                    if kind == .weekdays { weekdayPicker }
                    if kind == .interval { intervalPicker }
                    if kind != .unscheduled {
                        timesPicker
                        startPicker
                    }
                    if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { colorPicker }
                    batchExpiryField
                    noteField
                    if Peptide.library.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                        DisclosureGroup("Peptide reference") { PeptideReferenceChart(name: name) }
                    }
                    if editing != nil {
                        pauseToggle
                        Button(role: .destructive) { confirmRemove = true } label: {
                            Text("Remove from protocol").font(.system(.body, weight: .medium)).frame(maxWidth: .infinity, minHeight: 44)
                        }.accessibilityIdentifier("peptide.remove")
                    }
                }
                .padding(.horizontal, 22).padding(.vertical, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            SetupPrimaryButton(title: editing == nil ? "Add to protocol" : "Save changes", enabled: canSave, identifier: "peptide.save", action: save)
                .padding(.horizontal, 22).padding(.vertical, 12)
        }
        .background(SetupTheme.surface)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .onAppear(perform: prefill)
        .confirmationDialog("Remove \(name.isEmpty ? "this peptide" : name) from your protocol?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                if let editing, store.removePeptide(editing.id) {
                    store.showToast("Removed from protocol")
                    dismiss()
                }
            }
        } message: { Text("Its dose history is removed too. Export a backup first if you want to keep it.") }
    }

    private var header: some View {
        ZStack {
            Text(editing == nil ? "Add a peptide" : "Edit peptide").font(.headline).foregroundStyle(SetupTheme.ink)
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(SetupTheme.ink)
                        .frame(width: 32, height: 32).background(SetupTheme.tile, in: Circle())
                }
                .frame(width: 44, height: 44)
                .accessibilityLabel("Close").accessibilityIdentifier("peptide.close")
            }
        }
        .padding(.horizontal, 14).padding(.top, 18).padding(.bottom, 8)
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(SetupTheme.ink)
    }

    private var namePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("Peptide")
            if name.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(SetupTheme.muted)
                    TextField("Search or type a name", text: $search).focused($focused, equals: .search)
                        .textInputAutocapitalization(.words).submitLabel(.done)
                        .onSubmit(addCustomName)
                        .accessibilityIdentifier("peptide.search")
                    if !search.isEmpty {
                        Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(SetupTheme.muted) }
                            .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 16).frame(minHeight: 50)
                .background(SetupTheme.tile, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                SetupFlowLayout {
                    ForEach(matches) { peptide in
                        SetupChip(title: peptide.name, detail: peptide.category, selected: false,
                                  identifier: "peptide.pick.\(peptide.name)") {
                            name = peptide.name; search = ""; focused = nil
                        }
                    }
                    let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !query.isEmpty && !Peptide.library.contains(where: { $0.name.caseInsensitiveCompare(query) == .orderedSame })
                        && SetupDraft.validCompound(query) {
                        SetupChip(title: "Add “\(query)”", selected: false, identifier: "peptide.pick.custom") { addCustomName() }
                    }
                }
            } else {
                HStack {
                    PeptideBadge(name: name, color: displayColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name).font(.system(.body, weight: .semibold)).foregroundStyle(SetupTheme.ink)
                        Text(Peptide.category(for: name)).font(.caption).foregroundStyle(SetupTheme.muted)
                    }
                    Spacer()
                    Button("Change") { name = ""; search = "" }.font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("peptide.change-name")
                }
                .padding(12)
                .background(SetupTheme.tile, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("Name")
            HStack(spacing: 12) {
                PeptideBadge(name: name, color: displayColor)
                TextField("Peptide name", text: $name).focused($focused, equals: .name)
                    .accessibilityIdentifier("peptide.name")
            }
            .padding(.leading, 6).padding(.trailing, 16).frame(minHeight: 56)
            .background(SetupTheme.tile, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("Colour")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 6) {
                ForEach(PeptideColor.allCases) { swatch in
                    let selected = swatch == displayColor
                    Button { pickedColor = swatch } label: {
                        Circle().fill(swatch.color).frame(width: 36, height: 36)
                            .overlay {
                                if selected {
                                    Image(systemName: "checkmark").font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white).shadow(color: .black.opacity(0.35), radius: 1)
                                }
                            }
                            .padding(4)
                            .overlay(Circle().strokeBorder(selected ? SetupTheme.ink : .clear, lineWidth: 2.5))
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(SetupPressStyle())
                    .accessibilityLabel(swatch.title)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier("peptide.color.\(swatch.rawValue)")
                }
            }
            .sensoryFeedback(.selection, trigger: displayColor)
            Text("For recognising it at a glance on Today and in your calendar.")
                .font(.caption).foregroundStyle(SetupTheme.muted)
        }
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("Usual amount")
            HStack(spacing: 10) {
                TextField("Optional", text: $amountText).keyboardType(.decimalPad).focused($focused, equals: .amount)
                    .font(.system(size: 22, weight: .semibold))
                    .padding(.horizontal, 16).frame(minHeight: 56)
                    .background(SetupTheme.tile, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(amountIsValid ? .clear : Color.red.opacity(0.6)))
                    .accessibilityIdentifier("peptide.amount")
                Menu {
                    Picker("Unit", selection: $unit) { ForEach(DoseUnit.allCases) { Text($0.title).tag($0) } }
                } label: {
                    HStack(spacing: 4) {
                        Text(unit.title).font(.system(.body, weight: .semibold))
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(SetupTheme.ink).padding(.horizontal, 16).frame(minHeight: 56)
                    .background(SetupTheme.tile, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .accessibilityIdentifier("peptide.unit")
            }
            Text("Optional. Enter the amount you use. Along never suggests a dose.")
                .font(.caption).foregroundStyle(SetupTheme.muted)
        }
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = nil } } }
    }

    private var scheduleKind: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("Schedule")
            HStack(spacing: 0) {
                ForEach(DoseSchedule.Kind.allCases) { value in
                    Button { kind = value } label: {
                        Text(value == .unscheduled ? "Set later" : value.title).font(.system(.caption, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                            .foregroundStyle(kind == value ? SetupTheme.inverseInk : SetupTheme.ink)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(kind == value ? SetupTheme.ink : .clear, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(kind == value ? .isSelected : [])
                    .accessibilityIdentifier("peptide.schedule.\(value.rawValue)")
                }
            }
            .padding(4).background(SetupTheme.tile, in: Capsule())
            .sensoryFeedback(.selection, trigger: kind)
            .animation(.easeOut(duration: 0.15), value: kind)
        }
    }

    private var weekdayPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("Days")
            WeekdayPicker(selection: $weekdays, identifier: "peptide.weekday")
        }
    }

    private var intervalPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("Every")
            HStack {
                Stepper(value: $intervalDays, in: DoseSchedule.intervalRange) {
                    Text("\(intervalDays) days").font(.system(.body, weight: .semibold)).foregroundStyle(SetupTheme.ink)
                }
                .accessibilityIdentifier("peptide.interval")
            }
            .padding(.horizontal, 16).frame(minHeight: 56)
            .background(SetupTheme.tile, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var timesPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                label("Dose times")
                Spacer()
                if times.count < DoseSchedule.maximumTimes {
                    Button {
                        let next = nextSuggestedTime()
                        times.append(next); times = Array(Set(times)).sorted()
                    } label: {
                        Label("Add time", systemImage: "plus").font(.subheadline.weight(.semibold))
                    }
                    .accessibilityIdentifier("peptide.add-time")
                }
            }
            ForEach(Array(times.enumerated()), id: \.element.id) { index, time in
                HStack {
                    DatePicker("Time \(index + 1)", selection: binding(for: index), displayedComponents: .hourAndMinute)
                        .labelsHidden().accessibilityIdentifier("peptide.time.\(index)")
                    Spacer()
                    if times.count > 1 {
                        Button(role: .destructive) { times.remove(at: index) } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(SetupTheme.muted)
                        }
                        .accessibilityLabel("Remove time").accessibilityIdentifier("peptide.remove-time.\(index)")
                    }
                }
                .padding(.horizontal, 16).frame(minHeight: 52)
                .background(SetupTheme.tile, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var startPicker: some View {
        HStack {
            label("Started")
            Spacer()
            DatePicker("Started", selection: $startDate, in: ...Date.now, displayedComponents: .date)
                .labelsHidden().accessibilityIdentifier("peptide.start")
        }
    }

    private var batchExpiryField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $tracksBatchExpiry) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Track batch expiry").font(.system(.body, weight: .semibold)).foregroundStyle(SetupTheme.ink)
                    Text("Optional. Along can remind you before the date you set — never what to dose.")
                        .font(.caption).foregroundStyle(SetupTheme.muted)
                }
            }
            .tint(SetupTheme.ink)
            .accessibilityIdentifier("peptide.batch.toggle")
            if tracksBatchExpiry {
                HStack {
                    label("Expires")
                    Spacer()
                    DatePicker("Expires", selection: $batchExpiryDate, displayedComponents: .date)
                        .labelsHidden().accessibilityIdentifier("peptide.batch.expiry")
                }
            }
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("Note")
            TextField("Anything to remember about this peptide", text: $note, axis: .vertical)
                .lineLimit(2...4).focused($focused, equals: .note)
                .padding(14)
                .background(SetupTheme.tile, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityIdentifier("peptide.note")
        }
    }

    private var pauseToggle: some View {
        Toggle(isOn: $isPaused) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pause reminders and schedule").font(.system(.body, weight: .semibold)).foregroundStyle(SetupTheme.ink)
                Text("Keeps the history. Nothing is due while paused.").font(.caption).foregroundStyle(SetupTheme.muted)
            }
        }
        .tint(SetupTheme.ink)
        .accessibilityIdentifier("peptide.pause")
    }

    private func binding(for index: Int) -> Binding<Date> {
        Binding(
            get: {
                let time = times[index]
                return Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: .now) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                var copy = times
                copy[index] = DoseTime(hour: parts.hour ?? 8, minute: parts.minute ?? 0)
                times = Array(Set(copy)).sorted()
            }
        )
    }

    private func nextSuggestedTime() -> DoseTime {
        let last = times.sorted().last ?? DoseTime(hour: 8, minute: 0)
        let minutes = min(23 * 60 + 30, last.minutes + 12 * 60)
        return DoseTime(hour: minutes / 60, minute: minutes % 60)
    }

    private func addCustomName() {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard SetupDraft.validCompound(query) else { return }
        name = Peptide.library.first { $0.name.caseInsensitiveCompare(query) == .orderedSame }?.name ?? query
        search = ""; focused = nil
    }

    private func prefill() {
        guard let peptide = editing else {
            startDate = DayIdentity.date(for: store.todayKey) ?? .now
            return
        }
        name = peptide.name
        amountText = peptide.amount.map { $0.formatted(.number.precision(.fractionLength(0...3)).grouping(.never)) } ?? ""
        unit = peptide.unit
        kind = peptide.schedule.kind
        weekdays = peptide.schedule.weekdays
        intervalDays = peptide.schedule.intervalDays
        times = peptide.schedule.sortedTimes.isEmpty ? [DoseTime(hour: 8, minute: 0)] : peptide.schedule.sortedTimes
        startDate = DayIdentity.date(for: peptide.startKey) ?? .now
        if let key = peptide.batchExpiryKey, let date = DayIdentity.date(for: key) {
            tracksBatchExpiry = true
            batchExpiryDate = date
        } else {
            tracksBatchExpiry = false
            batchExpiryDate = Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now
        }
        note = peptide.note
        isPaused = peptide.isPaused
        pickedColor = peptide.color
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var peptide = editing ?? TrackedPeptide(name: trimmed, schedule: schedule, startKey: startKey)
        peptide.name = trimmed
        peptide.amount = amount
        peptide.unit = unit
        peptide.schedule = schedule
        peptide.startKey = startKey
        peptide.batchExpiryKey = tracksBatchExpiry ? DayIdentity.key(for: batchExpiryDate) : nil
        peptide.note = note
        peptide.isPaused = isPaused
        peptide.color = pickedColor
        if store.savePeptide(peptide) {
            store.showToast(editing == nil ? "\(trimmed) added" : "Saved")
            dismiss()
        }
    }
}
