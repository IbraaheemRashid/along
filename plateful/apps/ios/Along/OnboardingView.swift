import SwiftUI

struct OnboardingView: View {
    @Environment(JournalStore.self) private var store
    @Environment(BillingStore.self) private var billing
    @Environment(\.alongReducedMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicType
    @State private var showBackup = false
    @State private var showLocalData = false
    @State private var showPreviewConfirmation = false
    @State private var preparedReview = false
    @FocusState private var inputFocused: Bool
    private var draft: OnboardingDraft { store.onboardingDraft }
    private var step: Int { draft.step }
    private var companion: String { draft.displayCompanionName }
    private var chapter: Int { step < 12 ? 0 : step < 18 ? 1 : step < 20 ? 2 : 3 }
    private let chapterNames = ["YOUR JOURNEY", "YOUR ROUTINE", "YOUR COMPANION", "YOUR SPACE"]
    static let titles = [
        "Your journey.\nA little company.", "First, what should\nwe call you?", "Where are you\nin your journey?", "Every story has\na beginning.",
        "What brings\nyou here?", "What gets\nin the way?", "The little things\ntell a bigger story.", "What would you\nlike to notice?",
        "Keep your why\nclose by.", "Your journal.\nYour kind of progress.", "A starting point,\nif you’d like one.", "There’s room for\nall of your progress.",
        "Make room for\na little routine.", "Make it\nyour own.", "Find a rhythm\nthat fits real life.", "A moment that\nworks for you.",
        "A little time\nto look back.", "Your kind of\nencouragement.", "A little more\npersonality.", "A name for your\nlittle companion.",
        "Let’s begin\nwith today.", "One small moment.\nWorth remembering.", "Your first page.\nAlready yours.", "A space that\nfeels like you.",
        "One membership.\nYour whole journey.", "Your next\nchapter."
    ]
    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Color.clear.frame(height: 1).id("top")
                        screenContent
                    }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 24)
                        .frame(maxWidth: 560, alignment: .leading).frame(maxWidth: .infinity)
                }.scrollDismissesKeyboard(.interactively)
                    .onChange(of: step) { inputFocused = false; proxy.scrollTo("top", anchor: .top) }
            }
        }.pageBackground().safeAreaInset(edge: .bottom, spacing: 0) { footer }
            .onAppear { prepareScreenReview() }
            .sheet(isPresented: $showBackup) { JournalBackupView(journal: { store.journal }, replace: store.restoreJournal) }
            .sheet(isPresented: $showLocalData) { LocalDataView() }
            .alert("Open the local design preview?", isPresented: $showPreviewConfirmation) {
                Button("Open design preview") { _ = store.finishOnboardingPreview() }
                Button("Stay here", role: .cancel) {}
            } message: { Text("This developer preview does not purchase or activate a subscription. Your entries stay on this device.") }
    }
    private var header: some View {
        VStack(spacing: 16) {
            HStack {
                if step > 0 {
                    Button(action: back) { Image(systemName: "arrow.left").font(.system(size: 17, weight: .semibold)).frame(width: 44, height: 44).background(Theme.softAccent, in: Circle()).contentShape(Circle()) }
                        .accessibilityLabel("Back").accessibilityIdentifier("onboarding.back")
                } else { Text("along").font(.system(size: 28, weight: .semibold, design: .serif)).foregroundStyle(Theme.accent) }
                Spacer()
                Text("\(step + 1) / 26").font(.system(.caption, design: .rounded, weight: .medium)).monospacedDigit().foregroundStyle(Theme.accent).padding(.horizontal, 12).padding(.vertical, 8).background(Theme.softAccent, in: Capsule())
                    .accessibilityLabel("Screen \(step + 1) of 26").accessibilityIdentifier("onboarding.step.\(step + 1)")
                if step == 25 {
                    Button { store.onboardingDraft.step = 23 } label: { Image(systemName: "xmark").font(.system(size: 15, weight: .medium)).frame(width: 40, height: 40) }
                        .accessibilityLabel("Close membership offer").accessibilityIdentifier("onboarding.close")
                }
            }
            HStack(spacing: 5) { ForEach(0..<4) { index in Capsule().fill(index <= chapter ? Theme.accent : Theme.softAccent).frame(height: 5) } }.accessibilityHidden(true)
        }.padding(.horizontal, 24).padding(.top, 7).padding(.bottom, 8).frame(maxWidth: 560).frame(maxWidth: .infinity)
    }
    @ViewBuilder private var screenContent: some View {
        switch step {
        case 0: welcome
        case 1: nameScreen
        case 2: stageScreen
        case 3: startDateScreen
        case 4: priorityScreen
        case 5: obstacleScreen
        case 6: storyScreen
        case 7: progressScreen
        case 8: intentionScreen
        case 9: weightPreferenceScreen
        case 10: weightScreen
        case 11: progressPreview
        case 12: routinesScreen
        case 13: routineNamesScreen
        case 14: frequencyScreen
        case 15: reminderScreen
        case 16: reflectionDayScreen
        case 17: encouragementScreen
        case 18: accessoryScreen
        case 19: companionNameScreen
        case 20: checkInScreen
        case 21: noteScreen
        case 22: firstEntryScreen
        case 23: personalSpaceScreen
        case 24: membershipScreen
        default: paywallScreen
        }
    }
    private func heading(_ detail: String? = nil, eyebrow: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(eyebrow ?? chapterNames[chapter]).font(.system(.caption2, design: .rounded, weight: .bold))
                .tracking(1.5).foregroundStyle(Theme.accent)
                .padding(.horizontal, 11).padding(.vertical, 7).background(Theme.softApricot, in: Capsule())
            Text(Self.titles[step]).alongTitle(31).lineSpacing(1).fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
            if let detail {
                HStack(alignment: .top, spacing: 12) {
                    if ![0, 18, 19, 22, 24].contains(step) {
                        PipArtwork(pose: .welcome, accessory: draft.accessory).frame(width: 45, height: 55)
                    }
                    Text(detail).font(.subheadline).foregroundStyle(Theme.secondaryInk).lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                }.padding(15).background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
            }
        }
    }
    private var welcome: some View {
        VStack(alignment: .leading, spacing: 20) {
            PipPlayground(name: "Pip", accessory: .leaf, message: "Hi, I’m Pip.", height: 230)
            heading("A personal record of your GLP-1 journey. A little friend to help you notice the moments along the way.", eyebrow: "WELCOME TO ALONG")
            HStack(spacing: 18) { Label("Your progress", systemImage: "book.closed"); Label("Your pace", systemImage: "leaf") }.font(.caption.weight(.medium)).foregroundStyle(Theme.accent)
            Text("For adults · About 3–5 minutes to set up\nPaid membership required after setup. No free trial.").font(.caption).foregroundStyle(Theme.secondaryInk).lineSpacing(4)
            Button("Have a journal backup? Restore it") { showBackup = true }.font(.caption).frame(minHeight: 44)
            Button("Your data & reminders") { showLocalData = true }.font(.caption).frame(minHeight: 44)
        }
    }
    private var nameScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("Just a first name or nickname. This little space is yours.")
            input("Your name", placeholder: "e.g. Alex", value: binding(\.name, limit: 30), identifier: "onboarding.name")
            SetupHero(pose: .journal, height: 215)
        }
    }
    private var stageScreen: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("We’ll meet you where you are.").padding(.bottom, 10)
            choice("Preparing to start", detail: "Making a little space for what’s next", symbol: "sun.horizon", value: "Preparing", key: \.stage, id: "preparing")
            choice("I’ve recently started", detail: "Finding my feet in the first few weeks", symbol: "leaf", value: "Recently started", key: \.stage, id: "recent")
            choice("I’m finding my rhythm", detail: "Already a little way into my journey", symbol: "figure.walk", value: "Established routine", key: \.stage, id: "established")
            choice("I’m in maintenance", detail: "Keeping a record of this next chapter", symbol: "sun.max", value: "Maintenance", key: \.stage, id: "maintenance")
        }
    }
    private var startDateScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("If you’ve started treatment, when did your journey begin? An approximate date is fine.")
            Toggle("Add my start date", isOn: binding(\.hasStartDate)).font(.headline).padding(18).background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
            if draft.hasStartDate {
                DatePicker("Journey start date", selection: binding(\.startDate), in: ...Date.now, displayedComponents: .date).datePickerStyle(.graphical).padding(8).background(Theme.card, in: RoundedRectangle(cornerRadius: 20))
            } else { SetupHero(pose: .journal, height: 210) }
            SetupNote(text: "This simply adds context to your journal. You can leave it blank or change it later.", symbol: "calendar")
        }
    }
    private var priorityScreen: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("Choose what would feel most useful right now.").padding(.bottom, 10)
            choice("Notice my progress", detail: "Make the small changes easier to see", symbol: "sparkles", value: "Notice my progress", key: \.priority, id: "progress")
            choice("Keep a clear record", detail: "Give the days and details a place to live", symbol: "book.closed", value: "Keep a clear record", key: \.priority, id: "record")
            choice("Keep my routines going", detail: "Find a little consistency on my own terms", symbol: "leaf", value: "Keep my routines going", key: \.priority, id: "routines")
        }
    }
    private var obstacleScreen: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("Some days are easier to keep track of than others.").padding(.bottom, 10)
            choice("I forget the details", detail: "The weeks can blur together", symbol: "calendar", value: "Remembering details", key: \.obstacle, id: "remembering")
            choice("I don’t always notice change", detail: "There’s more happening than a number shows", symbol: "sparkle.magnifyingglass", value: "Noticing changes", key: \.obstacle, id: "noticing")
            choice("Tracking feels like a lot", detail: "I need something that fits into my day", symbol: "clock", value: "Finding time", key: \.obstacle, id: "time")
        }
    }
    private var storyScreen: some View {
        VStack(alignment: .leading, spacing: 23) {
            heading(draft.obstacle == "Finding time" ? "A short check-in can be enough. Along gives those little moments a place to add up." : "A note from today. A routine you made time for. A moment you might otherwise forget.")
            SetupHero(pose: .journal, height: 210)
            SetupBenefit(number: "01", title: "Notice a moment", detail: "A quick check-in, whenever it feels useful.")
            SetupBenefit(number: "02", title: "Keep the whole story", detail: "Revisit your days together in one personal journal.")
            SetupBenefit(number: "03", title: "Find a little perspective", detail: "Weekly reflections drawn from what you record.")
        }
    }
    private var progressScreen: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("Choose up to three things that matter to you. These will shape your reflection prompts.").padding(.bottom, 8)
            progressChoice("Everyday comfort", symbol: "sun.max", id: "comfort")
            progressChoice("Energy", symbol: "bolt.heart", id: "energy")
            progressChoice("Confidence", symbol: "sparkles", id: "confidence")
            progressChoice("Strength & function", symbol: "figure.strengthtraining.traditional", id: "strength")
            progressChoice("My routines", symbol: "leaf", id: "routines")
            Text("\(draft.progressAreas.count) of 3 selected").font(.caption).foregroundStyle(Theme.secondaryInk)
        }
    }
    private var intentionScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("What would you like to remember you’re doing this for?")
            multiline("Your intention", placeholder: "More energy for the things I love…", value: binding(\.intention, limit: 300), identifier: "onboarding.intention", limit: 300)
            SetupNote(text: "Your words will become the opening note of your journal. A few words is plenty.", symbol: "pencil.line")
        }
    }
    private var weightPreferenceScreen: some View {
        VStack(alignment: .leading, spacing: 15) {
            heading("Would you like a place for weight records? You can change this whenever you like.").padding(.bottom, 9)
            SetupChoice(title: "Include weight", detail: "An optional part of my personal history", symbol: "chart.xyaxis.line", selected: draft.showWeight, identifier: "onboarding.weight.show") { store.onboardingDraft.showWeight = true }
            SetupChoice(title: "Leave weight out", detail: "Focus on my days, routines and moments", symbol: "book.closed", selected: !draft.showWeight, identifier: "onboarding.weight.hide") { store.onboardingDraft.showWeight = false; store.onboardingDraft.weightValue = "" }
            SetupHero(pose: .journal, height: 170)
        }
    }
    private var weightScreen: some View {
        VStack(alignment: .leading, spacing: 26) {
            heading("Add a current weight if you want a first point in your history. It’s always optional.")
            Picker("Weight unit", selection: binding(\.weightUnit)) { Text("Kilograms").tag(WeightUnit.kg); Text("Pounds").tag(WeightUnit.lb) }.pickerStyle(.segmented)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                TextField("—", text: binding(\.weightValue, limit: 8)).font(.system(size: 58, weight: .medium, design: .serif)).keyboardType(.decimalPad).focused($inputFocused).accessibilityLabel("Current weight").accessibilityIdentifier("onboarding.weight.value")
                Text(draft.weightUnit.rawValue).font(.title3).foregroundStyle(Theme.secondaryInk)
            }.padding(28).background(Theme.card, in: RoundedRectangle(cornerRadius: 24))
            if !draft.weightValue.isEmpty && draft.baselineKilograms == nil { Text("Enter a valid positive weight, or skip for now.").font(.caption).foregroundStyle(Theme.accent) }
            SetupNote(text: "A record, without a target or deadline. Weight never changes your companion’s progress.", symbol: "heart")
        }
    }
    private var progressPreview: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("Here’s the kind of space you’re making for yourself.")
            SetupJournalCard(draft: draft)
            if draft.showWeight {
                HStack(spacing: 14) {
                    Image(systemName: "chart.xyaxis.line").font(.title2).foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Weight, in perspective").font(.headline)
                        Text(draft.baselineKilograms == nil ? "Add records whenever you choose." : "One starting point. More history comes with time.").font(.subheadline).foregroundStyle(Theme.secondaryInk)
                    }
                }.card()
            }
            SetupNote(text: "Your journal will reflect the days you record. There’s no score to chase.")
        }
    }
    private var routinesScreen: some View {
        VStack(alignment: .leading, spacing: 13) {
            heading("Pick up to two things you’d like to make space for. A check-in on its own is fine, too.").padding(.bottom, 8)
            ForEach(Routine.allCases) { routine in
                SetupChoice(title: routine.shortTitle, detail: routine.description, symbol: routine.symbol, selected: draft.routines.contains(routine), identifier: "onboarding.routine.\(routine.rawValue)") {
                    if draft.routines.contains(routine) { store.onboardingDraft.routines.remove(routine); store.onboardingDraft.routineNames.removeValue(forKey: routine.rawValue) }
                    else if draft.routines.count < 2 { store.onboardingDraft.routines.insert(routine) }
                }
            }
            Text("\(draft.routines.count) of 2 selected · optional").font(.caption).foregroundStyle(Theme.secondaryInk)
        }
    }
    private var routineNamesScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("Keep these words, or make them sound a little more like you.")
            if draft.routines.isEmpty {
                SetupHero(pose: .journal, height: 220)
                SetupNote(text: "Just a check-in for now. You can add a routine later in your settings.")
            } else {
                ForEach(Routine.allCases.filter { draft.routines.contains($0) }) { routine in
                    input(routine.shortTitle, placeholder: routine.title, value: Binding(get: { draft.routineNames[routine.rawValue] ?? routine.title }, set: { store.onboardingDraft.routineNames[routine.rawValue] = String($0.prefix(80)) }), identifier: "onboarding.routine.name.\(routine.rawValue)")
                }
                SetupNote(text: "Small and specific is a good place to begin. You can change these as life changes.")
            }
        }
    }
    private var frequencyScreen: some View {
        VStack(alignment: .leading, spacing: 13) {
            heading("How often would you like to make room for your routines?").padding(.bottom, 8)
            choice("Keep it flexible", detail: "Whenever it works for me", symbol: "leaf", value: "Flexible", key: \.frequency, id: "flexible")
            choice("A few days a week", detail: "A little rhythm, with room to breathe", symbol: "calendar", value: "A few days a week", key: \.frequency, id: "few")
            choice("A daily moment", detail: "Make it part of my everyday", symbol: "sun.max", value: "Daily", key: \.frequency, id: "daily")
            SetupNote(text: "Missed days are simply unrecorded days. Your progress stays with you.")
        }
    }
    private var reminderScreen: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("When would a gentle invitation to check in fit best?").padding(.bottom, 8)
            choice("Morning", detail: "A moment before the day gets going", symbol: "sun.horizon", value: "Morning", key: \.reminder, id: "morning")
            choice("Evening", detail: "A little space to look back on today", symbol: "moon", value: "Evening", key: \.reminder, id: "evening")
            choice("I’ll find my own moment", detail: "No reminder for now", symbol: "bell.slash", value: "Off", key: \.reminder, id: "off")
            Text("Your preference is saved. After setup, choose a time and turn reminders on in You. Nothing is scheduled yet.").font(.caption).foregroundStyle(Theme.secondaryInk)
        }
    }
    private var reflectionDayScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("Choose a day for a weekly look at the moments you’ve kept.")
            SetupHero(pose: .journal, height: 200)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: dynamicType.isAccessibilitySize ? 2 : 4), spacing: 10) {
                ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in
                    Button { store.onboardingDraft.reflectionDay = day } label: {
                        Text(Calendar.current.shortWeekdaySymbols[day - 1]).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).frame(minHeight: 58)
                            .background(draft.reflectionDay == day ? Theme.accent : Theme.card, in: RoundedRectangle(cornerRadius: 17)).foregroundStyle(draft.reflectionDay == day ? Theme.paper : Color.primary)
                    }.buttonStyle(.plain).accessibilityLabel(Calendar.current.weekdaySymbols[day - 1]).accessibilityAddTraits(draft.reflectionDay == day ? .isSelected : [])
                }
            }
            SetupNote(text: "Your chapter is a reflection of your entries, however many there are. You can read it any time.", symbol: "book.closed")
        }
    }
    private var encouragementScreen: some View {
        VStack(alignment: .leading, spacing: 13) {
            heading("How would you like \(companion) to sound?").padding(.bottom, 8)
            choice("Gentle", detail: "“A little space for today. That’s enough.”", symbol: "leaf", value: "Gentle", key: \.encouragement, id: "gentle")
            choice("Straightforward", detail: "“Today’s entry is saved. See you next time.”", symbol: "checkmark", value: "Straightforward", key: \.encouragement, id: "straightforward")
            choice("Celebratory", detail: "“Another little moment in your story!”", symbol: "sparkles", value: "Celebratory", key: \.encouragement, id: "celebratory")
        }
    }
    private var accessoryScreen: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Choose a first keepsake for \(companion). This one’s yours from the beginning.")
            SetupHero(accessory: draft.accessory, height: 240)
            let layout = dynamicType.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
            layout {
                ForEach(Accessory.allCases) { accessory in
                    Button { store.onboardingDraft.accessory = accessory } label: {
                        VStack(spacing: 10) {
                            PipArtwork(accessory: accessory).frame(width: 74, height: 84)
                            Text(accessory.title).font(.system(.caption, design: .rounded, weight: .semibold)).multilineTextAlignment(.center)
                            Image(systemName: draft.accessory == accessory ? "checkmark.circle.fill" : "circle").font(.caption)
                        }.foregroundStyle(Theme.accent).frame(maxWidth: .infinity).padding(.vertical, 14).frame(minHeight: 92)
                            .background(draft.accessory == accessory ? Theme.softAccent : Theme.card, in: RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(draft.accessory == accessory ? Theme.accent : Theme.line))
                    }.buttonStyle(.plain).accessibilityIdentifier("onboarding.accessory.\(accessory.rawValue)").accessibilityAddTraits(draft.accessory == accessory ? .isSelected : [])
                }
            }
        }
    }
    private var companionNameScreen: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading("Pip is lovely. Something of your own is lovely, too.")
            input("Companion name", placeholder: "Pip", value: binding(\.companionName, limit: 24), identifier: "onboarding.companionName")
            PipPlayground(name: companion, accessory: draft.accessory, message: "A little company, at your pace.", height: 210)
        }
    }
    private var checkInScreen: some View {
        VStack(alignment: .leading, spacing: 16) {
            heading("There’s no right answer. Just how things feel right now.").padding(.bottom, 5)
            Text("How are you feeling?").font(.headline)
            let layout = dynamicType.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 9)) : AnyLayout(HStackLayout(spacing: 9))
            layout {
                ForEach(Mood.allCases) { mood in
                    Button { store.onboardingDraft.mood = mood } label: {
                        VStack(spacing: 10) { Image(systemName: mood.symbol).font(.system(size: 27, weight: .light)); Text(mood.shortTitle).font(.caption.weight(.semibold)) }
                            .foregroundStyle(Theme.accent).frame(maxWidth: .infinity).frame(minHeight: 98)
                            .background(draft.mood == mood ? Theme.softAccent : Theme.card, in: RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(draft.mood == mood ? Theme.accent : Theme.line))
                    }.buttonStyle(.plain).accessibilityLabel(mood.title).accessibilityIdentifier("onboarding.mood.\(mood.rawValue)").accessibilityAddTraits(draft.mood == mood ? .isSelected : [])
                }
            }
            Text("And your appetite?").font(.headline).padding(.top, 8)
            ForEach(Appetite.allCases) { appetite in
                SetupChoice(title: appetite.title, symbol: "leaf", selected: draft.appetite == appetite, identifier: "onboarding.appetite.\(appetite.rawValue)") { store.onboardingDraft.appetite = appetite }
            }
        }
    }
    private var noteScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("What would you like to remember about today?")
            multiline("Today’s moment", placeholder: "A walk. A good conversation. How it felt to begin…", value: binding(\.note, limit: 500), identifier: "onboarding.note", limit: 500)
            HStack(spacing: 16) {
                PipArtwork(pose: .journal, accessory: draft.accessory).frame(width: 90, height: 100)
                Text("A sentence, a few words, or nothing at all. This is your page.").font(.system(.body, design: .serif)).foregroundStyle(Theme.secondaryInk).lineSpacing(4)
            }
        }
    }
    private var firstEntryScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("One small check-in. The beginning of a record you can come back to.")
            SetupJournalCard(draft: draft, recorded: true, entry: store.onboardingEntry)
            SetupHero(pose: .celebrate, accessory: draft.accessory, height: 180, caption: draft.encouragement == "Straightforward" ? (store.onboardingEntry == nil ? "Your journal preview." : "Your entry is saved.") : "A little beginning.")
        }
    }
    private var personalSpaceScreen: some View {
        VStack(alignment: .leading, spacing: 21) {
            heading("Built around what matters to you, \(draft.name.isEmpty ? "one day at a time" : draft.name).")
            HStack(spacing: 15) {
                PipArtwork(pose: .journal, accessory: draft.accessory).frame(width: 92, height: 112)
                VStack(alignment: .leading, spacing: 7) {
                    Text("\(companion) & you").alongTitle(27)
                    Text(store.onboardingEntry == nil ? "Your journal preview." : "Your first page is saved.").font(.subheadline).foregroundStyle(Theme.secondaryInk)
                    Text(draft.stage).font(.caption.weight(.medium)).foregroundStyle(Theme.accent)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).card()
            SetupBenefit(number: "01", title: draft.priority.isEmpty ? "Your personal record" : draft.priority, detail: draft.progressAreas.sorted().joined(separator: " · "))
            SetupBenefit(number: "02", title: "A rhythm of your own", detail: draft.routines.isEmpty ? "A simple check-in, whenever it fits." : draft.routines.sorted { $0.rawValue < $1.rawValue }.map { draft.routineNames[$0.rawValue] ?? $0.title }.joined(separator: " · "))
            SetupBenefit(number: "03", title: "Space to look back", detail: "A weekly chapter on \(Calendar.current.weekdaySymbols[draft.reflectionDay - 1]).")
            SetupNote(text: store.onboardingEntry == nil ? "An example of your personal space. Your own first entry appears here after setup." : "Your setup and first entry are saved. Membership opens the rest of your journal.", symbol: "lock")
        }
    }
    private var membershipScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("A place to keep coming back to, through every chapter.")
            SetupHero(pose: .journal, accessory: draft.accessory, height: 180)
            SetupBenefit(number: "01", title: "The everyday, remembered", detail: "Keep check-ins, personal moments and optional weight records together.")
            SetupBenefit(number: "02", title: "A little perspective", detail: "Look back through your history and weekly reflections.")
            SetupBenefit(number: "03", title: "Company along the way", detail: "Your chosen routines, your companion and keepsakes earned over time.")
            Text("Choose a monthly or yearly membership next. Payment begins when you subscribe.").font(.subheadline.weight(.medium)).foregroundStyle(Theme.accent).lineSpacing(3)
        }
    }
    private var paywallScreen: some View {
        VStack(alignment: .leading, spacing: 19) {
            BillingAvailabilityView()
            let layout = dynamicType.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
            layout {
                VStack(alignment: .leading, spacing: 10) {
                    Text("ALONG MEMBERSHIP").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1.5).foregroundStyle(Theme.accent)
                    Text(Self.titles[25]).alongTitle(32).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                PipArtwork(pose: .journal, accessory: draft.accessory).frame(width: 108, height: 128)
            }
            HStack { Pill(text: "No free trial", symbol: "checkmark"); Spacer() }
            Text("Your days, your progress, and a little company from \(companion).").font(.body).foregroundStyle(Theme.secondaryInk).lineSpacing(3)
            VStack(alignment: .leading, spacing: 14) {
                Label("Your complete personal journey", systemImage: "book.closed")
                Label("Reflections from your recorded days", systemImage: "sparkles")
                Label("Your routines, at your own pace", systemImage: "leaf")
            }.font(.subheadline.weight(.medium)).foregroundStyle(Theme.accent).card(padding: 17)
            MembershipPlans(selection: binding(\.plan))
            MembershipDisclosure(plan: draft.plan)
            HStack(spacing: 22) {
                Button("Restore") { Task { await billing.restore(); finishIfSubscribed() } }.disabled(billing.isBusy).accessibilityIdentifier("onboarding.restore")
                MembershipLegalLinks()
            }.font(.caption).frame(maxWidth: .infinity).frame(minHeight: 35)
            #if DEBUG
            Button("Open app preview · no payment") { showPreviewConfirmation = true }.font(.caption).frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("onboarding.preview")
            #endif
        }
    }
    private var footer: some View {
        VStack(spacing: 4) {
            Button {
                if step == 25 {
                    if billing.isEntitled { finishIfSubscribed() }
                    else { Task { await billing.purchase(plan: draft.plan.billingPlan); finishIfSubscribed() } }
                } else { advance() }
            } label: {
                HStack(spacing: 12) {
                    Spacer(minLength: 0)
                    Text(step == 25 && dynamicType.isAccessibilitySize ? (billing.isEntitled ? "Open journal" : billing.canPurchase ? "Subscribe" : "Unavailable") : primaryTitle).font(.system(.body, design: .rounded, weight: .semibold))
                    Image(systemName: step == 25 ? "lock.open" : "arrow.right").font(.system(size: 17, weight: .semibold))
                    Spacer(minLength: 0)
                }.padding(.vertical, 15).frame(minHeight: 56).padding(.horizontal, 12).foregroundStyle(.white)
                    .background(Theme.plum.opacity(primaryEnabled ? 1 : 0.35), in: RoundedRectangle(cornerRadius: 20))
            }.buttonStyle(.plain).disabled(!primaryEnabled).accessibilityLabel(primaryTitle).accessibilityIdentifier(step == 25 ? "onboarding.subscribe" : "onboarding.continue")
            if canSkip {
                Button("Skip for now", action: skip).font(.subheadline).foregroundStyle(Theme.secondaryInk).frame(minHeight: 38).accessibilityIdentifier("onboarding.skip")
            } else if step == 0 { Text("Made for your real life.").font(.caption).foregroundStyle(Theme.secondaryInk).frame(minHeight: 32) }
            else if step == 25 {
                Text(billing.product(for: draft.plan.billingPlan).map { "\($0.priceWithPeriod) · Due on purchase" } ?? (dynamicType.isAccessibilitySize ? "Checkout unavailable" : "No payment can be taken until plans are available."))
                    .font(.caption).foregroundStyle(Theme.secondaryInk).multilineTextAlignment(.center).frame(minHeight: 32)
            }
        }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 8).frame(maxWidth: 560).frame(maxWidth: .infinity)
            .background(Theme.paper.opacity(0.98)).overlay(alignment: .top) { Theme.line.frame(height: 1) }
    }
    private var primaryTitle: String {
        switch step {
        case 0: return "Meet your companion"
        case 6: return "Make this my space"
        case 11: return "Find my rhythm"
        case 19: return "Begin with \(companion)"
        case 20: return "Keep this moment"
        case 21: return "Save my first page"
        case 22: return "See my space"
        case 23: return "Explore membership"
        case 24: return "Choose my membership"
        case 25:
            if billing.isEntitled { return "Open my journal" }
            if billing.isBusy { return "Please wait…" }
            return billing.product(for: draft.plan.billingPlan).map { "Subscribe for \($0.priceWithPeriod)" } ?? "Purchases unavailable"
        default: return "Continue"
        }
    }
    private var primaryEnabled: Bool {
        draft.canContinue(at: step) && (step != 25 || billing.isEntitled || billing.canPurchase)
    }
    private func finishIfSubscribed() {
        if billing.isEntitled { _ = store.finishPaidOnboarding() }
    }
    private var canSkip: Bool { [1, 3, 8, 10, 19, 21].contains(step) }
    private func advance() {
        guard draft.canContinue(at: step) else { return }
        if step == 21 && !store.saveOnboardingEntry() { return }
        inputFocused = false
        let next = step == 9 && !draft.showWeight ? 11 : min(25, step + 1)
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { store.onboardingDraft.step = next }
    }
    private func back() { inputFocused = false; store.onboardingDraft.step = step == 11 && !draft.showWeight ? 9 : max(0, step - 1) }
    private func skip() {
        switch step {
        case 1: store.onboardingDraft.name = ""
        case 3: store.onboardingDraft.hasStartDate = false
        case 8: store.onboardingDraft.intention = ""
        case 10: store.onboardingDraft.weightValue = ""
        case 19: store.onboardingDraft.companionName = "Pip"
        case 21: store.onboardingDraft.note = ""
        default: break
        }
        advance()
    }
    private func binding<Value>(_ path: WritableKeyPath<OnboardingDraft, Value>) -> Binding<Value> {
        Binding(get: { store.onboardingDraft[keyPath: path] }, set: { store.onboardingDraft[keyPath: path] = $0 })
    }
    private func binding(_ path: WritableKeyPath<OnboardingDraft, String>, limit: Int) -> Binding<String> {
        Binding(get: { store.onboardingDraft[keyPath: path] }, set: { store.onboardingDraft[keyPath: path] = String($0.prefix(limit)) })
    }
    private func input(_ label: String, placeholder: String, value: Binding<String>, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label).font(.subheadline.weight(.medium)).foregroundStyle(Theme.secondaryInk)
            TextField(placeholder, text: value).font(.title2).textInputAutocapitalization(.words).autocorrectionDisabled().focused($inputFocused)
                .submitLabel(.continue).onSubmit { if draft.canContinue(at: step) { advance() } }
                .alongField()
                .accessibilityLabel(label).accessibilityIdentifier(identifier)
        }
    }
    private func multiline(_ label: String, placeholder: String, value: Binding<String>, identifier: String, limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(placeholder, text: value, axis: .vertical).lineLimit(5...8).font(.system(.body, design: .serif)).lineSpacing(5).focused($inputFocused)
                .alongField()
                .accessibilityLabel(label).accessibilityIdentifier(identifier)
            Text("\(value.wrappedValue.count) / \(limit)").font(.caption2).foregroundStyle(Theme.secondaryInk).frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
    private func choice(_ title: String, detail: String, symbol: String, value: String, key: WritableKeyPath<OnboardingDraft, String>, id: String) -> some View {
        let category = step == 2 ? "stage" : step == 4 ? "priority" : step == 5 ? "obstacle" : step == 14 ? "frequency" : step == 15 ? "reminder" : "encouragement"
        return SetupChoice(title: title, detail: detail, symbol: symbol, selected: draft[keyPath: key] == value, identifier: "onboarding.\(category).\(id)") { store.onboardingDraft[keyPath: key] = value }
    }
    private func progressChoice(_ title: String, symbol: String, id: String) -> some View {
        SetupChoice(title: title, symbol: symbol, selected: draft.progressAreas.contains(title), identifier: "onboarding.progress.\(id)") {
            if draft.progressAreas.contains(title) { store.onboardingDraft.progressAreas.remove(title) }
            else if draft.progressAreas.count < 3 { store.onboardingDraft.progressAreas.insert(title) }
        }
    }
    private func prepareScreenReview() {
        guard !preparedReview else { return }; preparedReview = true
        #if DEBUG
        let args = store.startupArguments
        guard let index = args.firstIndex(of: "--onboarding-step"), args.indices.contains(index + 1), let target = Int(args[index + 1]), (0..<26).contains(target) else { return }
        store.onboardingDraft = Self.exampleDraft(at: target)
        #endif
    }
    #if DEBUG
    static func exampleDraft(at target: Int) -> OnboardingDraft {
        var example = OnboardingDraft()
        example.step = target; example.name = "Alex"; example.stage = "Recently started"; example.priority = "Notice my progress"
        example.obstacle = "Noticing changes"; example.progressAreas = ["Energy", "Confidence"]; example.intention = "More energy for the things I love."
        example.showWeight = true; example.weightValue = "88.2"; example.routines = [.nutrition, .movement]
        example.frequency = "Flexible"; example.encouragement = "Gentle"; example.mood = .steady; example.appetite = .comfortable
        example.note = "Made time for a little walk. Glad I went."
        return example
    }
    #endif
}

struct MembershipTermsView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                AlongSection(title: "Membership information") { Text("Purchases are unavailable until the App Store plans and final legal documents have been configured. No subscription is created by previewing these screens.") }
                AlongSection(title: "Proposed membership") {
                    Text("Along offers monthly and yearly membership. The App Store price is shown before you subscribe. Billing starts immediately after a confirmed purchase. There is no free trial.")
                    Text("A production membership will renew automatically unless cancelled through the App Store subscription settings. Store pricing and final terms must be configured before purchases are enabled.")
                }
                AlongSection(title: "Your journal") { Text("Your saved entries remain on this device. Along supports personal reflection and routines; it does not give medical advice or medication instructions.") }
                }.padding(22).frame(maxWidth: 650)
            }.frame(maxWidth: .infinity).pageBackground().navigationTitle("Membership terms").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
