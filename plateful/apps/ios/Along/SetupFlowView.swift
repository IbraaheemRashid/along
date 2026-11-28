import SwiftUI

struct SetupFlowView: View {
    @Environment(JournalStore.self) private var store
    @Environment(BillingStore.self) private var billing
    @Environment(ReminderStore.self) private var reminders
    @Environment(AuthStore.self) private var auth
    @Environment(\.alongReducedMotion) private var reduceMotion
    @State private var forward = true
    @State private var showBackup = false
    @State private var showLocalData = false
    @State private var showSignIn = false
    @State private var requestingReminders = false
    @State private var previousPlan: SetupDraft?
    @State private var search = ""
    @State private var accountEmail = ""
    @State private var accountPassword = ""
    @FocusState private var fieldFocused: Bool

    private var draft: SetupDraft { store.setup }
    private var step: SetupStep { draft.step }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                screen(step)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("setup.screen.\(step.rawValue)")
                    .id(step)
                    .transition(.asymmetric(insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                                            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .background(SetupTheme.surface.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        // Keyboard must not resize the setup chrome — that layout thrash was crashing email fields.
        .ignoresSafeArea(.keyboard)
        .tint(SetupTheme.ink)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .sheet(isPresented: $showBackup) { JournalBackupView(journal: { store.journal }, replace: store.restoreJournal) }
        .sheet(isPresented: $showLocalData) { LocalDataView() }
        .sheet(isPresented: $showSignIn) {
            SetupSignInSheet(
                restoreBackup: {
                    showSignIn = false
                    Task { try? await Task.sleep(for: .seconds(0.4)); showBackup = true }
                },
                onSignedIn: {
                    showSignIn = false
                }
            )
        }
        .onChange(of: billing.isEntitled) { _, entitled in
            if entitled && step == .paywall {
                Task { await completePaidSetup() }
            }
        }
        .onChange(of: auth.user?.id) { _, id in
            if id != nil, step == .account, let email = auth.user?.email, !email.isEmpty {
                accountEmail = email
                store.setup.accountEmail = email
            }
        }
        .onChange(of: accountEmail) { _, value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if SetupDraft.validEmail(trimmed) {
                store.setup.accountEmail = trimmed
                if accountPassword.count >= 6 {
                    auth.stageOnboardingCredentials(email: trimmed, password: accountPassword)
                } else if !auth.emailDraft.isEmpty || auth.passwordDraft.count >= 6 {
                    auth.emailDraft = trimmed
                }
            }
        }
        .onChange(of: accountPassword) { _, value in
            let trimmed = accountEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            if SetupDraft.validEmail(trimmed), value.count >= 6 {
                auth.stageOnboardingCredentials(email: trimmed, password: value)
            }
        }
        .onAppear {
            if accountEmail.isEmpty { accountEmail = draft.accountEmail }
            if accountPassword.isEmpty, auth.passwordDraft.count >= 6 {
                accountPassword = auth.passwordDraft
            }
        }
    }

    // MARK: Chrome

    @ViewBuilder private var header: some View {
        if step.showsBack || step.showsProgress {
            HStack(spacing: 16) {
                if step.showsBack { SetupBackButton(action: back) } else { Color.clear.frame(width: 44, height: 44) }
                if step.showsProgress { SetupProgressBar(progress: draft.progress) } else { Spacer() }
            }
            .padding(.horizontal, 24).padding(.top, 6).padding(.bottom, 4)
            .frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
    }

    private struct FooterAction {
        var title: String
        var symbol: String? = nil
        var enabled = true
        var action: () -> Void
    }

    @ViewBuilder private var footer: some View {
        if step != .building {
            let primary = primaryAction
            VStack(spacing: 6) {
                SetupPrimaryButton(title: primary.title, symbol: primary.symbol, enabled: primary.enabled,
                                   identifier: step == .paywall ? "setup.subscribe" : "setup.continue", action: primary.action)
                footerAccessory
            }
            .padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 8)
            .frame(maxWidth: 560).frame(maxWidth: .infinity)
            .background(alignment: .top) {
                SetupTheme.surface.ignoresSafeArea(edges: .bottom)
                    .overlay(alignment: .top) {
                        LinearGradient(colors: [SetupTheme.surface.opacity(0), SetupTheme.surface], startPoint: .top, endPoint: .bottom)
                            .frame(height: 24).offset(y: -24).allowsHitTesting(false)
                    }
            }
        }
    }

    private var primaryAction: FooterAction {
        switch step {
        case .welcome: return FooterAction(title: "Get started", action: advance)
        case .commitment: return FooterAction(title: "Continue", action: advance)
        case .compounds: return FooterAction(title: draft.compounds.isEmpty ? "Choose at least one" : "Continue", enabled: !draft.compounds.isEmpty, action: advance)
        case .reminders: return FooterAction(title: requestingReminders ? "Please wait…" : "Turn on reminders", symbol: "bell.fill", enabled: !requestingReminders, action: requestReminders)
        case .referral:
            return FooterAction(title: draft.referralCode.isEmpty ? "Skip" : "Continue", enabled: draft.canContinue(at: .referral)) {
                if draft.referralCode.isEmpty { store.setup.referralCode = "" }
                advance()
            }
        case .ready: return FooterAction(title: "See my schedule", action: advance)
        case .plan: return FooterAction(title: "Continue to account", action: advance)
        case .account: return accountAction
        case .paywall: return paywallAction
        default: return FooterAction(title: "Continue", enabled: draft.canContinue(at: step), action: advance)
        }
    }

    private var accountAction: FooterAction {
        if auth.isSignedIn {
            return FooterAction(title: "Continue") {
                commitAccountEmail()
                advance()
            }
        }
        let emailOK = SetupDraft.validEmail(accountEmail)
        let passwordOK = accountPassword.count >= 6
        return FooterAction(title: "Continue", enabled: emailOK && passwordOK) {
            commitAccountEmail()
            auth.stageOnboardingCredentials(email: accountEmail, password: accountPassword)
            advance()
        }
    }

    private func commitAccountEmail() {
        let trimmed = accountEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        store.setup.accountEmail = trimmed
    }

    @ViewBuilder private var footerAccessory: some View {
        switch step {
        case .welcome:
            Button { showSignIn = true } label: {
                (Text("Already have an account? ").foregroundStyle(SetupTheme.muted) + Text("Sign in").fontWeight(.semibold).foregroundStyle(SetupTheme.ink))
                    .font(.subheadline).frame(maxWidth: .infinity, minHeight: 44)
            }.accessibilityIdentifier("setup.sign-in")
            if hasLocalRecords {
                SetupTextButton(title: "Your data & reminders", identifier: "setup.local-data") { showLocalData = true }
            }
        case .compounds:
            SetupTextButton(title: draft.experience == .planning ? "I haven’t decided yet" : "Skip for now", identifier: "setup.compounds.none") {
                store.setup.compounds = []; advance()
            }
        case .reminders:
            SetupTextButton(title: "Not now", identifier: "setup.reminders.skip") {
                store.setup.remindersRequested = false; advance()
            }
        case .paywall:
            Text("No free trial · Cancel anytime").font(.caption).foregroundStyle(SetupTheme.muted).lineLimit(1).minimumScaleFactor(0.8)
        default:
            EmptyView()
        }
    }

    private var hasLocalRecords: Bool {
        !store.journal.checkIns.isEmpty || !store.journal.weights.isEmpty || !store.journal.milestones.isEmpty
    }

    // MARK: Navigation

    private func advance() {
        guard draft.canContinue(at: step) else { return }
        fieldFocused = false
        var next = store.setup
        if step == .weight { next.prepareTarget() }
        if step == .target { next.hasChosenTarget = true }
        guard let destination = next.step(after: step) else { return }
        next.step = previousPlan != nil && step == .doseTime ? .plan : destination
        if step == .doseTime { previousPlan = nil }
        forward = true
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) { store.setup = next }
        _ = store.saveSetup()
    }

    private func back() {
        fieldFocused = false
        guard let previous = draft.step(before: step) else { return }
        forward = false
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.28)) {
            if step == .frequency, let original = previousPlan {
                store.setup = original
                previousPlan = nil
            } else {
                store.setup.step = previous
            }
        }
    }

    private func requestReminders() {
        requestingReminders = true
        Task {
            var preferences = reminders.preferences
            preferences.enabled = true
            // Sources are empty until setup finishes; sync runs after the protocol is created.
            let saved = await reminders.save(preferences, sources: [])
            store.setup.remindersRequested = saved
            requestingReminders = false
            advance()
        }
    }

    private func binding<Value>(_ path: WritableKeyPath<SetupDraft, Value>) -> Binding<Value> {
        Binding(get: { store.setup[keyPath: path] }, set: { store.setup[keyPath: path] = $0 })
    }

    // MARK: Screens

    @ViewBuilder private func screen(_ step: SetupStep) -> some View {
        switch step {
        case .welcome: welcome
        case .experience: experienceScreen
        case .goals: goalsScreen
        case .source: sourceScreen
        case .showcase: showcaseScreen
        case .pinMap: pinMapScreen
        case .birthday: birthdayScreen
        case .weight: weightScreen
        case .target: targetScreen
        case .commitment: commitmentScreen
        case .compounds: compoundsScreen
        case .frequency: frequencyScreen
        case .doseTime: doseTimeScreen
        case .obstacles: obstaclesScreen
        case .trust: trustScreen
        case .reminders: remindersScreen
        case .referral: referralScreen
        case .ready: readyScreen
        case .building: SetupBuildingView(draft: draft, reduceMotion: reduceMotion) { advance() }
        case .plan:
            SetupPlanView(draft: draft) {
                previousPlan = draft
                forward = false
                store.setup.step = .frequency
            }
        case .account: accountScreen
        case .paywall: paywallScreen
        }
    }

    private var accountScreen: some View {
        SetupScrollPage {
            SetupHeading(
                title: "Save your protocol",
                subtitle: "Add your email now. We’ll sign you in automatically when you subscribe so your plan syncs across devices."
            )
            VStack(spacing: 12) {
                AlongFormField(text: $accountEmail, kind: .email, placeholder: "Email", identifier: "setup.account.email") {
                    fieldFocused = false
                }
                if !auth.isSignedIn {
                    AlongFormField(text: $accountPassword, kind: .password, placeholder: "Password (min 6 characters)", identifier: "setup.account.password")
                }
                if auth.isSignedIn {
                    Label(auth.user?.email ?? "Signed in", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(SetupTheme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                        .accessibilityIdentifier("setup.account.signed-in")
                }
            }
            .padding(.top, 20)

            if !auth.isSignedIn {
                HStack(spacing: 12) {
                    Rectangle().fill(SetupTheme.border).frame(height: 1)
                    Text("or").font(.caption.weight(.medium)).foregroundStyle(SetupTheme.muted)
                    Rectangle().fill(SetupTheme.border).frame(height: 1)
                }
                .padding(.vertical, 8)

                accountProvider("Continue with Apple", identifier: "apple", filled: true) {
                    Image(systemName: "apple.logo").font(.system(size: 19, weight: .medium))
                } action: {
                    fieldFocused = false
                    Task {
                        await auth.signInWithApple()
                        if auth.isSignedIn {
                            if let email = auth.user?.email {
                                accountEmail = email
                                store.setup.accountEmail = email
                            }
                            advance()
                        }
                    }
                }
                accountProvider("Continue with Google", identifier: "google", filled: false) {
                    Text("G").font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [Color(red: 0.26, green: 0.52, blue: 0.96), Color(red: 0.92, green: 0.26, blue: 0.21), Color(red: 0.98, green: 0.74, blue: 0.02), Color(red: 0.2, green: 0.66, blue: 0.33)], startPoint: .topLeading, endPoint: .bottomTrailing))
                } action: {
                    fieldFocused = false
                    Task {
                        await auth.signInWithGoogle()
                        if auth.isSignedIn {
                            if let email = auth.user?.email {
                                accountEmail = email
                                store.setup.accountEmail = email
                            }
                            advance()
                        }
                    }
                }

                if let notice = auth.message {
                    Text(notice).font(.footnote).foregroundStyle(SetupTheme.muted).multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity).padding(.top, 4)
                        .accessibilityIdentifier("setup.account.notice")
                }
            }
        }
        .disabled(auth.isBusy)
        .onAppear {
            if accountEmail.isEmpty { accountEmail = draft.accountEmail }
        }
    }

    private func accountProvider<Icon: View>(_ title: String, identifier: String, filled: Bool, @ViewBuilder icon: () -> Icon, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                icon().frame(width: 22)
                Text(title).font(.system(.body, weight: .semibold))
            }
            .foregroundStyle(filled ? SetupTheme.inverseInk : SetupTheme.ink)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(filled ? SetupTheme.ink : SetupTheme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(filled ? Color.clear : SetupTheme.border, lineWidth: 1.5))
            .contentShape(Capsule())
        }
        .buttonStyle(SetupPressStyle())
        .accessibilityIdentifier("setup.account.\(identifier)")
    }

    private var welcome: some View {
        VStack(spacing: 22) {
            SetupPhoneDemo(reduceMotion: reduceMotion)
                .frame(maxHeight: .infinity)
                .padding(.top, 12)
            Text("Start your peptides\nwith a clear plan").setupTitleFont().multilineTextAlignment(.center).foregroundStyle(SetupTheme.ink)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.horizontal, 24).padding(.bottom, 26)
    }

    private var experienceScreen: some View {
        SetupQuestionPage(title: "Where are you with peptides?", subtitle: "We’ll shape your setup around where you are right now.") {
            ForEach(PeptideExperience.allCases) { option in
                SetupOptionRow(title: option.title, detail: option.detail, icon: .symbol(option.symbol), selected: draft.experience == option,
                               identifier: "setup.experience.\(option.rawValue)") { store.setup.experience = option }
            }
        }
    }

    private var goalsScreen: some View {
        SetupQuestionPage(title: "What are your peptides for?", subtitle: "Choose all that apply. Your protocol is organised around these.") {
            ForEach(SetupGoal.allCases) { goal in
                SetupOptionRow(title: goal.title, icon: .symbol(goal.symbol), selected: draft.goals.contains(goal), multiple: true,
                               identifier: "setup.goal.\(goal.rawValue)") {
                    if draft.goals.contains(goal) { store.setup.goals.remove(goal) } else { store.setup.goals.insert(goal) }
                }
            }
        }
    }

    private var sourceScreen: some View {
        SetupQuestionPage(title: "Where did you hear about us?") {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(HeardFrom.allCases) { source in
                    SetupGridOption(title: source.title, symbol: source.symbol, selected: draft.heardFrom == source,
                                    identifier: "setup.source.\(source.rawValue)") { store.setup.heardFrom = source }
                }
            }
        }
    }

    private var showcaseScreen: some View {
        SetupQuestionPage(title: "Know exactly what you took, and when", subtitle: "Log each dose in one tap: the peptide, the amount and the time. Your whole week, at a glance.") {
            SetupWeekCard(pattern: [true, true, false, true, true, false, true], animated: !reduceMotion, footnote: "Next · BPC-157, tomorrow at 8:00")
        }
    }

    private var pinMapScreen: some View {
        SetupQuestionPage(
            title: "Rotate pin sites with a body map",
            subtitle: "When you log a dose you’ll open this 3D map. Tap a region, then a spot. Heat builds from your history — Along never chooses a site for you."
        ) {
            InjectionSitePicker(
                peptideName: "Your dose",
                heat: SpotHeat(),
                lastSpot: nil,
                initial: nil,
                isDemo: true,
                onFinish: { _ in },
                onCancel: {}
            )
            .frame(minHeight: 460)
            .padding(.horizontal, -8)
            .accessibilityIdentifier("setup.pinMap.demo")
        }
    }

    private var birthdayScreen: some View {
        SetupQuestionPage(title: "When were you born?", subtitle: "Along is for adults aged 18 and over.") {
            DatePicker("Date of birth", selection: binding(\.birthDate), in: Self.birthRange, displayedComponents: .date)
                .datePickerStyle(.wheel).labelsHidden().frame(maxWidth: .infinity)
                .accessibilityIdentifier("setup.birthday")
            Group {
                if let age = draft.age(), draft.isAdult() {
                    Text("You’re \(age)").foregroundStyle(SetupTheme.muted)
                } else {
                    Text("You need to be 18 or older to use Along.").foregroundStyle(SetupTheme.highlight)
                }
            }.font(.subheadline.weight(.medium)).frame(maxWidth: .infinity).contentTransition(.numericText())
        }
    }

    private static var birthRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let earliest = calendar.date(byAdding: .year, value: -110, to: .now) ?? .distantPast
        return earliest...Date.now
    }

    private var weightScreen: some View {
        SetupQuestionPage(title: "What’s your current weight?", subtitle: "Your starting point, saved as your first weight record.") {
            SetupUnitToggle(left: "lb", right: "kg", isRight: binding(\.usesMetric)).frame(maxWidth: .infinity)
            weightReadout(label: "Current weight", kilograms: draft.weightKg)
            weightRuler(\.weightKg, anchor: nil, label: "Current weight")
        }
    }

    private var targetScreen: some View {
        SetupQuestionPage(title: "What’s your goal weight?", subtitle: "You can change this at any time.") {
            weightReadout(label: draft.targetDirection, kilograms: draft.targetKg)
            weightRuler(\.targetKg, anchor: draft.weightKg, label: "Goal weight")
        }
    }

    private func weightReadout(label: String, kilograms: Double) -> some View {
        VStack(spacing: 6) {
            Text(label).font(.subheadline).foregroundStyle(SetupTheme.muted)
            Text(draft.formattedWeight(kilograms)).font(.system(size: 44, weight: .bold)).monospacedDigit()
                .foregroundStyle(SetupTheme.ink).contentTransition(.numericText())
        }.frame(maxWidth: .infinity).padding(.top, 18)
    }

    private func weightRuler(_ path: WritableKeyPath<SetupDraft, Double>, anchor: Double?, label: String) -> some View {
        let unit = draft.weightUnit
        let range = unit == .kg ? SetupDraft.weightRange : 66.0...550.0
        return SetupRuler(value: Binding(get: { unit.display(store.setup[keyPath: path]) }, set: { value in
            let kilograms = min(SetupDraft.weightRange.upperBound, max(SetupDraft.weightRange.lowerBound, unit.kilograms(value)))
            store.setup[keyPath: path] = (kilograms * 100).rounded() / 100
        }), range: range, step: unit == .kg ? 0.1 : 0.5, anchor: anchor.map(unit.display), accessibilityLabel: label, unit: unit.rawValue)
        .id(unit)
        .padding(.horizontal, -24)
        .accessibilityIdentifier("setup.ruler")
    }

    private var commitmentScreen: some View {
        VStack(spacing: 14) {
            Spacer()
            SetupRingArtwork(symbol: "calendar.badge.checkmark").padding(.bottom, 10)
            commitmentTitle.setupTitleFont().multilineTextAlignment(.center).foregroundStyle(SetupTheme.ink)
                .accessibilityAddTraits(.isHeader)
            Text(commitmentDetail).font(.body).foregroundStyle(SetupTheme.muted).multilineTextAlignment(.center)
            Spacer(); Spacer()
        }.padding(.horizontal, 32)
    }

    private var commitmentTitle: Text {
        if draft.tracksWeightGoal && abs(draft.targetChange) >= 0.5 {
            return Text("Reaching ") + Text(draft.formattedWeight(draft.targetKg)).foregroundStyle(SetupTheme.highlight) + Text(" starts with consistency")
        }
        return Text("Consistency is the part ") + Text("you control").foregroundStyle(SetupTheme.highlight)
    }

    private var commitmentDetail: String {
        switch draft.experience {
        case .planning?: "Protocols run on schedules. Set yours up now, and from your first dose you’ll know exactly where you are."
        case .experienced?: "Protocols run on schedules. Keep every dose, amount and time in one place, so nothing slips."
        default: "Protocols run on schedules. Missed or doubled doses are easy to make early on. Along keeps you on track."
        }
    }

    private var compoundsScreen: some View {
        SetupScrollPage {
            SetupHeading(title: draft.experience == .planning ? "Which peptides are you starting?" : "Which peptides are you taking?", subtitle: "Tap to add. Search for anything not listed.")
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(SetupTheme.muted)
                TextField("Search peptides", text: $search).focused($fieldFocused)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.done)
                    .onSubmit(addSearchedCompound)
                    .accessibilityIdentifier("setup.compounds.search")
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(SetupTheme.muted) }.accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 16).frame(minHeight: 50)
            .background(SetupTheme.tile, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.top, 20)

            let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
            if query.isEmpty {
                chipSection("Popular peptides") {
                    ForEach(Peptide.popular) { peptide in compoundChip(peptide.name) }
                }
                let custom = draft.compounds.filter { name in !Peptide.popular.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame } }
                if !custom.isEmpty {
                    chipSection("Also added") { ForEach(custom, id: \.self) { compoundChip($0) } }
                }
                Text("Search the full catalogue for anything else.")
                    .font(.caption).foregroundStyle(SetupTheme.muted).padding(.top, 12)
            } else {
                let matches = Peptide.matches(query)
                chipSection(matches.isEmpty ? "No matches" : "Results") {
                    ForEach(matches) { compoundChip($0.name, clearingSearch: true) }
                    if !matches.contains(where: { $0.name.caseInsensitiveCompare(query) == .orderedSame }) && SetupDraft.validCompound(query) {
                        SetupChip(title: "Add “\(query)”", selected: false, identifier: "setup.compounds.add") { addSearchedCompound() }
                    }
                }
            }
            if !draft.compounds.isEmpty {
                Text("\(draft.compounds.count) selected").font(.footnote.weight(.medium)).foregroundStyle(SetupTheme.muted).padding(.top, 16)
            }
        }
    }

    private func compoundChip(_ name: String, clearingSearch: Bool = false) -> some View {
        SetupChip(title: name, selected: draft.contains(name), identifier: "setup.compound.\(name)") {
            store.setup.toggleCompound(name)
            if clearingSearch { search = "" }
        }
    }

    private func addSearchedCompound() {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard SetupDraft.validCompound(query) else { return }
        let canonical = Peptide.library.first { $0.name.caseInsensitiveCompare(query) == .orderedSame }?.name ?? query
        if !draft.contains(canonical) { store.setup.toggleCompound(canonical) }
        search = ""
    }

    private func chipSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased()).font(.caption.weight(.semibold)).tracking(0.8).foregroundStyle(SetupTheme.muted)
            SetupFlowLayout(spacing: 8) { content() }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 22)
    }

    private var frequencyScreen: some View {
        SetupQuestionPage(title: draft.experience == .planning ? "How often will you dose?" : "How often do you dose?", subtitle: "Choose the frequency in your own protocol. You’ll review the days and times next.") {
            ForEach(DoseFrequency.allCases) { option in
                SetupOptionRow(title: option.title, detail: option.detail, icon: .symbol(option.symbol), selected: draft.frequency == option,
                               identifier: "setup.frequency.\(option.rawValue)") {
                    if draft.frequency != option { store.setup.sharedWeekdays = [] }
                    store.setup.frequency = option
                }
            }
        }
    }

    @ViewBuilder private var doseTimeScreen: some View {
        if draft.compounds.isEmpty {
            SetupQuestionPage(title: "Set your schedule later", subtitle: "When you add your first peptide in Your peptides, you can choose its days and times.") {
                Image(systemName: "calendar").font(.largeTitle).foregroundStyle(SetupTheme.muted)
                    .accessibilityHidden(true)
            }
        } else if draft.frequency == .varies {
            SetupQuestionPage(title: "When is each peptide scheduled?", subtitle: "Choose the days and time you follow for each peptide. Leave the days blank to set a schedule later in Your peptides, including intervals or multiple times a day.") {
                ForEach(draft.compounds, id: \.self) { name in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(name).font(.headline)
                        WeekdayPicker(selection: weekdays(for: name), identifier: "setup.weekday.\(name)")
                        if let schedule = draft.peptideSchedules[name], let time = schedule.times.first {
                            DatePicker("Dose time", selection: Binding(get: { time.date(on: store.todayKey) ?? .now }, set: { date in
                                store.setup.peptideSchedules[name]?.times = [doseTime(from: date)]
                            }), displayedComponents: .hourAndMinute)
                                .accessibilityIdentifier("setup.dose-time.\(name)")
                        } else {
                            Text("Schedule not set").font(.caption).foregroundStyle(SetupTheme.muted)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        } else {
            SetupQuestionPage(title: "When are your doses scheduled?", subtitle: draft.compounds.joined(separator: " · ")) {
                if draft.frequency == .weekly || draft.frequency == .fewPerWeek {
                    Text(draft.frequency == .weekly ? "Choose your dose day" : "Choose your dose days")
                        .font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                    WeekdayPicker(selection: binding(\.sharedWeekdays), single: draft.frequency == .weekly, identifier: "setup.weekday")
                }
                DatePicker("Dose time", selection: Binding(get: { draft.doseTime }, set: { date in
                    let time = doseTime(from: date)
                    store.setup.doseHour = time.hour
                    store.setup.doseMinute = time.minute
                }), displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel).labelsHidden().frame(maxWidth: .infinity)
                    .accessibilityIdentifier("setup.dose-time")
            }
        }
    }

    private func weekdays(for name: String) -> Binding<Set<Int>> {
        Binding(get: { store.setup.peptideSchedules[name]?.weekdays ?? [] }, set: { days in
            let time = store.setup.peptideSchedules[name]?.times.first ?? DoseTime(hour: draft.doseHour, minute: draft.doseMinute)
            store.setup.peptideSchedules[name] = days.isEmpty ? nil : .on(days, at: time)
        })
    }

    private func doseTime(from date: Date) -> DoseTime {
        DoseTime(hour: Calendar.current.component(.hour, from: date), minute: Calendar.current.component(.minute, from: date))
    }

    private var obstaclesScreen: some View {
        SetupQuestionPage(title: draft.experience == .experienced ? "What’s getting in the way?" : "What feels hardest about it?", subtitle: "Choose all that apply. Your plan will cover each one.") {
            ForEach(SetupObstacle.allCases) { obstacle in
                SetupOptionRow(title: obstacle.title, icon: .symbol(obstacle.symbol), selected: draft.obstacles.contains(obstacle), multiple: true,
                               identifier: "setup.obstacle.\(obstacle.rawValue)") {
                    if draft.obstacles.contains(obstacle) { store.setup.obstacles.remove(obstacle) } else { store.setup.obstacles.insert(obstacle) }
                }
            }
        }
    }

    private var trustScreen: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 8)
            SetupRingArtwork(symbol: "lock.shield")
            SetupHeading(title: "Thank you for trusting us", subtitle: "Now let’s build your protocol.", centered: true)
            VStack(spacing: 14) {
                trustRow("iphone", "Private by design", "Your protocol stays on this iPhone, with optional cloud backup when you’re signed in. We never sell your data.")
                Divider()
                trustRow("stethoscope", "A tracker, not a prescriber", "Along keeps your record straight. Dosing and treatment decisions stay with you and your clinician.")
            }
            .padding(18).background(SetupTheme.tile, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            Spacer(minLength: 8)
        }.padding(.horizontal, 24)
    }

    private func trustRow(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            SetupIconTile(icon: .symbol(symbol), size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(SetupTheme.ink)
                Text(detail).font(.footnote).foregroundStyle(SetupTheme.muted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var remindersScreen: some View {
        VStack(spacing: 30) {
            Spacer()
            SetupHeading(title: "Never miss a dose", subtitle: "Along can notify you at the times you set for each peptide.", centered: true)
            SetupNotificationMock(allow: requestReminders, disabled: requestingReminders)
            Spacer(); Spacer()
        }.padding(.horizontal, 24)
    }

    private var referralScreen: some View {
        SetupQuestionPage(title: "Have a referral code?", subtitle: "Optional. Enter a code from a creator or friend.", centered: false) {
            TextField("Referral code", text: Binding(get: { draft.referralCode }, set: { store.setup.referralCode = String($0.uppercased().prefix(SetupDraft.referralLimit)) }))
                .font(.system(.title3, weight: .semibold)).multilineTextAlignment(.center)
                .textInputAutocapitalization(.characters).autocorrectionDisabled().focused($fieldFocused)
                .submitLabel(.done).onSubmit { if draft.canContinue(at: .referral) { advance() } }
                .padding(.horizontal, 16).frame(minHeight: 60)
                .background(SetupTheme.tile, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityIdentifier("setup.referral")
                .task { if draft.referralCode.isEmpty { fieldFocused = true } }
            if !draft.canContinue(at: .referral) {
                Text("Use letters, numbers, - or _ only.").font(.footnote).foregroundStyle(SetupTheme.highlight).frame(maxWidth: .infinity)
            }
        }
    }

    private var readyScreen: some View {
        SetupQuestionPage(title: draft.compounds.isEmpty ? "Your schedule preview" : "When was your last injection?",
                          subtitle: draft.compounds.isEmpty ? "You can add your first peptide and its schedule later." : "Optional. Add a past injection for any peptide, or continue if you haven’t started.") {
            ForEach(draft.compounds, id: \.self) { name in
                SetupCard {
                    Text(name).font(.headline)
                    if let entry = draft.lastInjections[name] {
                        DatePicker("Last injection", selection: Binding(get: { entry.takenAt }, set: { date in
                            guard let key = DayIdentity.key(for: date) else { return }
                            var updated = entry
                            updated.takenAt = date
                            updated.dayKey = key
                            store.setup.lastInjections[name] = updated
                        }), in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                        Picker("Site (optional)", selection: Binding(get: { entry.site }, set: { store.setup.lastInjections[name]?.site = $0 })) {
                            Text("Unspecified").tag(InjectionSite?.none)
                            ForEach(InjectionSite.allCases) { site in Text(site.title).tag(Optional(site)) }
                        }
                        Button("Remove entry") { store.setup.lastInjections[name] = nil }
                            .accessibilityLabel("Remove last injection for \(name)")
                    } else {
                        Button {
                            let now = Date.now
                            if let key = DayIdentity.key(for: now) {
                                store.setup.lastInjections[name] = SetupInjection(takenAt: now, dayKey: key)
                            }
                        } label: { Label("Add last injection", systemImage: "plus") }
                        .accessibilityLabel("Add last injection for \(name)")
                        .accessibilityIdentifier("setup.last-injection.\(name)")
                    }
                }
            }
        }
    }

    // MARK: Paywall

    private var paywallScreen: some View {
        SetupScrollPage {
            SetupHeading(title: "Unlock your protocol", subtitle: "Track the peptides and schedules you choose.")
            VStack(alignment: .leading, spacing: 14) {
                benefit("checkmark.circle.fill", "One-tap dose log for \(draft.compounds.isEmpty ? "every peptide" : draft.compounds.prefix(2).joined(separator: " and "))")
                benefit("bell.badge.fill", draft.remindersRequested == true ? draft.reminderSummary : "Optional reminders for each scheduled dose")
                benefit("chart.line.uptrend.xyaxis", draft.tracksWeightGoal ? "Progress towards \(draft.formattedWeight(draft.targetKg))" : "A full history of every dose")
            }.padding(.top, 22)
            VStack(spacing: 12) {
                planOption(.annual, title: "Yearly", period: "year", badge: "BEST VALUE")
                planOption(.monthly, title: "Monthly", period: "month", badge: nil)
            }.padding(.top, 26)
            if let notice = billingNotice {
                Text(notice).font(.footnote).foregroundStyle(SetupTheme.muted).multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.top, 14)
                    .accessibilityIdentifier("setup.billing-notice")
            }
            paywallFinePrint.padding(.top, 18)
        }
        .task(id: step) {
            guard step == .paywall, billing.usesSuperwallDashboard else { return }
            _ = await billing.presentOnboardingPaywall()
        }
    }

    private func benefit(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 18, weight: .semibold)).foregroundStyle(SetupTheme.ink).frame(width: 26)
            Text(text).font(.body).foregroundStyle(SetupTheme.ink).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func planOption(_ plan: OnboardingPlan, title: String, period: String, badge: String?) -> some View {
        let selected = draft.plan == plan
        let price = billing.product(for: plan.billingPlan)?.displayPrice ?? examplePrice(plan)
        return Button { store.setup.plan = plan } label: {
            VStack(spacing: 0) {
                if let badge {
                    Text(badge).font(.caption.weight(.bold)).tracking(0.8).foregroundStyle(selected ? SetupTheme.inverseInk : SetupTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 28).background(selected ? SetupTheme.ink : SetupTheme.tile)
                }
                HStack(spacing: 14) {
                    ZStack {
                        Circle().strokeBorder(selected ? SetupTheme.ink : SetupTheme.border, lineWidth: 1.5)
                        if selected { Circle().fill(SetupTheme.ink); Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(SetupTheme.inverseInk) }
                    }.frame(width: 24, height: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.system(.body, weight: .semibold)).foregroundStyle(SetupTheme.ink)
                        Text(plan == .annual ? "Billed once a year" : "Billed every month").font(.footnote).foregroundStyle(SetupTheme.muted)
                    }
                    Spacer()
                    Text(price.map { "\($0)/\(period)" } ?? "—").font(.system(.body, weight: .semibold)).foregroundStyle(SetupTheme.ink)
                }.padding(.horizontal, 16).frame(minHeight: 68)
            }
            .background(SetupTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(selected ? SetupTheme.ink : SetupTheme.border, lineWidth: selected ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(SetupPressStyle())
        .sensoryFeedback(.selection, trigger: selected)
        .accessibilityIdentifier("setup.plan.\(plan.rawValue)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func examplePrice(_ plan: OnboardingPlan) -> String? {
        #if DEBUG
        if !billing.isConfigured { return plan == .annual ? "£49.99" : "£12.99" }
        #endif
        return nil
    }

    private var billingNotice: String? {
        if let notice = billing.notice { return notice }
        #if DEBUG
        if billing.configuration.value?.superwallPublicKey == BillingConfiguration.localStoreKitKey {
            return "Local StoreKit prices. Simulator purchases unlock the app for this device only."
        }
        if !billing.isConfigured { return "Example prices for development. Purchases aren’t available in this build, so no payment will be taken." }
        #endif
        if !billing.isConfigured { return "Purchases aren’t available in this build. No payment will be taken." }
        if billing.catalogState == .loading { return "Loading App Store plans…" }
        if case .failed = billing.catalogState { return "We couldn’t load App Store plans. Check your connection and try again." }
        return nil
    }

    private var paywallAction: FooterAction {
        if billing.isEntitled {
            return FooterAction(title: "Open Along") {
                Task { await completePaidSetup() }
            }
        }
        if billing.isBusy || auth.isBusy { return FooterAction(title: "Please wait…", enabled: false) {} }
        return FooterAction(title: "Continue", enabled: billing.canPurchase) {
            Task {
                _ = await billing.purchase(plan: draft.plan.billingPlan)
                if billing.isEntitled { await completePaidSetup() }
            }
        }
    }

    /// Persist setup answers first, then create/sign-in so cloud restore cannot clobber them.
    private func completePaidSetup() async {
        persistAccountCredentials()
        guard store.finishSetup() else { return }
        await signInAfterSetupIfNeeded()
    }

    /// Temporary unlock while App Store / Superwall aren’t wired. Still creates the account.
    private func completeSkippedPaywall() async {
        persistAccountCredentials()
        guard store.finishSetupPreview() else { return }
        await signInAfterSetupIfNeeded()
    }

    /// Keep AuthStore as the source of truth so a view rebuild can’t lose the password.
    private func persistAccountCredentials() {
        commitAccountEmail()
        let email = store.setup.accountEmail
        let password = accountPassword.count >= 6 ? accountPassword : auth.passwordDraft
        if SetupDraft.validEmail(email), password.count >= 6 {
            auth.stageOnboardingCredentials(email: email, password: password)
        }
        _ = store.saveSetup()
    }

    private func signInAfterSetupIfNeeded() async {
        guard !auth.isSignedIn else { return }
        persistAccountCredentials()
        let email = store.setup.accountEmail
        guard SetupDraft.validEmail(email) else { return }
        // Prefer the staged password; never invent a new one if the member already chose one.
        if auth.passwordDraft.count < 6, accountPassword.count >= 6 {
            auth.stageOnboardingCredentials(email: email, password: accountPassword)
        }
        _ = await auth.ensureSignedInAfterPurchase(email: email)
    }

    private var paywallFinePrint: some View {
        VStack(spacing: 4) {
            Text(billing.product(for: draft.plan.billingPlan).map { "\($0.priceWithPeriod), renews automatically until cancelled in Settings." } ?? "Renews automatically until cancelled in Settings.")
                .font(.caption).foregroundStyle(SetupTheme.muted).multilineTextAlignment(.center)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 18) { paywallLinks }
                VStack(spacing: 0) { paywallLinks }
            }.font(.caption).foregroundStyle(SetupTheme.muted).tint(SetupTheme.muted).frame(minHeight: 32)
            #if DEBUG
            Button("Continue without paying · temporary") {
                Task { await completeSkippedPaywall() }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(SetupTheme.ink)
            .frame(minHeight: 32)
            .disabled(auth.isBusy)
            .accessibilityIdentifier("setup.skip-paywall")
            #endif
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var paywallLinks: some View {
        MembershipLegalLinks(compact: true)
        Button("Restore") {
            Task {
                await billing.restore()
                if billing.isEntitled { await completePaidSetup() }
            }
        }
            .disabled(billing.isBusy || auth.isBusy).frame(minHeight: 32).accessibilityIdentifier("setup.restore")
        Button("Your data") { showLocalData = true }.frame(minHeight: 32).accessibilityIdentifier("setup.local-data")
    }
}

// MARK: - Page layouts

/// Title at the top, answers centred in the remaining space. Scrolls only when
/// the content is taller than the screen, e.g. at the largest text sizes.
struct SetupQuestionPage<Content: View>: View {
    var title: String
    var subtitle: String?
    var centered = true
    @ViewBuilder var content: Content
    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    SetupHeading(title: title, subtitle: subtitle).padding(.top, 18)
                    if centered { Spacer(minLength: 28) } else { Color.clear.frame(height: 32) }
                    VStack(spacing: 12) { content }
                    Spacer(minLength: 28)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 560, minHeight: proxy.size.height)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

struct SetupScrollPage<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) { content }
                .padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 32)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
    }
}
