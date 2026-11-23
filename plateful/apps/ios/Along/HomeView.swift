import SwiftUI

/// Today: the week at a glance, the day's doses and one-tap logging.
struct HomeView: View {
    @Environment(JournalStore.self) private var store
    @State private var selectedDay: String?
    @State private var feedback = 0
    @State private var sheet: DoseSheet.Mode?

    private var today: String { store.todayKey }
    private var day: String { selectedDay ?? today }
    private var slots: [DoseSlot] { store.slots(on: day) }
    private var scheduled: [DoseSlot] { slots.filter { !$0.isExtra } }
    private var isToday: Bool { day == today }
    private var isFuture: Bool { day > today }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                DayStrip(selected: day, today: today, fraction: fraction(on:)) { selectedDay = $0 }
                summary
                if isToday, let next = ProtocolSchedule.nextDose(after: store.referenceDate, peptides: store.journal.protocolPeptides, logs: store.journal.protocolLogs) {
                    nextDose(next.slot, at: next.at)
                }
                doses
            }
            .padding(.horizontal, 20).padding(.bottom, 96)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .overlay(alignment: .bottomTrailing) {
            if !store.journal.protocolPeptides.isEmpty && !isFuture {
                Button { sheet = .extra(dayKey: day) } label: {
                    Image(systemName: "plus").font(.system(size: 22, weight: .semibold)).foregroundStyle(SetupTheme.inverseInk)
                        .frame(width: 58, height: 58).background(SetupTheme.ink, in: Circle())
                        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                }
                .buttonStyle(SetupPressStyle())
                .accessibilityLabel("Log an extra dose").accessibilityIdentifier("today.log-extra")
                .padding(.trailing, 20).padding(.bottom, 16)
            }
        }
        .sheet(item: $sheet) { DoseSheet(mode: $0) }
        .sensoryFeedback(.success, trigger: feedback)
        .onChange(of: store.todayKey) { _, _ in selectedDay = nil }
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill").font(.system(size: 18, weight: .semibold))
                Text("Along").font(.system(size: 26, weight: .bold)).tracking(-0.5)
            }.foregroundStyle(SetupTheme.ink).accessibilityAddTraits(.isHeader)
            Spacer()
            PreviewBadge()
        }
        .padding(.top, 8)
    }

    private func fraction(on key: String) -> Double? {
        let due = store.slots(on: key).filter { !$0.isExtra }
        guard !due.isEmpty else { return nil }
        return Double(due.filter(\.isTaken).count) / Double(due.count)
    }

    private var dayTitle: String {
        if isToday { return "Today" }
        if ProtocolSchedule.key(today, adding: -1) == day { return "Yesterday" }
        if ProtocolSchedule.key(today, adding: 1) == day { return "Tomorrow" }
        return DayIdentity.formatted(key: day, rawDate: .now, style: .dateTime.weekday(.wide).day().month(.abbreviated))
    }

    private var summary: some View {
        let taken = scheduled.filter(\.isTaken).count
        return AppCard(padding: 22) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(dayTitle).font(.subheadline.weight(.medium)).foregroundStyle(SetupTheme.muted)
                    if scheduled.isEmpty {
                        Text("No doses").font(.system(size: 34, weight: .bold)).tracking(-0.8)
                        Text(store.journal.protocolPeptides.isEmpty ? "Add a peptide to build your schedule" : "Nothing scheduled")
                            .font(.subheadline).foregroundStyle(SetupTheme.muted)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(taken)").font(.system(size: 44, weight: .bold)).contentTransition(.numericText())
                            Text("/ \(scheduled.count)").font(.system(size: 22, weight: .semibold)).foregroundStyle(SetupTheme.muted)
                        }.tracking(-1)
                        Text(isFuture ? "doses planned" : taken == scheduled.count ? "All doses logged" : "doses logged")
                            .font(.subheadline).foregroundStyle(SetupTheme.muted)
                    }
                }
                .foregroundStyle(SetupTheme.ink)
                Spacer()
                DoseRing(fraction: scheduled.isEmpty ? nil : Double(taken) / Double(scheduled.count), lineWidth: 9,
                         tint: taken == scheduled.count && !scheduled.isEmpty ? SetupTheme.success : SetupTheme.ink) {
                    Image(systemName: taken == scheduled.count && !scheduled.isEmpty ? "checkmark" : "syringe")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(taken == scheduled.count && !scheduled.isEmpty ? SetupTheme.success : SetupTheme.ink)
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: 96, height: 96)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("today.summary")
    }

    private func nextDose(_ slot: DoseSlot, at moment: Date) -> some View {
        let calendar = Calendar.current
        let when = calendar.isDateInToday(moment) ? moment.formatted(date: .omitted, time: .shortened)
            : moment.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        return HStack(spacing: 12) {
            Image(systemName: "clock").font(.system(size: 15, weight: .semibold)).foregroundStyle(SetupTheme.ink)
                .frame(width: 36, height: 36).background(SetupTheme.surface, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Next dose").font(.caption).foregroundStyle(SetupTheme.muted)
                Text([slot.peptide.name, slot.peptide.amountText].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(SetupTheme.ink)
            }
            Spacer()
            Text(when).font(.subheadline.weight(.semibold)).foregroundStyle(SetupTheme.ink)
        }
        .padding(12)
        .background(SetupTheme.iconTile, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("today.next")
    }

    @ViewBuilder private var doses: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionTitle(title: isToday ? "Today’s doses" : "Doses", trailing: slots.isEmpty ? nil : "\(slots.count)")
            if store.journal.protocolPeptides.isEmpty {
                emptyProtocol
            } else if slots.isEmpty {
                AppCard {
                    Text(isFuture ? "Nothing is scheduled for this day." : "Nothing was scheduled for this day.")
                        .font(.subheadline).foregroundStyle(SetupTheme.muted)
                }
            } else {
                ForEach(slots) { slot in
                    DoseRow(slot: slot, canLog: !isFuture, toggle: { toggle(slot) }, setStatus: { set(slot, $0) })
                        .onTapGesture { if !isFuture { sheet = .slot(slot) } }
                }
            }
        }
    }

    private var emptyProtocol: some View {
        AppCard(padding: 22) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Your protocol is empty").font(.headline).foregroundStyle(SetupTheme.ink)
                Text("Add each peptide with the schedule you’ve chosen. Along keeps track of every dose from there.")
                    .font(.subheadline).foregroundStyle(SetupTheme.muted).fixedSize(horizontal: false, vertical: true)
                SetupPrimaryButton(title: "Add a peptide", symbol: "plus", identifier: "today.add-peptide") { store.selectedTab = 1 }
            }
        }
    }

    private func moment(for slot: DoseSlot) -> Date {
        if isToday { return .now }
        return slot.time?.date(on: slot.dayKey) ?? DayIdentity.date(for: slot.dayKey) ?? .now
    }

    private func toggle(_ slot: DoseSlot) {
        if let log = slot.log, log.status == .taken {
            store.removeDose(log.id)
        } else if store.logDose(slot, status: .taken, at: moment(for: slot)) {
            feedback += 1
            store.showToast("\(slot.peptide.name) logged")
        }
    }

    private func set(_ slot: DoseSlot, _ status: DoseLog.Status?) {
        guard let status else { if let log = slot.log { store.removeDose(log.id) }; return }
        if store.logDose(slot, status: status, at: moment(for: slot)), status == .taken { feedback += 1 }
    }
}

struct DoseRow: View {
    var slot: DoseSlot
    var canLog: Bool
    var toggle: () -> Void
    var setStatus: (DoseLog.Status?) -> Void

    private var detail: String {
        var parts: [String] = []
        if let amount = slot.log?.amountText ?? slot.peptide.amountText { parts.append(amount) }
        if slot.isExtra, let log = slot.log { parts.append("Extra · \(log.takenAt.formatted(date: .omitted, time: .shortened))") }
        else if let time = slot.time { parts.append(time.text) }
        if let label = slot.log?.spot?.shortTitle ?? slot.log?.site?.shortTitle { parts.append(label) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 14) {
            PeptideBadge(name: slot.peptide.name, dimmed: slot.isSkipped)
            VStack(alignment: .leading, spacing: 3) {
                Text(slot.peptide.name).font(.system(.body, weight: .semibold)).foregroundStyle(SetupTheme.ink)
                    .strikethrough(slot.isSkipped, color: SetupTheme.muted)
                Text(slot.isSkipped ? "Skipped" : detail).font(.footnote).foregroundStyle(SetupTheme.muted)
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(slot.isTaken ? "Taken" : slot.isSkipped ? "Skipped" : "Not logged")
            .accessibilityHint(canLog ? "Opens dose details" : "")
            .accessibilityAddTraits(canLog ? .isButton : [])
            .accessibilityIdentifier("today.dose.\(slot.peptide.name)")
            Spacer(minLength: 8)
            if canLog { checkButton }
        }
        .padding(14)
        .background(SetupTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(slot.isTaken ? SetupTheme.ink.opacity(0.9) : SetupTheme.border, lineWidth: slot.isTaken ? 1.5 : 1))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contextMenu {
            if canLog && !slot.isExtra {
                Button { setStatus(.taken) } label: { Label("Mark as taken", systemImage: "checkmark.circle") }
                Button { setStatus(.skipped) } label: { Label("Skip this dose", systemImage: "forward") }
                if slot.log != nil { Button(role: .destructive) { setStatus(nil) } label: { Label("Clear", systemImage: "arrow.uturn.backward") } }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var checkButton: some View {
        Button(action: toggle) {
            ZStack {
                Circle().strokeBorder(slot.isTaken ? Color.clear : SetupTheme.border, lineWidth: 1.5)
                    .background(Circle().fill(slot.isTaken ? SetupTheme.ink : Color.clear))
                Image(systemName: slot.isSkipped ? "forward.fill" : "checkmark")
                    .font(.system(size: slot.isSkipped ? 11 : 15, weight: .bold))
                    .foregroundStyle(slot.isTaken ? SetupTheme.inverseInk : slot.isSkipped ? SetupTheme.muted : SetupTheme.disabled)
            }
            .frame(width: 40, height: 40)
            .frame(width: 48, height: 48)
            .contentShape(Circle())
        }
        .buttonStyle(SetupPressStyle())
        .accessibilityLabel(slot.isTaken ? "Undo \(slot.peptide.name)" : "Log \(slot.peptide.name)")
        .accessibilityIdentifier("today.dose.\(slot.peptide.name).toggle")
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: slot.isTaken)
    }
}

/// Scrollable strip of days with a completion ring under each date.
struct DayStrip: View {
    var selected: String
    var today: String
    var fraction: (String) -> Double?
    var select: (String) -> Void

    private var days: [String] { (-27...3).compactMap { ProtocolSchedule.key(today, adding: $0) } }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(days, id: \.self) { key in cell(key) }
            }
            .padding(.horizontal, 2)
        }
        .defaultScrollAnchor(.trailing)
        .sensoryFeedback(.selection, trigger: selected)
    }

    private func cell(_ key: String) -> some View {
        let isSelected = key == selected, isFuture = key > today
        let weekday = DayIdentity.formatted(key: key, rawDate: .now, style: .dateTime.weekday(.narrow))
        let number = DayIdentity.formatted(key: key, rawDate: .now, style: .dateTime.day())
        return Button { select(key) } label: {
            VStack(spacing: 6) {
                Text(weekday).font(.caption2.weight(.semibold)).foregroundStyle(isSelected ? SetupTheme.ink : SetupTheme.muted)
                DoseRing(fraction: fraction(key), lineWidth: 3, tint: isFuture ? SetupTheme.disabled : SetupTheme.ink) {
                    Text(number).font(.system(size: 14, weight: key == today ? .bold : .medium))
                        .foregroundStyle(isFuture ? SetupTheme.muted : SetupTheme.ink)
                }
                .frame(width: 34, height: 34)
            }
            .padding(.vertical, 8).frame(width: 46)
            .background(isSelected ? SetupTheme.surface : Color.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(isSelected ? SetupTheme.border : .clear))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(DayIdentity.formatted(key: key, rawDate: .now, style: .dateTime.weekday(.wide).day().month(.wide)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("today.day.\(key)")
    }
}
