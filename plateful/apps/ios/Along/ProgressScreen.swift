import Charts
import SwiftUI

/// Adherence, dose calendar, notes and optional weight trend.
struct ProgressScreen: View {
    @Environment(JournalStore.self) private var store
    @State private var monthOffset = 0
    @State private var selectedPeptide: UUID?
    @State private var showWeight = false

    @State private var selectedDay: HistoryDay?
    @State private var historyLimit = 20

    private struct HistoryDay: Identifiable { let id: String }

    private var today: String { store.todayKey }
    private var peptides: [TrackedPeptide] { store.journal.protocolPeptides }
    private var logs: [DoseLog] { store.journal.protocolLogs }
    private var week: Adherence {
        let start = ProtocolSchedule.key(today, adding: -6) ?? today
        return ProtocolSchedule.adherence(from: start, to: today, peptides: peptides, logs: logs, now: store.referenceDate)
    }
    private var month: Adherence {
        let start = ProtocolSchedule.key(today, adding: -29) ?? today
        return ProtocolSchedule.adherence(from: start, to: today, peptides: peptides, logs: logs, now: store.referenceDate)
    }
    private var historyLogs: [DoseLog] {
        logs.filter { selectedPeptide == nil || $0.peptideID == selectedPeptide }
            .sorted { $0.takenAt > $1.takenAt }
    }
    private var showsWeight: Bool { store.journal.showWeight || store.journal.setupProfile?.tracksWeightGoal == true }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if peptides.isEmpty {
                    empty
                } else {
                    calendar
                    history
                    adherenceCards
                    siteMapSection
                    batchSection
                    if showsWeight { weightSection }
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .accessibilityHidden(selectedDay != nil || showWeight)
        .sheet(isPresented: $showWeight) { WeightLogSheet() }
        .sheet(item: $selectedDay) { selection in
            let entries = historyLogs.filter { $0.dayKey == selection.id }
            NavigationStack {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if entries.isEmpty {
                            Text("No doses recorded for this day.").foregroundStyle(SetupTheme.muted)
                        }
                        ForEach(entries) { log in DoseHistoryRow(log: log, peptide: store.peptide(log.peptideID), inCalendar: true) }
                    }.padding(20)
                }
                .navigationTitle(DayIdentity.formatted(key: selection.id, rawDate: .now, style: .dateTime.weekday(.abbreviated).day().month(.abbreviated).year()))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { selectedDay = nil } } }
            }
            .presentationDetents([.medium, .large])
        }
        .onChange(of: selectedPeptide) { _, _ in historyLimit = 20 }
    }

    private var header: some View {
        Text("Progress").font(.system(size: 30, weight: .bold)).tracking(-0.6).foregroundStyle(SetupTheme.ink)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }

    private var empty: some View {
        AppCard(padding: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Nothing to chart yet").font(.headline).foregroundStyle(SetupTheme.ink)
                Text("Your calendar and dose history appear here after you add a peptide.")
                    .font(.subheadline).foregroundStyle(SetupTheme.muted)
            }
        }
    }

    private var adherenceCards: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                AdherenceCard(title: "7 days", adherence: week)
                AdherenceCard(title: "30 days", adherence: month)
            }
            Text("Doses count towards these percentages once their scheduled time arrives.")
                .font(.caption).foregroundStyle(SetupTheme.muted)
        }
        .accessibilityIdentifier("progress.adherence")
    }

    private var calendar: some View {
        let monthStart = monthAnchor
        let calendar = Calendar.current
        let days = DayIdentity.monthGrid(containing: monthStart, calendar: calendar)
        let taken = takenPeptides(on: Set(days))
        let skipped = Set(logs.filter {
            $0.status == .skipped && (selectedPeptide == nil || $0.peptideID == selectedPeptide)
        }.map(\.dayKey))
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                AppSectionTitle(title: monthStart.formatted(.dateTime.month(.wide).year()))
                Spacer()
                Button { monthOffset -= 1 } label: {
                    Image(systemName: "chevron.left").frame(width: 36, height: 36)
                }.accessibilityLabel("Previous month").accessibilityIdentifier("progress.month.prev")
                Button { monthOffset = 0 } label: {
                    Text("Today").font(.caption.weight(.semibold))
                }.accessibilityIdentifier("progress.month.today")
                Button { monthOffset += 1 } label: {
                    Image(systemName: "chevron.right").frame(width: 36, height: 36)
                }.disabled(monthOffset >= 0).accessibilityLabel("Next month").accessibilityIdentifier("progress.month.next")
            }
            .foregroundStyle(SetupTheme.ink)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(DayIdentity.weekdays(in: calendar), id: \.self) { weekday in
                    Text(calendar.veryShortWeekdaySymbols[weekday - 1]).font(.caption2.weight(.semibold)).foregroundStyle(SetupTheme.muted).frame(maxWidth: .infinity)
                }
                ForEach(days, id: \.self) { key in
                    let inMonth = isInDisplayedMonth(key, monthStart)
                    Button { selectedDay = HistoryDay(id: key) } label: {
                        DayCell(key: key, today: today, fraction: fraction(on: key), inMonth: inMonth,
                                taken: taken[key] ?? [], hasSkipped: skipped.contains(key))
                    }
                    .buttonStyle(.plain)
                    .disabled(!inMonth || key > today)
                    .accessibilityIdentifier("progress.day.\(key)")
                }
            }
            calendarLegend
        }
        .padding(16)
        .background(SetupTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(SetupTheme.border))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("progress.calendar")
    }

    /// Peptides with a taken dose on each day, in protocol order, honouring the
    /// peptide filter. Colour is for recognition only.
    private func takenPeptides(on days: Set<String>) -> [String: [TrackedPeptide]] {
        var ids: [String: Set<UUID>] = [:]
        for log in logs where log.status == .taken && days.contains(log.dayKey) {
            ids[log.dayKey, default: []].insert(log.peptideID)
        }
        let shown = peptides.filter { selectedPeptide == nil || $0.id == selectedPeptide }
        return ids.mapValues { set in shown.filter { set.contains($0.id) } }
    }

    @ViewBuilder private var calendarLegend: some View {
        let active = peptides.filter { !$0.isPaused }
        if !active.isEmpty {
            SetupFlowLayout(spacing: 12) {
                ForEach(active) { peptide in
                    HStack(spacing: 6) {
                        PeptideDot(color: peptide.displayColor)
                        Text(peptide.name).font(.caption.weight(.medium)).foregroundStyle(SetupTheme.ink).lineLimit(1)
                    }
                    .opacity(selectedPeptide == nil || selectedPeptide == peptide.id ? 1 : 0.35)
                }
            }
            .padding(.top, 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Colour key: \(active.map(\.name).joined(separator: ", "))")
            .accessibilityIdentifier("progress.calendar.legend")
        }
    }

    private var batchSection: some View {
        let batches = peptides.filter { $0.batchExpiryKey != nil }
        return Group {
            if !batches.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    AppSectionTitle(title: "Batch expiry")
                    ForEach(batches) { peptide in
                        let offset = peptide.batchExpiryOffset(from: today)
                        AppCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(peptide.name).font(.subheadline.weight(.semibold)).foregroundStyle(SetupTheme.ink)
                                    Text(peptide.batchExpirySummary ?? "")
                                        .font(.caption).foregroundStyle(SetupTheme.muted)
                                }
                                Spacer()
                                Text(batchLabel(offset))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(batchColor(offset))
                            }
                        }
                    }
                }
                .accessibilityIdentifier("progress.batches")
            }
        }
    }

    private func batchLabel(_ offset: Int?) -> String {
        guard let offset else { return "" }
        if offset > 1 { return "In \(offset) days" }
        if offset == 1 { return "Tomorrow" }
        if offset == 0 { return "Today" }
        if offset == -1 { return "Yesterday" }
        return "\(abs(offset)) days ago"
    }

    private func batchColor(_ offset: Int?) -> Color {
        guard let offset else { return SetupTheme.muted }
        if offset < 0 { return Color.red.opacity(0.85) }
        if offset <= 7 { return SetupTheme.ink }
        return SetupTheme.muted
    }

    private var siteMapSection: some View {
        let heat = ProtocolSchedule.spotHeat(logs: logs, peptideID: selectedPeptide)
        return Group {
            if !heat.counts.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    AppSectionTitle(title: "Pin sites")
                    Text("The same 3D map you use when logging. Cooler spots are ones you’ve used less lately — rotate however you prefer.")
                        .font(.caption).foregroundStyle(SetupTheme.muted)
                    InjectionSitePicker(
                        peptideName: selectedPeptide.flatMap(store.peptide)?.name ?? "All peptides",
                        heat: heat,
                        lastSpot: nil,
                        initial: nil,
                        isDemo: true,
                        onFinish: { _ in },
                        onCancel: {}
                    )
                    .frame(minHeight: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .accessibilityIdentifier("progress.sites")
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionTitle(title: "Dose history")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "All", selected: selectedPeptide == nil) { selectedPeptide = nil }
                    ForEach(peptides) { peptide in
                        FilterChip(title: peptide.name, selected: selectedPeptide == peptide.id) {
                            selectedPeptide = selectedPeptide == peptide.id ? nil : peptide.id
                        }
                    }
                }
            }
            let records = historyLogs
            if records.isEmpty {
                AppCard {
                    Text("Doses you log appear here, including entries without notes.")
                        .font(.subheadline).foregroundStyle(SetupTheme.muted)
                }
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(records.prefix(historyLimit)) { log in historyRow(log) }
                }
                if records.count > historyLimit {
                    Button("Show older doses") { historyLimit += 20 }
                }
            }
        }
    }

    private func historyRow(_ log: DoseLog) -> some View {
        DoseHistoryRow(log: log, peptide: store.peptide(log.peptideID))
    }

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AppSectionTitle(title: "Weight")
                Spacer()
                Button { showWeight = true } label: {
                    Label("Log", systemImage: "plus").font(.subheadline.weight(.semibold))
                }
                .accessibilityIdentifier("progress.weight.log")
            }
            let entries = store.journal.weights.sorted { ($0.dateKey ?? "") < ($1.dateKey ?? "") }
            if entries.count < 2 {
                AppCard {
                    Text(entries.isEmpty ? "Log a weight when you want a trend. It’s optional." : "Log one more weight to see a trend.")
                        .font(.subheadline).foregroundStyle(SetupTheme.muted)
                }
            } else {
                Chart(entries) { entry in
                    LineMark(x: .value("Day", entry.displayDate), y: .value("Weight", store.journal.weightUnit.display(entry.kilograms)))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(SetupTheme.ink)
                    PointMark(x: .value("Day", entry.displayDate), y: .value("Weight", store.journal.weightUnit.display(entry.kilograms)))
                        .foregroundStyle(SetupTheme.ink)
                }
                .chartYAxisLabel(store.journal.weightUnit.rawValue)
                .frame(height: 180)
                .padding(16)
                .background(SetupTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(SetupTheme.border))
                .accessibilityIdentifier("progress.weight.chart")
            }
        }
    }

    private var monthAnchor: Date {
        let calendar = Calendar.current
        let base = DayIdentity.date(for: today) ?? .now
        return calendar.date(byAdding: .month, value: monthOffset, to: calendar.date(from: calendar.dateComponents([.year, .month], from: base))!) ?? base
    }

    private func isInDisplayedMonth(_ key: String, _ monthStart: Date) -> Bool {
        guard let date = DayIdentity.date(for: key) else { return false }
        return Calendar.current.isDate(date, equalTo: monthStart, toGranularity: .month)
    }

    private func fraction(on key: String) -> Double? {
        let due = store.slots(on: key).filter { !$0.isExtra && (selectedPeptide == nil || $0.peptide.id == selectedPeptide) }
        guard !due.isEmpty, key <= today else { return nil }
        return Double(due.filter(\.isTaken).count) / Double(due.count)
    }
}

private struct AdherenceCard: View {
    var title: String
    var adherence: Adherence
    var body: some View {
        AppCard(padding: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(SetupTheme.muted)
                if let fraction = adherence.fraction {
                    Text("\(Int((fraction * 100).rounded()))%")
                        .font(.system(size: 34, weight: .bold)).tracking(-1).foregroundStyle(SetupTheme.ink)
                        .contentTransition(.numericText())
                } else {
                    Text("—").font(.system(size: 34, weight: .bold)).foregroundStyle(SetupTheme.muted)
                }
                Text(caption).font(.caption).foregroundStyle(SetupTheme.muted).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    private var caption: String {
        if adherence.due == 0 { return "No doses due yet" }
        var parts = ["\(adherence.taken) logged"]
        if adherence.skipped > 0 { parts.append("\(adherence.skipped) skipped") }
        if adherence.unlogged > 0 { parts.append("\(adherence.unlogged) not logged") }
        return parts.joined(separator: " · ")
    }
}

private struct DayCell: View {
    var key: String
    var today: String
    var fraction: Double?
    var inMonth: Bool
    /// Peptides with a taken dose this day, in protocol order.
    var taken: [TrackedPeptide] = []
    var hasSkipped = false
    private static let maximumDots = 3

    var body: some View {
        let day = DayIdentity.formatted(key: key, rawDate: .now, style: .dateTime.day())
        let shown = inMonth ? taken : []
        VStack(spacing: 3) {
            DoseRing(fraction: inMonth ? fraction : nil, lineWidth: 2.5, tint: SetupTheme.ink) {
                Text(day).font(.system(size: 11, weight: key == today ? .bold : .medium))
                    .foregroundStyle(inMonth ? (key > today ? SetupTheme.muted : SetupTheme.ink) : SetupTheme.disabled)
            }
            .frame(width: 30, height: 30)
            HStack(spacing: 2) {
                if hasSkipped && inMonth {
                    Image(systemName: "minus").font(.system(size: 7, weight: .bold)).foregroundStyle(SetupTheme.muted)
                }
                ForEach(shown.prefix(Self.maximumDots)) { PeptideDot(color: $0.displayColor, size: 5) }
                if shown.count > Self.maximumDots {
                    Text("+").font(.system(size: 8, weight: .bold)).foregroundStyle(SetupTheme.muted)
                }
            }
            .frame(height: 7)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .opacity(inMonth ? 1 : 0.35)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label(for: shown))
    }

    private func label(for shown: [TrackedPeptide]) -> String {
        let date = DayIdentity.formatted(key: key, rawDate: .now, style: .dateTime.weekday(.wide).day().month(.wide))
        var description = date
        if !shown.isEmpty { description += ", \(shown.map(\.name).joined(separator: ", ")) taken" }
        if hasSkipped { description += ", skipped dose" }
        return description
    }
}

private struct FilterChip: View {
    var title: String
    var selected: Bool
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(.subheadline, weight: .semibold)).lineLimit(1)
                .foregroundStyle(selected ? SetupTheme.inverseInk : SetupTheme.ink)
                .padding(.horizontal, 14).frame(minHeight: 36)
                .background(selected ? SetupTheme.ink : SetupTheme.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(selected ? SetupTheme.ink : SetupTheme.border))
        }
        .buttonStyle(SetupPressStyle())
    }
}

private struct DoseHistoryRow: View {
    var log: DoseLog
    var peptide: TrackedPeptide?
    var inCalendar = false
    @State private var editor: DoseSheet.Mode?

    var body: some View {
        Button {
            guard let peptide else { return }
            editor = .slot(DoseSlot(peptide: peptide, dayKey: log.dayKey, time: log.scheduledTime, log: log))
        } label: { content }
        .buttonStyle(.plain)
        .accessibilityHint("Edit this dose record")
        .accessibilityIdentifier((inCalendar ? "progress.day-entry." : "progress.entry.") + log.id.uuidString)
        .sheet(item: $editor) { DoseSheet(mode: $0) }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(peptide?.name ?? "Peptide").font(.subheadline.weight(.semibold)).foregroundStyle(SetupTheme.ink)
                Spacer()
                Text(DayIdentity.formatted(key: log.dayKey, rawDate: log.takenAt, style: .dateTime.month(.abbreviated).day()))
                    .font(.caption).foregroundStyle(SetupTheme.muted)
            }
            Text("\(log.status == .taken ? "Taken" : "Skipped") · \(log.takenAt.formatted(date: .omitted, time: .shortened))")
                .font(.subheadline).foregroundStyle(SetupTheme.ink)
            let details = [log.scheduledTime == nil ? "Extra dose" : nil, log.amountText, log.spot?.title ?? log.site?.title].compactMap { $0 }.joined(separator: " · ")
            if !details.isEmpty { Text(details).font(.caption).foregroundStyle(SetupTheme.muted) }
            if !log.note.isEmpty {
                Text(log.note).font(.subheadline).foregroundStyle(SetupTheme.ink).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SetupTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(SetupTheme.border))
        .accessibilityElement(children: .combine)
    }
}

struct WeightLogSheet: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var date = Date.now
    @State private var unit: WeightUnit = .kg

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Log weight").font(.headline).foregroundStyle(SetupTheme.ink)
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .bold))
                            .frame(width: 32, height: 32).background(SetupTheme.tile, in: Circle())
                    }.frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 14).padding(.top, 18).padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 18) {
                SetupUnitToggle(left: "kg", right: "lb", isRight: Binding(get: { unit == .lb }, set: { unit = $0 ? .lb : .kg }))
                TextField("Weight", text: $text).keyboardType(.decimalPad)
                    .font(.system(size: 28, weight: .bold))
                    .padding(.horizontal, 16).frame(minHeight: 56)
                    .background(SetupTheme.tile, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityIdentifier("progress.weight.value")
                DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date)
                    .labelsHidden()
            }
            .padding(22)

            Spacer()
            SetupPrimaryButton(title: "Save weight", enabled: parsed != nil, identifier: "progress.weight.save") {
                if let parsed, store.addWeight(value: parsed, unit: unit, date: date) { dismiss() }
            }
            .padding(.horizontal, 22).padding(.bottom, 12)
        }
        .background(SetupTheme.surface)
        .presentationDetents([.medium])
        .onAppear { unit = store.journal.weightUnit }
    }

    private var parsed: Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(trimmed), value > 0 else { return nil }
        return value
    }
}
