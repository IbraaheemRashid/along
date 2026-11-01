import SwiftUI
import Charts

private enum JourneyMoment: Identifiable {
    case checkIn(CheckIn), milestone(Milestone), weight(WeightEntry), routines(RoutineDay)
    var id: UUID { switch self { case .checkIn(let item): item.id; case .milestone(let item): item.id; case .weight(let item): item.id; case .routines(let item): item.id } }
    var date: Date { switch self { case .checkIn(let item): item.day; case .milestone(let item): item.date; case .weight(let item): item.date; case .routines(let item): item.day } }
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
    @State private var selectedMilestone: Milestone?
    @State private var selectedWeight: WeightEntry?
    @State private var selectedRoutines: RoutineDay?
    @State private var search = ""
    @FocusState private var searchFocused: Bool
    @State private var pendingDelete: JourneyMoment?
    private var moments: [JourneyMoment] {
        var items = store.journal.milestones.map(JourneyMoment.milestone)
        if filter == 0 {
            items += store.journal.checkIns.map(JourneyMoment.checkIn)
            items += (store.journal.routineDays ?? []).filter { !$0.routines.isEmpty }.map(JourneyMoment.routines)
            if store.journal.showWeight { items += store.journal.weights.map(JourneyMoment.weight) }
        }
        return items.filter { moment in
            guard !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
            let text: String
            switch moment {
            case .checkIn(let value): text = value.note + " " + value.mood.title + " " + value.appetite.title
            case .milestone(let value): text = value.title + " " + value.note
            case .weight(let value): text = "Weight " + String(value.kilograms)
            case .routines(let value): text = value.routines.map { store.routineTitle($0) }.joined(separator: " ")
            }
            return text.localizedCaseInsensitiveContains(search)
        }.sorted { $0.date > $1.date }
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
                        stat("\(Set(store.journal.checkIns.map { Calendar.current.startOfDay(for: $0.day) } + (store.journal.routineDays ?? []).filter { !$0.routines.isEmpty }.map { Calendar.current.startOfDay(for: $0.day) }).count)", label: "days recorded", symbol: "book")
                        stat("\(store.journal.milestones.count)", label: "moments kept", symbol: "sparkles")
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        HStack { Text("Your last seven days").font(.headline); Spacer(); Image(systemName: "calendar").foregroundStyle(Theme.accent) }
                        HStack(spacing: 0) {
                            ForEach((-6...0), id: \.self) { offset in
                                let date = Calendar.current.date(byAdding: .day, value: offset, to: Date.now)!
                                let record = store.journal.checkIns.first { Calendar.current.isDate($0.day, inSameDayAs: date) }
                                let hasRoutine = !store.journal.recordedRoutines(on: date).isEmpty
                                VStack(spacing: 9) {
                                    Text(date.formatted(.dateTime.weekday(.narrow))).font(.caption).foregroundStyle(Theme.secondaryInk)
                                    ZStack { Circle().fill(record == nil && !hasRoutine ? Theme.paper : Theme.softApricot); if let record { Image(systemName: record.mood.symbol).font(.system(size: 14)).foregroundStyle(Theme.accent) } else if hasRoutine { Image(systemName: "checkmark").font(.caption).foregroundStyle(Theme.accent) } else { Circle().fill(.secondary.opacity(0.3)).frame(width: 4, height: 4) } }.frame(width: 33, height: 33)
                                    Text(date.formatted(.dateTime.day())).font(.caption2).foregroundStyle(Theme.secondaryInk)
                                }.frame(maxWidth: .infinity).accessibilityElement(children: .ignore).accessibilityLabel("\(date.formatted(date: .abbreviated, time: .omitted)): \(record?.mood.title ?? (hasRoutine ? "Routines recorded" : "No entry"))")
                            }
                        }
                        Text("A record, not a streak. Blank days are simply unrecorded.").font(.caption).foregroundStyle(Theme.secondaryInk)
                    }.card()
                    if store.journal.showWeight { WeightChartCard() }
                    Button { showRecap = true } label: {
                        HStack { Label("Read your weekly reflection", systemImage: "text.book.closed").font(.subheadline.weight(.semibold)); Spacer(); Image(systemName: "arrow.right") }.padding(18).background(Theme.softAccent, in: RoundedRectangle(cornerRadius: 18))
                    }.buttonStyle(.plain)
                    TextField("Find a note or milestone", text: $search).alongField().focused($searchFocused).submitLabel(.search).onSubmit { searchFocused = false }.accessibilityIdentifier("journey.search")
                    Picker("Journey view", selection: $filter) { Text("All moments").tag(0); Text("Milestones").tag(1) }.pickerStyle(.segmented)
                    if moments.isEmpty {
                        QuietEmpty(symbol: "book.pages", title: filter == 1 ? "Keep something that mattered" : "Your story starts here", detail: "Use the + button to save a check-in or a personal milestone. There’s no schedule to keep up with.")
                    } else {
                        LazyVStack(spacing: 17) {
                            ForEach(moments) { moment in
                                HStack(alignment: .top, spacing: 13) {
                                    VStack(spacing: 5) { Circle().fill(isMilestone(moment) ? Theme.gold : Theme.lilac).frame(width: 11, height: 11).padding(.top, 25); Rectangle().fill(Theme.line).frame(width: 1) }.frame(width: 11)
                                    VStack(alignment: .trailing, spacing: 0) {
                                        momentView(moment)
                                        Menu {
                                            Button("Edit entry", systemImage: "pencil") { edit(moment) }
                                            Button("Delete entry", systemImage: "trash", role: .destructive) { pendingDelete = moment }
                                        } label: { Label("Options", systemImage: "ellipsis").font(.caption).frame(minHeight: 44) }
                                        .accessibilityLabel("Options for entry on \(moment.date.formatted(date: .abbreviated, time: .omitted))")
                                    }
                                }
                            }
                        }
                    }
                    Text("Tap an entry to edit it. Use Options to remove a record.").font(.caption).foregroundStyle(Theme.secondaryInk).padding(.bottom, 16)
                }.padding(22).frame(maxWidth: 650)
            }.frame(maxWidth: .infinity).pageBackground().scrollDismissesKeyboard(.interactively).navigationTitle("Your journey").navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showMilestone) { AddMilestoneView() }
                .sheet(isPresented: $showWeight) { AddWeightView() }
                .sheet(isPresented: $showNewCheckIn) { CheckInView(entry: store.today) }
                .sheet(item: $selectedEntry) { CheckInView(entry: $0) }
                .sheet(item: $selectedMilestone) { AddMilestoneView(entry: $0) }
                .sheet(item: $selectedWeight) { AddWeightView(entry: $0) }
                .sheet(item: $selectedRoutines) { RoutineRecordView(entry: $0) }
                .sheet(isPresented: $showRecap) { WeeklyRecapView() }
                .confirmationDialog("Delete this entry?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
                    Button("Delete entry", role: .destructive) {
                        if let pendingDelete { switch pendingDelete { case .checkIn(let item): store.removeCheckIn(item.id); case .milestone(let item): store.removeMilestone(item.id); case .weight(let item): store.removeWeight(item.id); case .routines(let item): store.removeRoutineDay(item.id) } }; pendingDelete = nil
                    }
                } message: { Text("This removes the entry from this device. It can’t be undone.") }
        }
    }
    private func edit(_ moment: JourneyMoment) {
        switch moment { case .checkIn(let item): selectedEntry = item; case .milestone(let item): selectedMilestone = item; case .weight(let item): selectedWeight = item; case .routines(let item): selectedRoutines = item }
    }
    private func isMilestone(_ moment: JourneyMoment) -> Bool { if case .milestone = moment { true } else { false } }
    private func stat(_ value: String, label: String, symbol: String) -> some View {
        HStack(spacing: 12) { AlongIcon(symbol: symbol, apricot: true); VStack(alignment: .leading, spacing: 4) { Text(value).font(.system(size: 28, weight: .medium, design: .serif)).accessibilityIdentifier(label == "days recorded" ? "journey.daysRecorded" : "journey.momentsKept"); Text(label).font(.caption).foregroundStyle(Theme.secondaryInk) }; Spacer(minLength: 0) }.frame(maxWidth: .infinity, alignment: .leading).card(padding: 17)
    }
    @ViewBuilder private func momentView(_ moment: JourneyMoment) -> some View {
        switch moment {
        case .milestone(let item): Button { selectedMilestone = item } label: { MilestoneCard(milestone: item) }.buttonStyle(.plain)
        case .checkIn(let item):
            Button { selectedEntry = item } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text(item.day.formatted(.dateTime.day().month(.abbreviated)).uppercased()).font(.caption2.weight(.medium)).tracking(1); if item.isSample { Text("· SAMPLE").font(.caption2.weight(.medium)) }; Spacer(); Image(systemName: item.mood.symbol) }.foregroundStyle(Theme.secondaryInk)
                    Text(item.mood.title).font(.headline)
                    if !item.note.isEmpty { Text(item.note).font(.subheadline).foregroundStyle(Theme.secondaryInk).multilineTextAlignment(.leading) }
                    HStack(spacing: 8) { ForEach(Routine.allCases.filter { item.routines.contains($0) }) { routine in Image(systemName: routine.symbol).font(.caption).foregroundStyle(Theme.accent).frame(width: 27, height: 27).background(Theme.softAccent, in: Circle()).accessibilityLabel(routine.shortTitle) }; Spacer(); Text("Check-in").font(.caption2).foregroundStyle(Theme.secondaryInk) }
                }.frame(maxWidth: .infinity, alignment: .leading).card(padding: 18)
            }.buttonStyle(.plain)
        case .routines(let item):
            Button { selectedRoutines = item } label: {
                VStack(alignment: .leading, spacing: 10) {
                    Text(item.day.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(Theme.secondaryInk)
                    Text("Room for little things").font(.headline)
                    ForEach(Routine.allCases.filter { item.routines.contains($0) }) { routine in
                        Label(store.routineTitle(routine), systemImage: routine.symbol).font(.subheadline).foregroundStyle(Theme.accent)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).card(padding: 18)
            }.buttonStyle(.plain).accessibilityIdentifier("journey.routineRecord")
        case .weight(let item):
            Button { selectedWeight = item } label: { HStack { Image(systemName: "chart.xyaxis.line").foregroundStyle(Theme.accent); VStack(alignment: .leading, spacing: 6) { Text("\(store.journal.weightUnit.display(item.kilograms).formatted(.number.precision(.fractionLength(1)))) \(store.journal.weightUnit.rawValue)").font(.headline); Text(item.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(Theme.secondaryInk) }; Spacer(); Text(item.isSample ? "Sample" : "Recorded").font(.caption).foregroundStyle(Theme.secondaryInk) }.card(padding: 18) }.buttonStyle(.plain).accessibilityIdentifier("journey.weightRecord")
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
