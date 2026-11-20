import SwiftUI

/// Log or edit one dose: what was taken, when, where and how it felt.
struct DoseSheet: View {
    enum Mode: Identifiable {
        case slot(DoseSlot)
        case extra(dayKey: String)
        var id: String {
            switch self {
            case .slot(let slot): slot.id
            case .extra(let day): "extra|\(day)"
            }
        }
    }

    var mode: Mode
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var peptideID: UUID?
    @State private var status: DoseLog.Status = .taken
    @State private var takenAt = Date.now
    @State private var amountText = ""
    @State private var unit: DoseUnit = .mg
    @State private var site: InjectionSite?
    @State private var note = ""
    @State private var confirmDelete = false
    @FocusState private var focused: Bool

    private var existing: DoseLog? {
        if case .slot(let slot) = mode, let log = slot.log { return store.journal.protocolLogs.first { $0.id == log.id } ?? log }
        return nil
    }
    private var slot: DoseSlot? { if case .slot(let slot) = mode { return slot }; return nil }
    private var peptide: TrackedPeptide? { peptideID.flatMap(store.peptide) }
    private var lastSite: InjectionSite? {
        guard let peptideID else { return nil }
        return ProtocolSchedule.lastSite(for: peptideID, logs: store.journal.protocolLogs.filter { $0.id != existing?.id })
    }
    private var amount: Double? {
        let trimmed = amountText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        return trimmed.isEmpty ? nil : Double(trimmed)
    }
    private var amountIsValid: Bool {
        amountText.trimmingCharacters(in: .whitespaces).isEmpty || (amount.map { $0.isFinite && $0 > 0 && $0 <= TrackedPeptide.maximumAmount } ?? false)
    }
    private var canSave: Bool { peptide != nil && amountIsValid && note.count <= DoseLog.noteLimit }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if slot == nil { peptidePicker }
                    if slot?.isExtra == false { statusPicker }
                    if status == .taken {
                        amountField
                        timeField
                        sitePicker
                    }
                    noteField
                    if existing != nil {
                        Button(role: .destructive) { confirmDelete = true } label: {
                            Text("Delete this record").font(.system(.body, weight: .medium)).frame(maxWidth: .infinity, minHeight: 44)
                        }.accessibilityIdentifier("dose.delete")
                    }
                }
                .padding(.horizontal, 22).padding(.vertical, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            SetupPrimaryButton(title: existing == nil ? (status == .taken ? "Log dose" : "Mark as skipped") : "Save changes", enabled: canSave, identifier: "dose.save", action: save)
                .padding(.horizontal, 22).padding(.vertical, 12)
        }
        .background(SetupTheme.surface)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .onAppear(perform: prefill)
        .confirmationDialog("Delete this dose record?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { if let existing, store.removeDose(existing.id) { dismiss() } }
        } message: { Text("This removes it from your history. It can’t be undone.") }
    }

    private var header: some View {
        ZStack {
            VStack(spacing: 2) {
                Text(peptide?.name ?? "Log a dose").font(.headline).foregroundStyle(SetupTheme.ink)
                Text(subtitle).font(.caption).foregroundStyle(SetupTheme.muted)
            }
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(SetupTheme.ink)
                        .frame(width: 32, height: 32).background(SetupTheme.tile, in: Circle())
                }
                .frame(width: 44, height: 44)
                .accessibilityLabel("Close").accessibilityIdentifier("dose.close")
            }
        }
        .padding(.horizontal, 14).padding(.top, 18).padding(.bottom, 8)
    }

    private var subtitle: String {
        guard let slot else { return "Extra dose" }
        let day = DayIdentity.formatted(key: slot.dayKey, rawDate: .now, style: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
        if let time = slot.time { return "Scheduled \(day), \(time.text)" }
        return "Extra dose · \(day)"
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(SetupTheme.ink)
    }

    private var peptidePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("Peptide")
            SetupFlowLayout {
                ForEach(store.journal.protocolPeptides) { item in
                    SetupChip(title: item.name, selected: peptideID == item.id, leading: "circle", identifier: "dose.peptide.\(item.name)") {
                        peptideID = item.id
                        amountText = item.amount.map(Self.format) ?? ""
                        unit = item.unit
                        site = nil
                    }
                }
            }
        }
    }

    private var statusPicker: some View {
        HStack(spacing: 0) {
            ForEach([DoseLog.Status.taken, .skipped], id: \.self) { value in
                Button { status = value } label: {
                    Text(value == .taken ? "Taken" : "Skipped").font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(status == value ? SetupTheme.inverseInk : SetupTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(status == value ? SetupTheme.ink : .clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(status == value ? .isSelected : [])
                .accessibilityIdentifier("dose.status.\(value.rawValue)")
            }
        }
        .padding(4).background(SetupTheme.tile, in: Capsule())
        .sensoryFeedback(.selection, trigger: status)
        .animation(.easeOut(duration: 0.15), value: status)
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("Amount")
            HStack(spacing: 10) {
                TextField("Amount", text: $amountText)
                    .keyboardType(.decimalPad).focused($focused)
                    .font(.system(size: 22, weight: .semibold))
                    .padding(.horizontal, 16).frame(minHeight: 56)
                    .background(SetupTheme.tile, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(amountIsValid ? .clear : Color.red.opacity(0.6)))
                    .accessibilityIdentifier("dose.amount")
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
                .accessibilityIdentifier("dose.unit")
            }
            Text(peptide?.amount == nil ? "Enter the amount you took. Along never suggests a dose." : "Prefilled from your protocol. Change it if this dose was different.")
                .font(.caption).foregroundStyle(SetupTheme.muted)
        }
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = false } } }
    }

    private var timeField: some View {
        HStack {
            label("Time taken")
            Spacer()
            DatePicker("Time taken", selection: $takenAt, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden().accessibilityIdentifier("dose.time")
        }
    }

    private var sitePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                label("Injection site")
                Spacer()
                if let lastSite { Text("Last: \(lastSite.shortTitle)").font(.caption.weight(.medium)).foregroundStyle(SetupTheme.muted) }
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(InjectionSite.allCases) { item in
                    Button { site = site == item ? nil : item } label: {
                        HStack(spacing: 6) {
                            Text(item.title).font(.system(.subheadline, weight: .medium)).lineLimit(1).minimumScaleFactor(0.85)
                            Spacer(minLength: 0)
                            if item == lastSite { Image(systemName: "clock.arrow.circlepath").font(.caption).foregroundStyle(site == item ? SetupTheme.inverseInk.opacity(0.7) : SetupTheme.muted) }
                        }
                        .foregroundStyle(site == item ? SetupTheme.inverseInk : SetupTheme.ink)
                        .padding(.horizontal, 14).frame(maxWidth: .infinity, minHeight: 44)
                        .background(site == item ? SetupTheme.ink : SetupTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(site == item ? SetupTheme.ink : SetupTheme.border))
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(SetupPressStyle())
                    .accessibilityLabel(item.title + (item == lastSite ? ", used last time" : ""))
                    .accessibilityAddTraits(site == item ? .isSelected : [])
                    .accessibilityIdentifier("dose.site.\(item.rawValue)")
                }
            }
            .sensoryFeedback(.selection, trigger: site)
            Text("Optional. Along shows your last site so rotating is easy to keep track of.").font(.caption).foregroundStyle(SetupTheme.muted)
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("Note")
            TextField("How are you feeling? Anything worth remembering?", text: $note, axis: .vertical)
                .lineLimit(3...6).focused($focused)
                .padding(14)
                .background(SetupTheme.tile, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityIdentifier("dose.note")
            if note.count > DoseLog.noteLimit - 50 {
                Text("\(note.count)/\(DoseLog.noteLimit)").font(.caption).foregroundStyle(note.count > DoseLog.noteLimit ? .red : SetupTheme.muted)
            }
        }
    }

    private static func format(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...3)).grouping(.never)) }

    private func prefill() {
        switch mode {
        case .slot(let slot):
            peptideID = slot.peptide.id
            if let log = existing {
                status = log.status; takenAt = log.takenAt; site = log.site; note = log.note
                amountText = log.amount.map(Self.format) ?? ""; unit = log.unit
            } else {
                amountText = slot.peptide.amount.map(Self.format) ?? ""; unit = slot.peptide.unit
                let scheduled = slot.time?.date(on: slot.dayKey) ?? .now
                takenAt = slot.dayKey == store.todayKey ? .now : min(scheduled, .now)
            }
        case .extra(let day):
            let first = store.journal.activePeptides.first ?? store.journal.protocolPeptides.first
            peptideID = first?.id
            amountText = first?.amount.map(Self.format) ?? ""; unit = first?.unit ?? .mg
            takenAt = day == store.todayKey ? .now : min(DayIdentity.date(for: day) ?? .now, .now)
        }
    }

    private func save() {
        guard let peptideID else { return }
        let dayKey: String
        if let slot, !slot.isExtra { dayKey = slot.dayKey } else { dayKey = DayIdentity.key(for: takenAt) ?? store.todayKey }
        var log = existing ?? DoseLog(peptideID: peptideID, dayKey: dayKey, scheduledTime: slot?.time, takenAt: takenAt)
        log.peptideID = peptideID
        log.dayKey = dayKey
        log.status = status
        log.takenAt = min(takenAt, .now)
        log.amount = status == .taken ? amount : nil
        log.unit = unit
        log.site = status == .taken ? site : nil
        log.note = note
        if store.saveDose(log) {
            store.showToast(status == .taken ? "\(peptide?.name ?? "Dose") logged" : "Marked as skipped")
            dismiss()
        }
    }
}
