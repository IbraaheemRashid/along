import SwiftUI

struct SettingsView: View {
    @Environment(JournalStore.self) private var store
    @Environment(ReminderStore.self) private var reminders
    @Environment(BillingStore.self) private var billing
    @Environment(AuthStore.self) private var auth
    @Environment(CloudSync.self) private var cloudSync
    @State private var showPrivacy = false
    @State private var showBackup = false
    @State private var showPaywall = false
    @State private var showPeptides = false
    @State private var showSignIn = false
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Settings")
                    .font(.system(size: 30, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(SetupTheme.ink)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 8)

                account
                membership
                protocolSection
                preferences
                remindersSection
                data
                about
                disclaimer
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .sheet(isPresented: $showPrivacy) { PrivacyView() }
        .sheet(isPresented: $showBackup) { JournalBackupView(journal: { store.journal }, replace: store.restoreJournal) }
        .sheet(isPresented: $showPaywall) { MembershipView(canClose: true) }
        .sheet(isPresented: $showPeptides) { ProtocolPeptidesView() }
        .sheet(isPresented: $showSignIn) {
            SetupSignInSheet(restoreBackup: { showSignIn = false; showBackup = true })
        }
        .confirmationDialog("Delete this journal from this iPhone?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) { deleteLocalData() }
        } message: {
            Text("This clears your protocol, dose history, weight records and setup on this device. Export a backup first if you want to keep them. Your App Store subscription is unchanged.")
        }
    }

    private var account: some View {
        SettingsGroup(title: "Account") {
            if let user = auth.user {
                SettingsInfoRow(
                    title: user.email ?? user.displayName ?? "Signed in",
                    detail: cloudSyncDetail,
                    symbol: "person.crop.circle.fill"
                )
                SettingsDivider()
                if cloudSync.conflict != nil {
                    AccountBackupChoice()
                } else if cloudSync.message != nil {
                    SettingsRow(title: "Retry backup", symbol: "arrow.clockwise") { Task { await cloudSync.prepare() } }
                }
                SettingsRow(title: "Sign out", symbol: "rectangle.portrait.and.arrow.right", destructive: true, showsChevron: false) {
                    auth.signOut()
                }
            } else {
                SettingsRow(
                    title: "Sign in",
                    detail: auth.isConfigured ? "Sync your protocol across devices" : "Accounts aren’t configured in this build",
                    symbol: "person.crop.circle"
                ) { showSignIn = true }
            }
        }
    }

    private var cloudSyncDetail: String {
        if cloudSync.isSyncing { return "Syncing…" }
        if let message = cloudSync.message ?? auth.message { return message }
        if let synced = cloudSync.lastSyncedAt {
            return "Last synced \(synced.formatted(date: .abbreviated, time: .shortened))"
        }
        return auth.isConfigured ? "Cloud backup on" : "Saved on this iPhone"
    }

    private var membership: some View {
        SettingsGroup(title: "Membership") {
            SettingsRow(
                title: billing.isEntitled ? "Along Membership" : "Manage membership",
                detail: billing.isEntitled ? "Active on this Apple ID" : "Yearly or monthly · no free trial",
                symbol: "creditcard"
            ) { showPaywall = true }
        }
    }

    private var protocolSection: some View {
        SettingsGroup(title: "Protocol") {
            SettingsRow(
                title: "Your peptides",
                detail: store.journal.protocolPeptides.isEmpty
                    ? "Add the schedules you follow"
                    : "\(store.journal.protocolPeptides.count) tracked",
                symbol: "list.bullet.rectangle.portrait"
            ) { showPeptides = true }
        }
    }

    private var preferences: some View {
        SettingsGroup(title: "Preferences") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weight unit").font(.system(.body, weight: .medium)).foregroundStyle(SetupTheme.ink)
                    Text(store.journal.weightUnit == .kg ? "Kilograms" : "Pounds")
                        .font(.caption).foregroundStyle(SetupTheme.muted)
                }
                Spacer()
                SetupUnitToggle(
                    left: "kg",
                    right: "lb",
                    isRight: Binding(
                        get: { store.journal.weightUnit == .lb },
                        set: { value in store.updateJournal { $0.weightUnit = value ? .lb : .kg } }
                    )
                )
                .frame(width: 140)
            }
            .frame(minHeight: 52)
            .accessibilityIdentifier("settings.weightUnit")

            SettingsDivider()

            Toggle(isOn: Binding(
                get: { store.journal.showWeight },
                set: { value in store.updateJournal { $0.showWeight = value } }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show weight in Progress").font(.system(.body, weight: .medium)).foregroundStyle(SetupTheme.ink)
                    Text("Hiding weight keeps existing records.").font(.caption).foregroundStyle(SetupTheme.muted)
                }
            }
            .tint(SetupTheme.ink)
            .frame(minHeight: 52)
            .accessibilityIdentifier("settings.showWeight")
        }
    }

    private var remindersSection: some View {
        SettingsGroup(title: "Reminders") { ReminderSettingsView() }
    }

    private var data: some View {
        SettingsGroup(title: "Your data") {
            SettingsRow(title: "Privacy & your data", symbol: "lock") { showPrivacy = true }
            SettingsDivider()
            SettingsRow(title: "Backup & restore", symbol: "externaldrive") { showBackup = true }
            SettingsDivider()
            ShareLink(item: store.exportText, preview: SharePreview("Along export")) {
                SettingsRowLabel(title: "Export a readable copy", symbol: "square.and.arrow.up")
            }
            .buttonStyle(.plain)
            SettingsDivider()
            SettingsRow(title: store.accountID == nil ? "Delete on-device journal" : "Delete this account’s local data", symbol: "trash", destructive: true) {
                confirmDelete = true
            }
        }
    }

    private var about: some View {
        SettingsGroup(title: "About") {
            SettingsInfoRow(
                title: "Version",
                detail: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—",
                symbol: "info.circle"
            )
            if let config = billing.configuration.value {
                SettingsDivider()
                Link(destination: config.termsURL) {
                    SettingsRowLabel(title: "Terms of use", symbol: "doc.text")
                }
                SettingsDivider()
                Link(destination: config.privacyURL) {
                    SettingsRowLabel(title: "Privacy policy", symbol: "hand.raised")
                }
            } else {
                SettingsDivider()
                SettingsRow(title: "Terms of use", symbol: "doc.text") { showPrivacy = true }
                SettingsDivider()
                SettingsRow(title: "Privacy policy", symbol: "hand.raised") { showPrivacy = true }
            }
        }
    }

    private var disclaimer: some View {
        Text("Along is a peptide protocol tracker for adults. It never recommends peptides, doses or schedules, and it is not medical advice. Records stay on this iPhone, with optional cloud backup when you’re signed in.")
            .font(.caption)
            .foregroundStyle(SetupTheme.muted)
            .padding(.top, 4)
    }

    private func deleteLocalData() {
        Task {
            if reminders.deliveryEnabled, !(await reminders.reset()) {
                store.error = "Reminders could not be removed. Your protocol has been kept. Please try deleting again."
                return
            }
            store.clearJournal()
        }
    }
}

struct AccountBackupChoice: View {
    @Environment(CloudSync.self) private var sync
    @State private var choose = false

    var body: some View {
        Button("Choose which journal to keep") { choose = true }
            .frame(maxWidth: .infinity, minHeight: 44)
            .confirmationDialog("Which journal should Along keep?", isPresented: $choose) {
                Button("Use account backup", role: .destructive) { sync.resolveConflict(useAccount: true) }
                Button("Use this iPhone’s journal", role: .destructive) { sync.resolveConflict(useAccount: false) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The version you choose will replace the other copy. You can export this iPhone’s journal from Backup & restore first.")
            }
    }
}

private struct SettingsGroup<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SetupTheme.muted)
                .padding(.leading, 4)
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SetupTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(SetupTheme.border))
        }
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(SetupTheme.border.opacity(0.85))
            .frame(height: 1)
            .padding(.leading, 44)
    }
}

private struct SettingsRow: View {
    var title: String
    var detail: String? = nil
    var symbol: String
    var destructive = false
    var showsChevron = true
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            SettingsRowLabel(title: title, detail: detail, symbol: symbol, destructive: destructive, showsChevron: showsChevron)
        }
        .buttonStyle(SetupPressStyle())
    }
}

private struct SettingsInfoRow: View {
    var title: String
    var detail: String? = nil
    var symbol: String
    var body: some View {
        SettingsRowLabel(title: title, detail: detail, symbol: symbol, showsChevron: false)
    }
}

private struct SettingsRowLabel: View {
    var title: String
    var detail: String? = nil
    var symbol: String
    var destructive = false
    var showsChevron = true
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(destructive ? Color.red : SetupTheme.ink)
                .frame(width: 32, height: 32)
                .background((destructive ? Color.red.opacity(0.1) : SetupTheme.tile), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, weight: .medium))
                    .foregroundStyle(destructive ? Color.red : SetupTheme.ink)
                    .multilineTextAlignment(.leading)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(SetupTheme.muted)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 8)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SetupTheme.muted)
            }
        }
        .frame(minHeight: 52)
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
                    privacyBlock(
                        title: "Your protocol stays with you",
                        body: "Your peptides, dose logs, notes, optional weight records and setup answers are stored in this app’s private device storage, protected by iOS file protection. When you’re signed in, Along can also keep a cloud backup under your account so you can restore on another device."
                    )
                    privacyBlock(
                        title: "Copies you choose to save",
                        body: "A readable export and a restorable backup contain the records you created. Backup files are unencrypted. Review the destination before sharing. Delete all local data clears this iPhone only — it does not cancel an App Store subscription or remove a cloud backup until you sign in and overwrite it."
                    )
                    privacyBlock(
                        title: "Reminders & membership",
                        body: billing.isConfigured
                            ? "Reminders are optional local notifications. They show the peptide name and amount you set, never notes or injection sites. Apple processes subscriptions. Superwall supports membership purchases when configured."
                            : "Reminders are optional local notifications with no health notes. Membership purchases are not configured in this build."
                    )
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
