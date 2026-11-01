import Foundation
import Observation
import StoreKit
import UIKit

/// StoreKit's verified transactions are the only source of paid access on this device.
/// A paywall dismissal, onboarding flag, or Superwall test-mode grant cannot unlock Along.
@MainActor @Observable
final class BillingStore {
    let configuration: BillingConfiguration.State
    private(set) var hasCheckedEntitlements = false
    private(set) var entitlement: BillingEntitlement?
    private(set) var catalogState: BillingCatalogState = .unavailable
    private(set) var products: [BillingProduct] = []
    private(set) var operation: BillingOperation = .idle
    private(set) var notice: String?
    private(set) var isRefreshing = false
    private(set) var isDispatchingPurchase = false

    var isEntitled: Bool { entitlement?.isActive(at: Date()) == true }
    var isBusy: Bool { operation != .idle || isDispatchingPurchase }
    var canPurchase: Bool { configuration.value != nil && catalogState == .ready && !isBusy }
    var isConfigured: Bool { configuration.value != nil }
    var isTestPurchase: Bool { entitlement.map { $0.environment != .production } ?? false }

    @ObservationIgnored private var storeProducts: [String: Product] = [:]
    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var expirationTask: Task<Void, Never>?
    @ObservationIgnored private var refreshGeneration = 0
    @ObservationIgnored private var catalogGeneration = 0
    @ObservationIgnored private var started = false
    @ObservationIgnored private var executingStorePurchase = false
    @ObservationIgnored private var superwall: SuperwallBillingBridge?

    init(configuration: BillingConfiguration.State = BillingConfiguration.load()) {
        if !SuperwallBillingBridge.isAvailable, case .ready = configuration {
            self.configuration = .unconfigured(["The SuperwallKit package is not linked to the app target"])
        } else {
            self.configuration = configuration
        }
    }

    deinit {
        updatesTask?.cancel()
        expirationTask?.cancel()
    }

    /// Call once from the app's root task. This never prompts for App Store authentication.
    func start() async {
        guard !started else { return }
        started = true
        guard let config = configuration.value else {
            hasCheckedEntitlements = true
            return
        }
        superwall = SuperwallBillingBridge(store: self, configuration: config)
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard !Task.isCancelled else { return }
                await self?.receive(update)
            }
        }
        // Entitlements must remain available when the product catalog cannot load.
        async let catalog: Void = loadProducts()
        await refresh()
        await catalog
    }

    /// Call when the scene becomes active, including after subscription management.
    func refresh() async {
        guard let config = configuration.value else {
            entitlement = nil
            hasCheckedEntitlements = true
            return
        }
        refreshGeneration += 1
        let generation = refreshGeneration
        isRefreshing = true
        var candidates: [BillingEntitlement] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  config.productIDs.contains(transaction.productID) else { continue }
            if let candidate = await verifiedEntitlement(for: transaction, allowedIDs: config.productIDs) {
                candidates.append(candidate)
            }
        }
        guard generation == refreshGeneration else { return }
        setEntitlement(BillingPolicy.strongest(candidates, now: Date()))
        hasCheckedEntitlements = true
        isRefreshing = false
        superwall?.synchronizeStatus()
    }

    func loadProducts() async {
        guard let config = configuration.value else { return }
        catalogGeneration += 1
        let generation = catalogGeneration
        catalogState = .loading
        do {
            let fetched = try await Product.products(for: config.productIDs)
            guard Set(fetched.map(\.id)) == config.productIDs else { throw BillingFailure.productUnavailable }
            var groupIDs: Set<String> = []
            for product in fetched {
                guard let plan = config.plan(for: product.id) else { throw BillingFailure.unsupportedProduct }
                try validate(product, plan: plan)
                if let group = product.subscription?.subscriptionGroupID { groupIDs.insert(group) }
            }
            guard groupIDs.count == 1 else { throw BillingFailure.unsupportedProduct }
            guard generation == catalogGeneration else { return }
            storeProducts = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
            products = BillingPlan.allCases.compactMap { plan in
                guard let product = storeProducts[config.productID(for: plan)] else { return nil }
                return BillingProduct(plan: plan, productID: product.id, displayName: product.displayName,
                                      displayPrice: product.displayPrice)
            }
            catalogState = .ready
        } catch {
            guard generation == catalogGeneration else { return }
            storeProducts = [:]
            products = []
            catalogState = .failed(error.localizedDescription)
        }
    }

    /// Native SwiftUI paywall purchases still pass through Superwall for the named billing stack.
    @discardableResult
    func purchase(plan: BillingPlan) async -> BillingOutcome {
        guard !isBusy else { return report(.failed(BillingFailure.busy.localizedDescription)) }
        guard let config = configuration.value, let superwall,
              let product = storeProducts[config.productID(for: plan)], catalogState == .ready else {
            return report(.failed(BillingFailure.unavailable.localizedDescription))
        }
        isDispatchingPurchase = true
        defer { isDispatchingPurchase = false }
        notice = nil
        let outcome = await superwall.purchase(product)
        return report(outcome)
    }

    /// Used exclusively by Superwall's PurchaseController. Never call Superwall again from here.
    func purchaseFromController(productID: String) async -> BillingOutcome {
        guard !executingStorePurchase, operation == .idle else {
            return report(.failed(BillingFailure.busy.localizedDescription))
        }
        guard let config = configuration.value, let plan = config.plan(for: productID) else {
            return report(.failed(BillingFailure.unsupportedProduct.localizedDescription))
        }
        executingStorePurchase = true
        operation = .purchasing(plan)
        defer { executingStorePurchase = false; operation = .idle }
        do {
            // Re-fetch before charging: don't rely on a stale price / offer catalog.
            guard let product = try await Product.products(for: [productID]).first else {
                throw BillingFailure.productUnavailable
            }
            try validate(product, plan: plan)
            let result = try await product.purchase()
            switch result {
            case .success(.verified(let transaction)):
                guard config.productIDs.contains(transaction.productID) else { throw BillingFailure.unverified }
                await refresh()
                // Verified transactions are finished even if expired/revoked; they never grant access.
                await transaction.finish()
                guard isEntitled else { throw BillingFailure.noActivePurchase }
                return report(.purchased)
            case .success(.unverified): throw BillingFailure.unverified
            case .pending: return report(.pending)
            case .userCancelled: return report(.cancelled)
            @unknown default: throw BillingFailure.unverified
            }
        } catch {
            if Self.isCancellation(error) { return report(.cancelled) }
            return report(.failed(error.localizedDescription))
        }
    }

    /// Only call in response to a Restore Purchases action. sync() can show an Apple sign-in prompt.
    @discardableResult
    func restore() async -> BillingOutcome {
        guard !isBusy else { return report(.failed(BillingFailure.busy.localizedDescription)) }
        guard isConfigured else { return report(.failed(BillingFailure.unavailable.localizedDescription)) }
        operation = .restoring
        notice = nil
        defer { operation = .idle }
        do {
            try await AppStore.sync()
            await refresh()
            return report(isEntitled ? .restored : .nothingToRestore)
        } catch {
            if Self.isCancellation(error) { return report(.cancelled) }
            return report(.failed(error.localizedDescription))
        }
    }

    func manageSubscriptions(in scene: UIWindowScene) async {
        guard !isBusy else { return }
        operation = .managing
        defer { operation = .idle }
        do {
            try await AppStore.showManageSubscriptions(in: scene)
            await refresh()
        } catch {
            if !Self.isCancellation(error) { notice = error.localizedDescription }
        }
    }

    func clearNotice() { notice = nil }
    func product(for plan: BillingPlan) -> BillingProduct? { products.first { $0.plan == plan } }

    private func validate(_ product: Product, plan: BillingPlan) throws {
        guard product.type == .autoRenewable, let subscription = product.subscription,
              subscription.subscriptionPeriod.value == 1,
              subscription.subscriptionPeriod.unit == (plan == .annual ? .year : .month) else {
            throw BillingFailure.unsupportedProduct
        }
        // A free trial must not silently appear for an eligible customer. No intro offer of any kind.
        guard subscription.introductoryOffer == nil else { throw BillingFailure.trialConfigured }
        guard !subscription.promotionalOffers.contains(where: { $0.paymentMode == .freeTrial }) else {
            throw BillingFailure.trialConfigured
        }
        if #available(iOS 18.0, *), subscription.winBackOffers.contains(where: { $0.paymentMode == .freeTrial }) {
            throw BillingFailure.trialConfigured
        }
    }

    private func receive(_ result: VerificationResult<Transaction>) async {
        guard let config = configuration.value else { return }
        switch result {
        case .verified(let transaction) where config.productIDs.contains(transaction.productID):
            await refresh()
            await transaction.finish()
            if isEntitled { notice = nil }
        case .unverified:
            // Never finish an unverified transaction or interpret its unsafe payload as an entitlement.
            await refresh()
        default: break
        }
    }

    private func verifiedEntitlement(for transaction: Transaction, allowedIDs: Set<String>) async -> BillingEntitlement? {
        let environment: BillingEntitlement.Environment
        switch transaction.environment {
        case .production: environment = .production
        case .sandbox: environment = .sandbox
        case .xcode: environment = .xcode
        default: return nil
        }
        var renewal: BillingPolicy.RenewalState = .subscribed
        var renewalVerified = false
        var graceExpiry: Date?
        if let status = await transaction.subscriptionStatus {
            // Status can include another transaction in the group. Require the same verified transaction.
            guard case .verified(let statusTransaction) = status.transaction,
                  statusTransaction.id == transaction.id else { return nil }
            switch status.state {
            case .subscribed: renewal = .subscribed
            case .inGracePeriod: renewal = .gracePeriod
            case .inBillingRetryPeriod: renewal = .billingRetry
            case .expired: renewal = .expired
            case .revoked: renewal = .revoked
            default: renewal = .unknown
            }
            if case .verified(let info) = status.renewalInfo {
                renewalVerified = true
                graceExpiry = info.gracePeriodExpirationDate
            }
        }
        // No status/network response: an unexpired verified current entitlement is sufficient.
        // An expired transaction needs verified grace-period evidence and can never use this fallback.
        let evidence = BillingPolicy.Evidence(productID: transaction.productID, isVerified: true,
            isAutoRenewable: transaction.productType == .autoRenewable, expirationDate: transaction.expirationDate,
            revocationDate: transaction.revocationDate, isUpgraded: transaction.isUpgraded,
            renewalState: renewal, renewalInfoVerified: renewalVerified,
            gracePeriodExpirationDate: graceExpiry, environment: environment)
        #if DEBUG
        let allowXcode = true
        #else
        let allowXcode = false
        #endif
        return BillingPolicy.entitlement(from: evidence, allowedIDs: allowedIDs, allowXcode: allowXcode, now: Date())
    }

    private func setEntitlement(_ value: BillingEntitlement?) {
        expirationTask?.cancel()
        entitlement = value
        guard let value else { return }
        expirationTask = Task { [weak self] in
            let seconds = max(0, value.expirationDate.timeIntervalSinceNow)
            do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
            guard !Task.isCancelled, let self else { return }
            self.entitlement = nil
            self.superwall?.synchronizeStatus()
            await self.refresh()
        }
    }

    @discardableResult private func report(_ outcome: BillingOutcome) -> BillingOutcome {
        switch outcome {
        case .purchased: notice = nil
        case .cancelled: notice = nil
        case .pending: notice = "Your purchase is awaiting App Store approval. Membership will unlock when Apple confirms it."
        case .restored: notice = "Your membership has been restored."
        case .nothingToRestore: notice = "No active Along membership was found for this Apple Account."
        case .failed(let message): notice = message
        }
        return outcome
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let error = error as? StoreKitError, case .userCancelled = error { return true }
        return (error as? SKError)?.code == .paymentCancelled
    }
}
