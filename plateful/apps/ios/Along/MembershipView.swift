import SwiftUI

extension OnboardingPlan {
    var billingPlan: BillingPlan { self == .annual ? .annual : .monthly }
}

struct BillingAvailabilityView: View {
    @Environment(BillingStore.self) private var billing
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !billing.isConfigured {
                SetupNote(text: "Membership purchases aren’t available in this build. Your saved entries are safe and no payment will be taken.", symbol: "info.circle")
            } else if billing.catalogState == .loading {
                ProgressView("Loading App Store plans…").font(.subheadline)
            } else if case .failed = billing.catalogState {
                SetupNote(text: "We couldn’t load your App Store plans. Check your connection and try again.", symbol: "wifi.exclamationmark")
                Button("Reload plans") { Task { await billing.loadProducts() } }.frame(minHeight: 44)
            }
            if let notice = billing.notice {
                Text(notice).font(.subheadline).foregroundStyle(Theme.secondaryInk)
                    .accessibilityIdentifier("membership.notice")
            }
        }
    }
}

struct MembershipLegalLinks: View {
    @Environment(BillingStore.self) private var billing
    @State private var privacy = false
    @State private var terms = false
    var compact = false
    var body: some View {
        HStack(spacing: compact ? 18 : 24) {
            if let config = billing.configuration.value {
                Link("Terms", destination: config.termsURL)
                Link("Privacy", destination: config.privacyURL)
            } else {
                Button("Terms") { terms = true }
                Button("Privacy") { privacy = true }
            }
        }.font(compact ? .caption : .subheadline).frame(maxWidth: compact ? nil : .infinity, minHeight: compact ? 32 : 44)
            .sheet(isPresented: $privacy) { PrivacyView() }
            .sheet(isPresented: $terms) { MembershipTermsView() }
    }
}

struct MembershipView: View {
    @Environment(JournalStore.self) private var store
    @Environment(BillingStore.self) private var billing
    @Environment(\.dismiss) private var dismiss
    @State private var plan: OnboardingPlan = .annual
    @State private var backup = false
    @State private var localData = false
    var canClose = true
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(SetupTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .background(SetupTheme.tile, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    Text(billing.isEntitled ? "Your protocol stays organised." : "Keep your protocol organised.").font(.system(size: 32, weight: .bold)).tracking(-0.6)
                    if billing.isEntitled {
                        Label(billing.isTestPurchase ? "Test membership active" : "Membership active", systemImage: "checkmark.seal.fill")
                            .font(.headline).foregroundStyle(SetupTheme.ink)
                        Text("Dose logging, reminders and progress are included. Manage renewal or cancellation with the App Store.").foregroundStyle(SetupTheme.muted)
                    } else {
                        Text("One place for every peptide, dose, reminder and note. No free trial.").foregroundStyle(SetupTheme.muted)
                        Pill(text: "No free trial", symbol: "checkmark")
                        MembershipPlans(selection: $plan)
                        MembershipDisclosure(plan: plan)
                        PrimaryButton(title: billing.isBusy ? "Please wait…" : billing.product(for: plan.billingPlan).map { "Subscribe for \($0.priceWithPeriod)" } ?? "Purchases unavailable", symbol: "lock.open") {
                            Task { await billing.purchase(plan: plan.billingPlan) }
                        }.disabled(!billing.canPurchase).opacity(billing.canPurchase ? 1 : 0.5)
                    }
                    BillingAvailabilityView()
                    Button(billing.isBusy ? "Please wait…" : "Restore purchases") { Task { await billing.restore() } }
                        .frame(maxWidth: .infinity, minHeight: 44).disabled(billing.isBusy)
                        .accessibilityIdentifier("membership.restore")
                    if billing.isConfigured {
                        Button("Manage App Store subscription") {
                            guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
                            Task { await billing.manageSubscriptions(in: scene) }
                        }.frame(maxWidth: .infinity, minHeight: 44).disabled(billing.isBusy)
                    }
                    MembershipLegalLinks()
                    if !canClose {
                        Divider()
                        Button("Your data & reminders") { localData = true }.frame(maxWidth: .infinity, minHeight: 44)
                        Text("Your protocol remains on this device. You can export your records without an active membership.").font(.caption).foregroundStyle(SetupTheme.muted)
                        Button("Backup & restore") { backup = true }.frame(maxWidth: .infinity, minHeight: 44)
                        ShareLink(item: store.exportText, preview: SharePreview("Along export")) {
                            Label("Export my records", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                }.padding(24).frame(maxWidth: 560)
            }.frame(maxWidth: .infinity).pageBackground().navigationTitle("Along membership").navigationBarTitleDisplayMode(.inline)
                .toolbar { if canClose { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } } }
                .sheet(isPresented: $backup) { JournalBackupView(journal: { store.journal }, replace: store.restoreJournal) }
                .sheet(isPresented: $localData) { LocalDataView() }
                .onAppear { plan = store.journal.setupProfile?.plan ?? store.journal.onboardingPreferences?.plan ?? .annual }
        }
    }
}

typealias PaywallPreview = MembershipView

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
                AlongSection(title: "Your protocol") { Text("Your saved peptides and dose logs remain on this device. Along is a tracker, not medical advice, and never recommends a dose or schedule.") }
                }.padding(22).frame(maxWidth: 650)
            }.frame(maxWidth: .infinity).pageBackground().navigationTitle("Membership terms").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
