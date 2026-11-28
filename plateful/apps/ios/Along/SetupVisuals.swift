import SwiftUI

/// Welcome hero: a phone showing today's protocol, with doses being logged.
struct SetupPhoneDemo: View {
    var reduceMotion: Bool
    @State private var logged = 0
    private let doses: [(String, String, String)] = [
        ("BPC-157", "250 mcg · Morning", "8:00"),
        ("Tirzepatide", "2.5 mg · Weekly", "9:00"),
        ("GHK-Cu", "1 mg · Evening", "20:00"),
    ]
    private let design = CGSize(width: 270, height: 540)

    var body: some View {
        GeometryReader { proxy in
            let scale = min(1, proxy.size.height / design.height, proxy.size.width / design.width)
            phone
                .frame(width: design.width, height: design.height)
                .scaleEffect(scale)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityElement()
        .accessibilityLabel("Along showing today’s peptide doses being logged")
        .task {
            guard !reduceMotion else { logged = 2; return }
            while !Task.isCancelled {
                for count in 0...doses.count {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { logged = count }
                    try? await Task.sleep(for: .seconds(count == doses.count ? 2.4 : 1.3))
                }
            }
        }
    }

    private var phone: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 46, style: .continuous).fill(Color(white: 0.08))
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("9:41").font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Image(systemName: "battery.75").font(.system(size: 12))
                }.foregroundStyle(Color.black).padding(.horizontal, 22).padding(.top, 16)
                Text("Today").font(.system(size: 26, weight: .bold)).foregroundStyle(.black).padding(.horizontal, 20).padding(.top, 18)
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide))).font(.system(size: 12)).foregroundStyle(Color(white: 0.5)).padding(.horizontal, 20)
                ring.padding(.top, 18).frame(maxWidth: .infinity)
                VStack(spacing: 8) {
                    ForEach(Array(doses.enumerated()), id: \.offset) { index, dose in row(dose, done: index < logged) }
                }.padding(.horizontal, 14).padding(.top, 18)
                trend.padding(.horizontal, 14).padding(.top, 10)
                Spacer(minLength: 0)
            }
            .background(Color.white, in: RoundedRectangle(cornerRadius: 38, style: .continuous))
            .padding(8)
            Capsule().fill(Color(white: 0.08)).frame(width: 84, height: 24).padding(.top, 16)
        }
        .environment(\.colorScheme, .light)
    }

    private var trend: some View {
        HStack(alignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Weight").font(.system(size: 10, weight: .medium)).foregroundStyle(Color(white: 0.5))
                Text("84.2 kg").font(.system(size: 17, weight: .bold)).foregroundStyle(.black)
                Text("↓ 4.2 kg in 6 weeks").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(red: 0.13, green: 0.6, blue: 0.33))
            }
            Spacer(minLength: 0)
            Path { path in
                let points: [CGFloat] = [0.1, 0.18, 0.15, 0.32, 0.4, 0.38, 0.55, 0.62, 0.7, 0.86]
                for (index, value) in points.enumerated() {
                    let point = CGPoint(x: CGFloat(index) / CGFloat(points.count - 1) * 96, y: value * 40)
                    if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
            }
            .stroke(Color.black, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .frame(width: 96, height: 40)
        }
        .padding(12)
        .background(Color(white: 0.96), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var ring: some View {
        ZStack {
            Circle().stroke(Color(white: 0.93), lineWidth: 12)
            Circle().trim(from: 0, to: CGFloat(logged) / CGFloat(doses.count))
                .stroke(Color.black, style: StrokeStyle(lineWidth: 12, lineCap: .round)).rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(logged)/\(doses.count)").font(.system(size: 26, weight: .bold)).foregroundStyle(.black).contentTransition(.numericText())
                Text("doses").font(.system(size: 11)).foregroundStyle(Color(white: 0.5))
            }
        }.frame(width: 118, height: 118)
    }

    private func row(_ dose: (String, String, String), done: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "syringe").font(.system(size: 13, weight: .medium)).foregroundStyle(.black)
                .frame(width: 32, height: 32).background(Color(white: 0.95), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(dose.0).font(.system(size: 13, weight: .semibold)).foregroundStyle(.black)
                Text(dose.1).font(.system(size: 10)).foregroundStyle(Color(white: 0.5))
            }
            Spacer()
            ZStack {
                Circle().strokeBorder(Color(white: 0.85), lineWidth: 1.5)
                if done { Circle().fill(Color.black); Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white).transition(.scale) }
            }.frame(width: 24, height: 24)
        }
        .padding(.horizontal, 10).frame(height: 52)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color(white: done ? 0.1 : 0.9), lineWidth: done ? 1.5 : 1))
    }
}

/// Seven-day strip with doses checking off in sequence.
struct SetupWeekCard: View {
    var pattern: [Bool]
    var animated: Bool
    var title = "This week"
    var footnote: String? = "Next dose · Tomorrow, 8:00 AM"
    var planned = false
    @State private var revealed = 0
    private let days = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        SetupCard {
            HStack {
                Text(title).font(.headline).foregroundStyle(SetupTheme.ink)
                Spacer()
                let count = pattern.filter { $0 }.count
                Text(planned ? "\(count) dose \(count == 1 ? "day" : "days")" : "\(min(revealed, count)) of \(count) logged")
                    .font(.footnote.weight(.medium)).foregroundStyle(SetupTheme.muted).contentTransition(.numericText())
            }
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { index in
                    VStack(spacing: 10) {
                        Text(days[index]).font(.caption.weight(.medium)).foregroundStyle(SetupTheme.muted)
                        dot(index)
                    }.frame(maxWidth: .infinity)
                }
            }.padding(.top, 18)
            if let footnote {
                Divider().padding(.vertical, 16)
                Label(footnote, systemImage: "bell").font(.subheadline).foregroundStyle(SetupTheme.ink)
            }
        }
        .accessibilityElement(children: .combine)
        .task {
            let total = pattern.filter { $0 }.count
            guard animated else { revealed = total; return }
            revealed = 0
            try? await Task.sleep(for: .seconds(0.4))
            for count in 1...max(1, total) {
                try? await Task.sleep(for: .seconds(0.28))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { revealed = count }
            }
        }
    }

    @ViewBuilder private func dot(_ index: Int) -> some View {
        let order = pattern.prefix(index + 1).filter { $0 }.count
        let done = pattern[index] && order <= revealed
        ZStack {
            if pattern[index] {
                Circle().strokeBorder(done || planned ? SetupTheme.ink : SetupTheme.border, lineWidth: 1.5)
                if planned {
                    Image(systemName: "syringe.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(SetupTheme.ink)
                } else if done {
                    Circle().fill(SetupTheme.ink)
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(SetupTheme.inverseInk).transition(.scale)
                }
            } else {
                Circle().fill(SetupTheme.border).frame(width: 6, height: 6)
            }
        }.frame(width: 32, height: 32)
    }
}

struct SetupRingArtwork: View {
    var symbol: String
    @State private var appeared = false
    var body: some View {
        ZStack {
            Circle().stroke(AngularGradient(colors: [Color(red: 0.96, green: 0.84, blue: 0.88), Color(red: 0.84, green: 0.88, blue: 0.97), Color(red: 0.93, green: 0.90, blue: 0.97), Color(red: 0.96, green: 0.84, blue: 0.88)], center: .center), lineWidth: 26)
            Circle().fill(SetupTheme.surface).padding(13)
            Image(systemName: symbol).font(.system(size: 64, weight: .thin)).foregroundStyle(SetupTheme.ink)
                .scaleEffect(appeared ? 1 : 0.7).opacity(appeared ? 1 : 0)
        }
        .frame(width: 190, height: 190)
        .accessibilityHidden(true)
        .onAppear { withAnimation(.spring(response: 0.55, dampingFraction: 0.65).delay(0.1)) { appeared = true } }
    }
}

/// A stand-in for the system prompt so people know what to expect before iOS asks.
struct SetupNotificationMock: View {
    var allow: () -> Void
    var disabled: Bool
    @State private var bob = false
    var body: some View {
        VStack(spacing: 0) {
            Text("“Along” Would Like to Send You Notifications").font(.system(.headline)).multilineTextAlignment(.center)
                .foregroundStyle(SetupTheme.ink).padding(.horizontal, 20).padding(.top, 20)
            Text("Dose reminders, at the times you choose.").font(.footnote).foregroundStyle(SetupTheme.muted)
                .multilineTextAlignment(.center).padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 18)
            HStack(spacing: 10) {
                Text("Don’t Allow").font(.body).foregroundStyle(SetupTheme.muted).frame(maxWidth: .infinity, minHeight: 46)
                    .background(SetupTheme.surface.opacity(0.6), in: Capsule())
                    .accessibilityHidden(true)
                Button(action: allow) {
                    Text("Allow").font(.body.weight(.semibold)).foregroundStyle(SetupTheme.inverseInk).frame(maxWidth: .infinity, minHeight: 46)
                        .background(SetupTheme.ink, in: Capsule())
                }.buttonStyle(SetupPressStyle()).disabled(disabled).accessibilityIdentifier("setup.reminders.allow")
            }.padding(.horizontal, 14).padding(.bottom, 14)
        }
        .background(SetupTheme.tile, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .frame(maxWidth: 320)
        .overlay(alignment: .bottomTrailing) {
            Text("👆").font(.system(size: 40)).offset(x: -52, y: bob ? 52 : 44).accessibilityHidden(true)
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { bob = true } }
    }
}

/// Short build step that plays back the person's own answers before the reveal.
struct SetupBuildingView: View {
    var draft: SetupDraft
    var reduceMotion: Bool
    var finished: () -> Void
    @State private var progress = 0.0
    @State private var didFinish = false

    private var items: [(String, String)] {
        [("Your goals", draft.goals.isEmpty ? "Ready" : SetupGoal.allCases.filter(draft.goals.contains).map(\.title).joined(separator: ", ")),
         ("Your peptides", draft.compounds.isEmpty ? "Add any time" : draft.compounds.joined(separator: ", ")),
         ("Weekly schedule", draft.frequency?.title ?? "Flexible"),
         ("Reminders", draft.reminderSummary),
         ("Progress tracking", draft.tracksWeightGoal ? "Goal \(draft.formattedWeight(draft.targetKg))" : "Every dose, from day one")]
    }
    private var status: String {
        switch progress {
        case ..<0.2: "Applying your goals…"
        case ..<0.4: "Adding your peptides…"
        case ..<0.6: "Setting your schedule…"
        case ..<0.8: "Saving reminder preferences…"
        default: "Finalising your protocol…"
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("\(Int(progress * 100))%").font(.system(size: 64, weight: .bold)).monospacedDigit().foregroundStyle(SetupTheme.ink)
                .contentTransition(.numericText())
            Text("We’re setting everything up for you").setupTitleFont().multilineTextAlignment(.center).foregroundStyle(SetupTheme.ink)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(SetupTheme.tile)
                    Capsule().fill(SetupTheme.loader).frame(width: max(8, proxy.size.width * progress))
                }
            }.frame(height: 8).padding(.top, 6)
            Text(status).font(.subheadline).foregroundStyle(SetupTheme.ink)
            VStack(alignment: .leading, spacing: 14) {
                Text("Your protocol includes").font(.subheadline.weight(.semibold)).foregroundStyle(SetupTheme.ink)
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    let done = progress >= Double(index + 1) / Double(items.count) - 0.001
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("•").foregroundStyle(SetupTheme.muted)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.0).font(.subheadline).foregroundStyle(SetupTheme.ink)
                            if done { Text(item.1).font(.caption).foregroundStyle(SetupTheme.muted).lineLimit(1).transition(.opacity) }
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).foregroundStyle(SetupTheme.ink)
                            .opacity(done ? 1 : 0).scaleEffect(done ? 1 : 0.5)
                    }
                }
            }
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(SetupTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(SetupTheme.border))
            .padding(.top, 10)
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 560).frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("setup.building")
        .task {
            let steps = reduceMotion ? 10 : 50
            let pause = reduceMotion ? 0.12 : 0.075
            for index in 1...steps {
                try? await Task.sleep(for: .seconds(pause))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: pause)) { progress = Double(index) / Double(steps) }
            }
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled, !didFinish else { return }
            didFinish = true
            finished()
        }
    }
}

/// The payoff: the person's own answers arranged as a protocol.
struct SetupPlanView: View {
    var draft: SetupDraft
    var editSchedule: () -> Void

    var body: some View {
        SetupScrollPage {
            VStack(spacing: 14) {
                Image(systemName: "checkmark").font(.system(size: 20, weight: .bold)).foregroundStyle(SetupTheme.inverseInk)
                    .frame(width: 44, height: 44).background(SetupTheme.ink, in: Circle())
                Text(headline).setupTitleFont().multilineTextAlignment(.center).foregroundStyle(SetupTheme.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(summary).font(.subheadline).foregroundStyle(SetupTheme.muted).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity).padding(.top, 8)

            SetupCard {
                Text("Your protocol").font(.headline).foregroundStyle(SetupTheme.ink)
                if draft.compounds.isEmpty {
                    Text("Add your first peptide and its schedule in Your peptides whenever you’re ready.")
                        .font(.subheadline).foregroundStyle(SetupTheme.muted).padding(.top, 8)
                } else {
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        let peptides = draft.initialPeptides(startKey: DayIdentity.key(for: context.date) ?? "")
                        VStack(spacing: 0) {
                            ForEach(Array(peptides.enumerated()), id: \.element.name) { index, peptide in
                                let name = peptide.name
                                if index > 0 { Divider() }
                                HStack(spacing: 12) {
                                    Image(systemName: "syringe").font(.system(size: 14, weight: .medium)).foregroundStyle(SetupTheme.ink)
                                        .frame(width: 34, height: 34).background(SetupTheme.surface, in: Circle())
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(name).font(.subheadline.weight(.semibold)).foregroundStyle(SetupTheme.ink)
                                        let schedule = draft.schedule(for: name)
                                        Text(schedule.kind == .unscheduled ? "Set schedule in Your peptides" : "\(schedule.summary) · \(schedule.timesSummary)").font(.caption).foregroundStyle(SetupTheme.muted)
                                        if let last = draft.lastInjections[name] {
                                            Text("Last logged: \(DayIdentity.formatted(key: last.dayKey, rawDate: last.takenAt)) · \(last.takenAt.formatted(date: .omitted, time: .shortened))")
                                                .font(.subheadline)
                                                .accessibilityIdentifier("setup.last-logged.\(name)")
                                        }
                                        let logs = draft.lastInjections[name].map { [$0.log(for: peptide)] } ?? []
                                        if schedule.kind != .unscheduled,
                                           let next = ProtocolSchedule.nextDose(after: context.date, peptides: [peptide], logs: logs) {
                                            Text("Next scheduled: \(next.at.formatted(.dateTime.weekday().month().day().hour().minute()))")
                                                .font(.subheadline.weight(.semibold))
                                                .accessibilityIdentifier("setup.next.\(name)")
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }.padding(.vertical, 10)
                            }
                        }
                    }.padding(.top, 8)
                    Button("Edit schedule", action: editSchedule).font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("setup.edit-schedule")
                }
            }.padding(.top, 24)

            if draft.hasScheduledPeptides {
                SetupWeekCard(pattern: weekPattern, animated: false, title: "Your week",
                              footnote: draft.reminderSummary, planned: true)
                    .padding(.top, 12)
            }

            if draft.tracksWeightGoal {
                SetupCard {
                    HStack {
                        Text("Weight goal").font(.headline).foregroundStyle(SetupTheme.ink)
                        Spacer()
                        Text(draft.targetDirection).font(.footnote.weight(.medium)).foregroundStyle(SetupTheme.muted)
                    }
                    SetupGoalLine(start: draft.formattedWeight(draft.weightKg), end: draft.formattedWeight(draft.targetKg), descending: draft.targetChange < 0)
                        .frame(height: 110).padding(.top, 14)
                }.padding(.top, 12)
            }

            if !draft.obstacles.isEmpty {
                SetupCard {
                    Text("Built around what gets in your way").font(.headline).foregroundStyle(SetupTheme.ink)
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(SetupObstacle.allCases.filter(draft.obstacles.contains)) { obstacle in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(SetupTheme.ink)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(answer(for: obstacle)).font(.subheadline.weight(.medium)).foregroundStyle(SetupTheme.ink)
                                    Text(obstacle.title).font(.caption).foregroundStyle(SetupTheme.muted)
                                }
                            }
                        }
                    }.padding(.top, 12)
                }.padding(.top, 12)
            }

            Text("You can edit any of this later.").font(.footnote).foregroundStyle(SetupTheme.muted)
                .frame(maxWidth: .infinity).padding(.top, 16)
        }
        .accessibilityIdentifier("setup.plan")
    }

    private var headline: String {
        draft.compounds.isEmpty || draft.compounds.contains { draft.schedule(for: $0).kind == .unscheduled }
            ? "Your protocol so far" : "Your protocol is ready"
    }

    private var weekPattern: [Bool] {
        let schedules = draft.compounds.map { draft.schedule(for: $0) }
        return [2, 3, 4, 5, 6, 7, 1].map { day in
            schedules.contains { $0.kind == .daily || $0.weekdays.contains(day) }
        }
    }

    private var summary: String {
        let peptides = draft.compounds.isEmpty ? "Add peptides any time" : draft.compounds.prefix(3).joined(separator: " + ") + (draft.compounds.count > 3 ? " + \(draft.compounds.count - 3) more" : "")
        return "\(peptides) · \(draft.frequency?.title ?? "Flexible schedule")"
    }

    private func answer(for obstacle: SetupObstacle) -> String {
        switch obstacle {
        case .forgetting: draft.remindersRequested == true ? draft.reminderSummary : "Reminders, whenever you turn them on"
        case .schedules: "Each peptide on its own schedule"
        case .tracking: "A one-tap log: peptide, amount and time"
        case .response: "A quick note with any dose"
        case .progress: draft.tracksWeightGoal ? "Your weight trend alongside every dose" : "A full history you can look back on"
        }
    }
}

struct SetupGoalLine: View {
    var start: String
    var end: String
    var descending: Bool
    @State private var drawn = false
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height - 22
            let top: CGFloat = 12, bottom = h - 10
            let a = CGPoint(x: 8, y: descending ? top : bottom), b = CGPoint(x: w - 8, y: descending ? bottom : top)
            let path = Path { p in
                p.move(to: a)
                p.addCurve(to: b, control1: CGPoint(x: w * 0.45, y: a.y), control2: CGPoint(x: w * 0.55, y: b.y))
            }
            ZStack(alignment: .topLeading) {
                Path { p in p.move(to: CGPoint(x: 0, y: h)); p.addLine(to: CGPoint(x: w, y: h)) }.stroke(SetupTheme.border, lineWidth: 1)
                path.trim(from: 0, to: drawn ? 1 : 0).stroke(SetupTheme.ink, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                Circle().strokeBorder(SetupTheme.ink, lineWidth: 2).background(Circle().fill(SetupTheme.surface)).frame(width: 12, height: 12).position(a)
                Circle().fill(SetupTheme.highlight).frame(width: 14, height: 14).position(b).opacity(drawn ? 1 : 0)
                Text(start).font(.caption.weight(.medium)).foregroundStyle(SetupTheme.muted).position(x: 40, y: h + 13)
                Text(end).font(.caption.weight(.semibold)).foregroundStyle(SetupTheme.ink).position(x: w - 40, y: h + 13)
            }
        }
        .accessibilityElement().accessibilityLabel("From \(start) to \(end)")
        .onAppear { withAnimation(.easeInOut(duration: 1.1).delay(0.2)) { drawn = true } }
    }
}
