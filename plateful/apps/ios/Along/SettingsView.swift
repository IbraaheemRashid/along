import SwiftUI

struct SettingsView: View {
    @Environment(JournalStore.self) private var store
    @Environment(ReminderStore.self) private var reminders
    @Environment(BillingStore.self) private var billing
    @State private var showPrivacy = false
    @State private var showBackup = false
    @State private var showPaywall = false
    @State private var showOnboardingReview = false
    @State private var resetAction: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                membership
                units
                remindersSection
                data
                about
                disclaimer
            }
            .padding(.horizontal, 20).padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .sheet(isPresented: $showPrivacy) { PrivacyView() }
        .sheet(isPresented: $showBackup) { JournalBackupView(journal: { store.journal }, replace: store.restoreJournal) }
        .sheet(isPresented: $showPaywall) { MembershipView(canClose: true) }
        #if DEBUG
        .sheet(isPresented: $showOnboardingReview) { OnboardingCatalogView() }
        #endif
        .confirmationDialog(resetTitle, isPresented: Binding(get: { resetAction != nil }, set: { if !$0 { resetAction = nil } }), titleVisibility: .visible) {
            Button(resetAction == "all" ? "Delete all local data" : "Replace data", role: .destructive, action: performReset)
        } message: {
            Text(resetAction == "all"
                 ? "This clears your protocol, dose history, weight records and setup on this device. Export a backup first if you want to keep them."
                 : "This replaces local data and cannot be undone.")
        }
    }

    private var header: some View {
        HStack {
            Text("Settings").font(.system(size: 30, weight: .bold)).tracking(-0.6).foregroundStyle(SetupTheme.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            PreviewBadge()
        }
        .padding(.top, 8)
    }

    private var membership: some View {
        SettingsGroup(title: "Membership") {
            SettingsRow(title: billing.isEntitled ? "Along Membership" : "Membership & purchases",
                        detail: billing.isEntitled ? "Active on this Apple ID" : "Yearly or monthly · no trial",
                        symbol: "star") { showPaywall = true }
        }
    }

    private var units: some View {
        SettingsGroup(title: "Units") {
            HStack {
                Text("Weight").font(.system(.body, weight: .medium)).foregroundStyle(SetupTheme.ink)
                Spacer()
                SetupUnitToggle(left: "kg", right: "lb",
                                isRight: Binding(get: { store.journal.weightUnit == .lb },
                                                 set: { value in store.updateJournal { $0.weightUnit = value ? .lb : .kg } }))
                .frame(width: 140)
            }
            .frame(minHeight: 48)
            .accessibilityIdentifier("settings.weightUnit")

            Toggle(isOn: Binding(get: { store.journal.showWeight }, set: { value in store.updateJournal { $0.showWeight = value } })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show weight in Progress").font(.system(.body, weight: .medium)).foregroundStyle(SetupTheme.ink)
                    Text("Hiding weight keeps existing records.").font(.caption).foregroundStyle(SetupTheme.muted)
                }
            }
            .tint(SetupTheme.ink)
            .frame(minHeight: 48)
            .accessibilityIdentifier("settings.showWeight")
        }
    }

    private var remindersSection: some View {
        SettingsGroup(title: "Reminders") { ReminderSettingsView() }
    }

    private var data: some View {
        SettingsGroup(title: "Your data") {
            SettingsRow(title: "Privacy & your data", symbol: "lock") { showPrivacy = true }
            SettingsRow(title: "Backup & restore", symbol: "externaldrive") { showBackup = true }
            ShareLink(item: store.exportText, preview: SharePreview("Along export")) {
                SettingsRowLabel(title: "Export a readable copy", symbol: "square.and.arrow.up")
            }
            .buttonStyle(.plain)
            #if DEBUG
            SettingsRow(title: "Start a blank protocol", symbol: "plus.square") { resetAction = "blank" }
            SettingsRow(title: "Load sample protocol", symbol: "sparkles") { resetAction = "sample" }
            #endif
            SettingsRow(title: "Delete all local data", symbol: "trash", destructive: true) { resetAction = "all" }
        }
    }

    private var about: some View {
        SettingsGroup(title: "About") {
            #if DEBUG
            SettingsRow(title: "Review setup screens", symbol: "rectangle.stack") { showOnboardingReview = true }
            #endif
            LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development")
                .font(.subheadline).foregroundStyle(SetupTheme.ink)
            LabeledContent("Storage", value: "This device only")
                .font(.subheadline).foregroundStyle(SetupTheme.ink)
            if let config = billing.configuration.value {
                Link(destination: config.termsURL) { SettingsRowLabel(title: "Terms of use", symbol: "doc.text") }
                Link(destination: config.privacyURL) { SettingsRowLabel(title: "Privacy policy", symbol: "hand.raised") }
            } else {
                SettingsRow(title: "Terms of use", symbol: "doc.text") { showPrivacy = true }
                SettingsRow(title: "Privacy policy", symbol: "hand.raised") { showPrivacy = true }
            }
        }
    }

    private var disclaimer: some View {
        Text("Along is a peptide protocol tracker for adults. It never recommends peptides, doses or schedules, and it is not medical advice. Records stay on this device unless you export them.")
            .font(.caption).foregroundStyle(SetupTheme.muted)
            .padding(.top, 4)
    }

    private var resetTitle: String {
        switch resetAction {
        case "all": "Delete your local data?"
        case "sample": "Replace with sample protocol?"
        default: "Start a blank protocol?"
        }
    }

    private func performReset() {
        let action = resetAction; resetAction = nil
        #if DEBUG
        if action == "sample" { store.loadSample(); return }
        if action == "blank" { store.startBlank(); return }
        #endif
        Task {
            if reminders.deliveryEnabled, !(await reminders.reset()) {
                store.error = "Reminders could not be removed. Your protocol has been kept. Please try deleting again."
                return
            }
            store.clearJournal()
        }
    }
}

private struct SettingsGroup<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(SetupTheme.muted)
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SetupTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(SetupTheme.border))
        }
    }
}

private struct SettingsRow: View {
    var title: String
    var detail: String? = nil
    var symbol: String
    var destructive = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            SettingsRowLabel(title: title, detail: detail, symbol: symbol, destructive: destructive)
        }
        .buttonStyle(SetupPressStyle())
    }
}

private struct SettingsRowLabel: View {
    var title: String
    var detail: String? = nil
    var symbol: String
    var destructive = false
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(destructive ? Color.red : SetupTheme.ink)
                .frame(width: 32, height: 32)
                .background((destructive ? Color.red.opacity(0.1) : SetupTheme.tile), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(.body, weight: .medium))
                    .foregroundStyle(destructive ? Color.red : SetupTheme.ink)
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(SetupTheme.muted)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(SetupTheme.muted)
        }
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }
}

struct PrivacyView: View {
    @Environment(BillingStore.self) private var billing
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    privacyBlock(title: "Your protocol stays with you",
                                 body: "Your peptides, dose logs, notes, optional weight records and setup answers are stored in this app’s private device storage, protected by iOS file protection. Along marks the folder to be excluded from automatic backups; iOS ultimately controls device backup behaviour.")
                    privacyBlock(title: "Copies you choose to save",
                                 body: "A readable export and a restorable backup contain the records you created. Backup files are unencrypted. Review the destination before sharing. Delete all local data clears this device only — it does not cancel an App Store subscription.")
                    privacyBlock(title: "Reminders & membership",
                                 body: billing.isConfigured
                                 ? "Reminders are optional local notifications. They show the peptide name and amount you set, never notes or injection sites. Apple processes subscriptions. Superwall supports membership purchases when configured."
                                 : "Reminders are optional local notifications with no health notes. Membership purchases are not configured in this build.")
                    if let config = billing.configuration.value {
                        Link("Read the full privacy policy", destination: config.privacyURL)
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(22)
            }
            .background(SetupTheme.tile)
            .navigationTitle("Privacy & your data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private func privacyBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).foregroundStyle(SetupTheme.ink)
            Text(body).font(.subheadline).foregroundStyle(SetupTheme.muted)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SetupTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
