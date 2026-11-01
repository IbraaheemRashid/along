import SwiftUI

struct TodayView: View {
    @Environment(JournalStore.self) private var store
    @State private var showCheckIn = false
    @State private var showMilestone = false
    @State private var showRecap = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("along").font(.system(size: 29, weight: .semibold, design: .serif)).foregroundStyle(Theme.accent)
                        Spacer()
                        DemoBadge()
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        ViewThatFits(in: .horizontal) {
                            HStack { dateLabel; Spacer(); daysLabel }
                            VStack(alignment: .leading, spacing: 4) { dateLabel; daysLabel }
                        }
                        Text(store.journal.name.isEmpty ? "Your journey, at your pace." : "A little space for you, \(store.journal.name).")
                            .alongTitle(25).fixedSize(horizontal: false, vertical: true)
                    }
                    PipPlayground(name: store.companionName, accessory: store.journal.accessory, message: store.encouragementLine)
                    Button { store.selectedTab = 2 } label: {
                        HStack {
                            Label("Visit \(store.companionName)’s place", systemImage: "pawprint")
                            Spacer(); Image(systemName: "arrow.right")
                        }.font(.system(.subheadline, design: .rounded, weight: .semibold)).foregroundStyle(Theme.accent)
                            .padding(.horizontal, 16).frame(minHeight: 48).background(Theme.softAccent, in: RoundedRectangle(cornerRadius: 18))
                    }.buttonStyle(.plain).accessibilityIdentifier("today.companion")
                    PrimaryButton(title: store.today == nil ? "How’s today feeling?" : "View today’s check-in", symbol: store.today == nil ? "arrow.right" : "checkmark.circle") { showCheckIn = true }
                        .accessibilityIdentifier("today.checkIn")
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(title: "Little things, your way", subtitle: "Room for the routines you choose.")
                        if store.journal.routines.isEmpty {
                            Text("A check-in can be enough. Add optional routines in You whenever you like.")
                                .font(.subheadline).foregroundStyle(Theme.secondaryInk).frame(maxWidth: .infinity, alignment: .leading).card()
                        } else {
                            ForEach(Routine.allCases.filter { store.journal.routines.contains($0) }) { routine in
                                routineRow(routine)
                            }
                        }
                    }
                    Button { showRecap = true } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "book.closed").font(.title2).foregroundStyle(Theme.accent)
                                .frame(width: 44, height: 48).background(Theme.lilac.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(store.reflectionSchedule ?? "Your week, reflected").font(.headline)
                                Text("\(store.week.count) days recorded · a little perspective").font(.caption).foregroundStyle(Theme.secondaryInk)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right").foregroundStyle(Theme.accent)
                        }.card(padding: 17)
                    }.buttonStyle(.plain)
                    HStack(alignment: .center) {
                        SectionLabel(title: "Worth remembering", subtitle: "Progress comes in all kinds of moments.")
                        Button { showMilestone = true } label: {
                            Image(systemName: "plus").font(.headline).frame(width: 44, height: 44)
                                .background(Theme.lilac.opacity(0.4), in: Circle())
                        }.accessibilityLabel("Add a milestone")
                    }
                    if let milestone = store.journal.milestones.max(by: { $0.date < $1.date }) { MilestoneCard(milestone: milestone) }
                    else {
                        Button { showMilestone = true } label: {
                            QuietEmpty(symbol: "sparkles", title: "The little wins belong here", detail: "A walk, a new routine, or a moment of confidence. Save something that mattered to you.")
                        }.buttonStyle(.plain)
                    }
                    Text(store.journal.hasSampleData ? "You’re exploring fictional sample records. Start a blank journal in You at any time." : "Your journal stays on this device. Along doesn’t offer medical advice.")
                        .font(.caption).foregroundStyle(Theme.secondaryInk).padding(.bottom, 12)
                }.padding(.horizontal, 22).padding(.top, topClearance).padding(.bottom, 20).frame(maxWidth: 650)
            }.frame(maxWidth: .infinity).pageBackground().toolbar(.hidden, for: .navigationBar)
                .sheet(isPresented: $showCheckIn) { CheckInView(entry: store.today) }
                .sheet(isPresented: $showMilestone) { AddMilestoneView() }
                .sheet(isPresented: $showRecap) { WeeklyRecapView() }
        }
    }
    private var topClearance: CGFloat {
        // On iOS 26, the hidden navigation bar starts this scroll view behind
        // the 44-point development strip. Release builds have no strip.
        #if DEBUG
        56
        #else
        12
        #endif
    }
    private var dateLabel: some View {
        Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)).uppercased())
            .font(.caption.weight(.medium)).tracking(1).foregroundStyle(Theme.secondaryInk)
    }
    private var daysLabel: some View {
        Text("\(store.daysTogether) \(store.daysTogether == 1 ? "day" : "days") together")
            .font(.caption.weight(.medium)).foregroundStyle(Theme.accent)
    }
    private func routineRow(_ routine: Routine) -> some View {
        let recorded = store.today?.routines.contains(routine) == true
        return Button { showCheckIn = true } label: {
            HStack(spacing: 12) {
                Image(systemName: routine.symbol).font(.title3).foregroundStyle(Theme.accent)
                    .frame(width: 40, height: 40).background(Theme.lilac.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                Text(store.routineTitle(routine)).font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: recorded ? "checkmark.circle.fill" : "chevron.right")
                    .font(recorded ? .title3 : .caption.weight(.semibold)).foregroundStyle(Theme.accent)
            }.frame(minHeight: 44).card(padding: 12)
        }.buttonStyle(.plain)
            .accessibilityLabel("\(store.routineTitle(routine)), \(recorded ? "recorded today" : "not recorded today")")
            .accessibilityHint("Opens your check-in")
    }
}

struct MilestoneCard: View {
    var milestone: Milestone
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: milestone.kind.symbol).font(.title2).foregroundStyle(Theme.ink).frame(width: 48, height: 48).background(Theme.gold.opacity(0.65), in: RoundedRectangle(cornerRadius: 15))
            VStack(alignment: .leading, spacing: 7) {
                HStack { Text(milestone.date.formatted(.dateTime.day().month(.abbreviated)).uppercased()).tracking(1); if milestone.isSample { Text("· SAMPLE") } }.font(.caption2.weight(.medium)).foregroundStyle(Theme.secondaryInk)
                Text(milestone.title).font(.headline)
                if !milestone.note.isEmpty { Text(milestone.note).font(.subheadline).foregroundStyle(Theme.secondaryInk) }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.card()
    }
}

struct WeeklyRecapView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PipRoomView(accessory: store.journal.accessory, pose: .journal, height: 210).clipShape(RoundedRectangle(cornerRadius: 28))
                    DemoBadge()
                    Text("A week of little moments.").alongTitle(30)
                    Text("The last seven days, from the entries you chose to keep.").foregroundStyle(Theme.secondaryInk)
                    HStack(spacing: 14) {
                        recapMetric("\(store.week.count)", label: "days recorded", symbol: "book")
                        recapMetric("\(store.routineCount)", label: "routine moments", symbol: "leaf")
                    }
                    Text(store.recap).font(.system(.body, design: .serif)).lineSpacing(6).frame(maxWidth: .infinity, alignment: .leading).card()
                    if let prompt = store.personalReflectionPrompt { SetupNote(text: prompt, symbol: "pencil.line") }
                    if !store.weeklyMilestones.isEmpty {
                        SectionLabel(title: "\(store.weeklyMilestones.count) moments you kept")
                        ForEach(store.weeklyMilestones) { MilestoneCard(milestone: $0) }
                    }
                    Text("A journal summary, not a health assessment. This recap uses simple on-device counts; no AI service is connected.").font(.caption).foregroundStyle(Theme.secondaryInk)
                    PrimaryButton(title: "Keep going at my pace", symbol: "heart") { dismiss() }
                }.padding(24).frame(maxWidth: 620)
            }.frame(maxWidth: .infinity).pageBackground().navigationTitle("Your weekly reflection").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
    private func recapMetric(_ value: String, label: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 9) { Image(systemName: symbol).foregroundStyle(Theme.accent); Text(value).alongTitle(34); Text(label).font(.caption).foregroundStyle(Theme.secondaryInk) }.frame(maxWidth: .infinity, alignment: .leading).card()
    }
}
