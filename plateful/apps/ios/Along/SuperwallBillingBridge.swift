import Foundation
import StoreKit

#if canImport(SuperwallKit)
import SuperwallKit

/// Superwall coordinates purchases; the custom controller verifies and delivers access.
/// Nothing reads Superwall's subscriptionStatus to decide whether the journal is unlocked.
@MainActor
final class SuperwallBillingBridge: PurchaseController {
    static let isAvailable = true
    private weak var store: BillingStore?
    private let configuration: BillingConfiguration

    init(store: BillingStore, configuration: BillingConfiguration) {
        self.store = store
        self.configuration = configuration
        if configuration.usesSuperwallDashboard {
            let options = SuperwallOptions()
            options.storeKitVersion = .storeKit2
            options.testModeBehavior = .never
            // Dashboard paywalls and price experiments need Superwall's own events.
            // Advertising/ATT integrations stay off until attribution is approved.
            options.eventTrackingBehavior = .superwallOnly
            options.logging.level = .error
            Superwall.configure(apiKey: configuration.superwallPublicKey, purchaseController: self, options: options)
            synchronizeStatus()
        }
    }

    /// Presents the Superwall dashboard paywall for A/B price tests. Falls back
    /// to false when Superwall is not configured so the SwiftUI paywall can show.
    @discardableResult
    func presentOnboardingPaywall() async -> Bool {
        guard configuration.usesSuperwallDashboard else { return false }
        if Superwall.shared.configurationStatus == .failed {
            await Superwall.shared.refreshConfiguration()
        }
        guard Superwall.shared.configurationStatus == .configured else { return false }
        return await withCheckedContinuation { continuation in
            var resumed = false
            Superwall.shared.register(placement: BillingConfiguration.onboardingPlacement) {
                if !resumed { resumed = true; continuation.resume(returning: true) }
            }
            // If Superwall skips the paywall (no assignment), still report presented=false
            // so Along can show the native fallback. Wait briefly for a presentation.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                if !resumed { resumed = true; continuation.resume(returning: Superwall.shared.isPaywallPresented) }
            }
        }
    }

    /// Direct StoreKit purchase when the local StoreKit configuration is in use.
    func purchaseLocally(_ product: StoreKit.Product) async -> BillingOutcome {
        await store?.purchaseFromController(productID: product.id) ?? .failed(BillingFailure.unavailable.localizedDescription)
    }

    func synchronizeStatus() {
        guard configuration.usesSuperwallDashboard, let store else { return }
        if !store.hasCheckedEntitlements {
            Superwall.shared.subscriptionStatus = .unknown
        } else if store.isEntitled {
            Superwall.shared.subscriptionStatus = .active([Entitlement(id: configuration.entitlementID)])
        } else {
            Superwall.shared.subscriptionStatus = .inactive
        }
    }

    func purchase(_ product: StoreKit.Product) async -> BillingOutcome {
        guard configuration.usesSuperwallDashboard else {
            return await purchaseLocally(product)
        }
        if Superwall.shared.configurationStatus == .failed {
            await Superwall.shared.refreshConfiguration()
        }
        guard Superwall.shared.configurationStatus == .configured else {
            return .failed("The membership service couldn’t connect yet. Check your connection and try again.")
        }
        let result = await Superwall.shared.purchase(product)
        switch result {
        case .purchased:
            // Dashboard grants, a skipped paywall, and test-mode purchase results are never authority.
            await store?.refresh()
            return store?.isEntitled == true ? .purchased : .failed(BillingFailure.noActivePurchase.localizedDescription)
        case .cancelled: return .cancelled
        case .pending: return .pending
        case .failed(let error): return .failed(error.localizedDescription)
        }
    }

    func purchase(product: StoreProduct) async -> PurchaseResult {
        guard let store else { return .failed(BillingFailure.unavailable) }
        let outcome = await store.purchaseFromController(productID: product.productIdentifier)
        synchronizeStatus()
        switch outcome {
        case .purchased: return .purchased
        case .cancelled: return .cancelled
        case .pending: return .pending
        case .failed(let message): return .failed(ControllerError(message: message))
        default: return .failed(BillingFailure.noActivePurchase)
        }
    }

    func restorePurchases() async -> RestorationResult {
        guard let store else { return .failed(BillingFailure.unavailable) }
        let outcome = await store.restore()
        synchronizeStatus()
        switch outcome {
        case .restored, .nothingToRestore: return .restored
        case .failed(let message): return .failed(ControllerError(message: message))
        case .cancelled: return .failed(StoreKitError.userCancelled)
        default: return .failed(BillingFailure.noActivePurchase)
        }
    }

    private struct ControllerError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
}
#else
/// Buildable before the package is installed, but deliberately unable to sell or grant membership.
@MainActor
final class SuperwallBillingBridge {
    static let isAvailable = false
    init(store: BillingStore, configuration: BillingConfiguration) {}
    func synchronizeStatus() {}
    @discardableResult func presentOnboardingPaywall() async -> Bool { false }
    func purchase(_ product: Product) async -> BillingOutcome {
        .failed(BillingFailure.unavailable.localizedDescription)
    }
}
#endif
