import Charts
import SwiftUI

/// Adherence, dose calendar, notes and optional weight trend.
struct ProgressScreen: View {
    @Environment(JournalStore.self) private var store
    @State private var monthOffset = 0
    @State private var selectedPeptide: UUID?
    @State private var showWeight = false

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
    private var noted: [DoseLog] {
            logs.filter { !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .filter { selectedPeptide == nil || $0.peptideID == selectedPeptide }
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
                    adherenceCards
                    if let selected = selectedPeptide.flatMap(store.peptide) {
                        PeptideReferenceChart(name: selected.name)
                    } else if peptides.count == 1, let only = peptides.first {
                        PeptideReferenceChart(name: only.name)
                    }
                    batchSection
                    siteMapSection
                    calendar
                    history
                    if showsWeight { weightSection }
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .sheet(isPresented: $showWeight) { WeightLogSheet() }
    }

    private var header: some View {
        HStack {
            Text("Progress").font(.system(size: 30, weight: .bold)).tracking(-0.6).foregroundStyle(SetupTheme.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            PreviewBadge()
        }
        .padding(.top, 8)
    }

    private var empty: some View {
        AppCard(padding: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Nothing to chart yet").font(.headline).foregroundStyle(SetupTheme.ink)
                Text("Once you log doses, adherence and notes show up here. Unlogged days stay blank — never marked as missed.")
                    .font(.subheadline).foregroundStyle(SetupTheme.muted)
            }
        }
    }

    private var adherenceCards: some View {
        HStack(spacing: 12) {
            AdherenceCard(title: "7 days", adherence: week)
            AdherenceCard(title: "30 days", adherence: month)
        }
        .accessibilityIdentifier("progress.adherence")
    }

    private var calendar: some View {
        let monthStart = monthAnchor
        let days = monthDays(around: monthStart)
        let taken = takenPeptides(on: Set(days))
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
                ForEach(Array(Calendar.current.veryShortWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol).font(.caption2.weight(.semibold)).foregroundStyle(SetupTheme.muted).frame(maxWidth: .infinity)
                }
                ForEach(days, id: \.self) { key in
                    DayCell(key: key, today: today, fraction: fraction(on: key), inMonth: isInDisplayedMonth(key, monthStart),
                            taken: taken[key] ?? [])
                }
            }
            calendarLegend
        }
        .padding(16)
        .background(SetupTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(SetupTheme.border))
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
        let heat = ProtocolSchedule.siteHeat(
            logs: logs,
            peptideID: selectedPeptide
        )
        return Group {
            if heat.total > 0 {
                VStack(alignment: .leading, spacing: 12) {
                    AppSectionTitle(title: "Pin sites")
                    Text("Recent logs by body region. Cooler spots are ones you’ve used less lately — rotate however you prefer.")
                        .font(.caption).foregroundStyle(SetupTheme.muted)
                    BodyMapView(
                        selection: .constant(nil),
                        heat: heat,
                        interactive: false,
                        autoRotate: true,
                        accessibilityPrefix: "progress.site"
                    )
                }
                .accessibilityIdentifier("progress.sites")
            }
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionTitle(title: "Notes with doses")
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
            if noted.isEmpty {
                AppCard {
                    Text("Notes you add when logging a dose appear here.")
                        .font(.subheadline).foregroundStyle(SetupTheme.muted)
                }
            } else {
                ForEach(noted.prefix(20)) { log in
                    NoteRow(log: log, peptideName: store.peptide(log.peptideID)?.name ?? "Peptide")
                }
            }
        }
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

    private func monthDays(around monthStart: Date) -> [String] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: monthStart),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: monthStart)) else { return [] }
        let weekday = calendar.component(.weekday, from: first)
        // Monday-first padding.
        let leading = (weekday + 5) % 7
        let start = calendar.date(byAdding: .day, value: -leading, to: first) ?? first
        return (0..<(leading + range.count)).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start).flatMap { DayIdentity.key(for: $0) }
        }
    }

    private func isInDisplayedMonth(_ key: String, _ monthStart: Date) -> Bool {
        guard let date = DayIdentity.date(for: key) else { return false }
        return Calendar.current.isDate(date, equalTo: monthStart, toGranularity: .month)
    }

    private func fraction(on key: String) -> Double? {
        let due = store.slots(on: key).filter { !$0.isExtra }
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
        guard !shown.isEmpty else { return date }
        return "\(date), \(shown.map(\.name).joined(separator: ", ")) taken"
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

private struct NoteRow: View {
    var log: DoseLog
    var peptideName: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(peptideName).font(.subheadline.weight(.semibold)).foregroundStyle(SetupTheme.ink)
                Spacer()
                Text(DayIdentity.formatted(key: log.dayKey, rawDate: log.takenAt, style: .dateTime.month(.abbreviated).day()))
                    .font(.caption).foregroundStyle(SetupTheme.muted)
            }
            Text(log.note).font(.subheadline).foregroundStyle(SetupTheme.ink).fixedSize(horizontal: false, vertical: true)
            if let amount = log.amountText {
                Text(amount).font(.caption).foregroundStyle(SetupTheme.muted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SetupTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(SetupTheme.border))
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
