import SwiftUI
import Charts

private enum JourneyMoment: Identifiable {
    case checkIn(CheckIn), milestone(Milestone), weight(WeightEntry)
    var id: UUID { switch self { case .checkIn(let item): item.id; case .milestone(let item): item.id; case .weight(let item): item.id } }
    var date: Date { switch self { case .checkIn(let item): item.day; case .milestone(let item): item.date; case .weight(let item): item.date } }
}
struct JourneyView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var filter = 0
    @State private var showMilestone = false
    @State private var showWeight = false
    @State private var showNewCheckIn = false
    @State private var showRecap = false
    @State private var selectedEntry: CheckIn?
    @State private var pendingDelete: JourneyMoment?
    private var moments: [JourneyMoment] {
        var items = store.journal.milestones.map(JourneyMoment.milestone)
        if filter == 0 {
            items += store.journal.checkIns.map(JourneyMoment.checkIn)
            if store.journal.showWeight { items += store.journal.weights.map(JourneyMoment.weight) }
        }
        return items.sorted { $0.date > $1.date }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        DemoBadge()
                        Spacer()
                        Menu {
                            Button("Check-in", systemImage: "square.and.pencil") { showNewCheckIn = true }
                            Button("Personal milestone", systemImage: "sparkles") { showMilestone = true }
                            Button("Weight record (optional)", systemImage: "chart.xyaxis.line") { showWeight = true }
                        } label: {
                            Image(systemName: "plus").font(.headline).frame(width: 44, height: 44)
                                .background(Theme.softAccent, in: Circle())
                        }.accessibilityLabel("Add to your journey")
                    }
                    CompanionHeading(title: "Look how much you’ve lived.", detail: "The little things deserve a place, too.", accessory: store.journal.accessory)
                    let layout = textSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
                    layout {
                        stat("\(store.journal.checkIns.count)", label: "days recorded", symbol: "book")
                        stat("\(store.journal.milestones.count)", label: "moments kept", symbol: "sparkles")
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        HStack { Text("Your last seven days").font(.headline); Spacer(); Image(systemName: "calendar").foregroundStyle(Theme.accent) }
                        HStack(spacing: 0) {
                            ForEach((-6...0), id: \.self) { offset in
                                let date = Calendar.current.date(byAdding: .day, value: offset, to: Date.now)!
                                let record = store.journal.checkIns.first { Calendar.current.isDate($0.day, inSameDayAs: date) }
                                VStack(spacing: 9) {
                                    Text(date.formatted(.dateTime.weekday(.narrow))).font(.caption).foregroundStyle(Theme.secondaryInk)
                                    ZStack { Circle().fill(record == nil ? Theme.paper : Theme.softApricot); if let record { Image(systemName: record.mood.symbol).font(.system(size: 14)).foregroundStyle(Theme.accent) } else { Circle().fill(.secondary.opacity(0.3)).frame(width: 4, height: 4) } }.frame(width: 33, height: 33)
                                    Text(date.formatted(.dateTime.day())).font(.caption2).foregroundStyle(Theme.secondaryInk)
                                }.frame(maxWidth: .infinity).accessibilityElement(children: .ignore).accessibilityLabel("\(date.formatted(date: .abbreviated, time: .omitted)): \(record?.mood.title ?? "No entry")")
                            }
                        }
                        Text("A record, not a streak. Blank days are simply unrecorded.").font(.caption).foregroundStyle(Theme.secondaryInk)
                    }.card()
                    if store.journal.showWeight { WeightChartCard() }
                    Button { showRecap = true } label: {
                        HStack { Label("Read your weekly reflection", systemImage: "text.book.closed").font(.subheadline.weight(.semibold)); Spacer(); Image(systemName: "arrow.right") }.padding(18).background(Theme.softAccent, in: RoundedRectangle(cornerRadius: 18))
                    }.buttonStyle(.plain)
                    Picker("Journey view", selection: $filter) { Text("All moments").tag(0); Text("Milestones").tag(1) }.pickerStyle(.segmented)
                    if moments.isEmpty {
                        QuietEmpty(symbol: "book.pages", title: filter == 1 ? "Keep something that mattered" : "Your story starts here", detail: "Use the + button to save a check-in or a personal milestone. There’s no schedule to keep up with.")
                    } else {
                        LazyVStack(spacing: 17) {
                            ForEach(moments) { moment in
                                HStack(alignment: .top, spacing: 13) {
                                    VStack(spacing: 5) { Circle().fill(isMilestone(moment) ? Theme.gold : Theme.lilac).frame(width: 11, height: 11).padding(.top, 25); Rectangle().fill(Theme.line).frame(width: 1) }.frame(width: 11)
                                    momentView(moment).contextMenu {
                                        if case .checkIn(let entry) = moment { Button("Edit check-in", systemImage: "pencil") { selectedEntry = entry } }
                                        Button("Delete entry", systemImage: "trash", role: .destructive) { pendingDelete = moment }
                                    }
                                }
                            }
                        }
                    }
                    Text("Touch and hold an entry to remove it. Your record is yours to edit.").font(.caption).foregroundStyle(Theme.secondaryInk).padding(.bottom, 16)
                }.padding(22).frame(maxWidth: 650)
            }.frame(maxWidth: .infinity).pageBackground().navigationTitle("Your journey").navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showMilestone) { AddMilestoneView() }
                .sheet(isPresented: $showWeight) { AddWeightView() }
                .sheet(isPresented: $showNewCheckIn) { CheckInView(entry: store.today) }
                .sheet(item: $selectedEntry) { CheckInView(entry: $0) }
                .sheet(isPresented: $showRecap) { WeeklyRecapView() }
                .confirmationDialog("Delete this entry?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
                    Button("Delete entry", role: .destructive) {
                        if let pendingDelete { switch pendingDelete { case .checkIn(let item): store.removeCheckIn(item.id); case .milestone(let item): store.removeMilestone(item.id); case .weight(let item): store.removeWeight(item.id) } }; pendingDelete = nil
                    }
                } message: { Text("This removes the entry from this device. It can’t be undone.") }
        }
    }
    private func isMilestone(_ moment: JourneyMoment) -> Bool { if case .milestone = moment { true } else { false } }
    private func stat(_ value: String, label: String, symbol: String) -> some View {
        HStack(spacing: 12) { AlongIcon(symbol: symbol, apricot: true); VStack(alignment: .leading, spacing: 4) { Text(value).font(.system(size: 28, weight: .medium, design: .serif)).accessibilityIdentifier(label == "days recorded" ? "journey.daysRecorded" : "journey.momentsKept"); Text(label).font(.caption).foregroundStyle(Theme.secondaryInk) }; Spacer(minLength: 0) }.frame(maxWidth: .infinity, alignment: .leading).card(padding: 17)
    }
    @ViewBuilder private func momentView(_ moment: JourneyMoment) -> some View {
        switch moment {
        case .milestone(let item): MilestoneCard(milestone: item)
        case .checkIn(let item):
            Button { selectedEntry = item } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text(item.day.formatted(.dateTime.day().month(.abbreviated)).uppercased()).font(.caption2.weight(.medium)).tracking(1); if item.isSample { Text("· SAMPLE").font(.caption2.weight(.medium)) }; Spacer(); Image(systemName: item.mood.symbol) }.foregroundStyle(Theme.secondaryInk)
                    Text(item.mood.title).font(.headline)
                    if !item.note.isEmpty { Text(item.note).font(.subheadline).foregroundStyle(Theme.secondaryInk).multilineTextAlignment(.leading) }
                    HStack(spacing: 8) { ForEach(Routine.allCases.filter { item.routines.contains($0) }) { routine in Image(systemName: routine.symbol).font(.caption).foregroundStyle(Theme.accent).frame(width: 27, height: 27).background(Theme.softAccent, in: Circle()).accessibilityLabel(routine.shortTitle) }; Spacer(); Text("Check-in").font(.caption2).foregroundStyle(Theme.secondaryInk) }
                }.frame(maxWidth: .infinity, alignment: .leading).card(padding: 18)
            }.buttonStyle(.plain)
        case .weight(let item):
            HStack { Image(systemName: "chart.xyaxis.line").foregroundStyle(Theme.accent); VStack(alignment: .leading, spacing: 6) { Text("\(store.journal.weightUnit.display(item.kilograms).formatted(.number.precision(.fractionLength(1)))) \(store.journal.weightUnit.rawValue)").font(.headline); Text(item.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(Theme.secondaryInk) }; Spacer(); Text(item.isSample ? "Sample" : "Recorded").font(.caption).foregroundStyle(Theme.secondaryInk) }.card(padding: 18)
        }
    }
}

struct WeightChartCard: View {
    @Environment(JournalStore.self) private var store
    private var entries: [WeightEntry] { store.journal.weights.sorted { $0.date < $1.date } }
    private var domain: ClosedRange<Double> {
        let values = entries.map { store.journal.weightUnit.display($0.kilograms) }
        return ((values.min() ?? 0) - 1)...((values.max() ?? 0) + 1)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack { Text("Weight, in perspective").font(.headline); Spacer(); Text(store.journal.weightUnit.rawValue).font(.caption).foregroundStyle(Theme.secondaryInk) }
            if entries.isEmpty { Text("No weight records yet. Add one from +, or hide this card in You.").font(.subheadline).foregroundStyle(Theme.secondaryInk) }
            else {
                Chart(entries) { entry in
                    LineMark(x: .value("Date", entry.date), y: .value("Weight", store.journal.weightUnit.display(entry.kilograms)), series: .value("Record type", entry.isSample ? "Sample" : "Your records"))
                        .foregroundStyle(by: .value("Record type", entry.isSample ? "Sample" : "Your records")).lineStyle(StrokeStyle(lineWidth: 2.5, dash: entry.isSample ? [4, 3] : []))
                    PointMark(x: .value("Date", entry.date), y: .value("Weight", store.journal.weightUnit.display(entry.kilograms)))
                        .foregroundStyle(by: .value("Record type", entry.isSample ? "Sample" : "Your records")).symbolSize(35)
                }.chartForegroundStyleScale(["Sample": Color.secondary, "Your records": Theme.accent])
                    .chartYScale(domain: domain).frame(height: 190)
                    .accessibilityLabel("Weight records, \(entries.count) entries. Latest \(store.journal.weightUnit.display(entries.last!.kilograms).formatted(.number.precision(.fractionLength(1)))) \(store.journal.weightUnit.rawValue). Individual records are listed in the timeline.")
            }
            if entries.contains(where: \.isSample) { Text("Dashed records are fictional examples, kept separate from your own records.").font(.caption).foregroundStyle(Theme.secondaryInk) }
            Text("One part of your story. No targets, forecasts or rewards tied to this number.").font(.caption).foregroundStyle(Theme.secondaryInk)
        }.card()
    }
}
