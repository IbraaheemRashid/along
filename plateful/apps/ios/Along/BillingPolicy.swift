import Foundation

/// Only constructed from verified StoreKit results by BillingStore. Never persisted as a paid flag.
struct BillingEntitlement: Equatable, Sendable {
    let productID: String
    let expirationDate: Date
    let isInGracePeriod: Bool
    let environment: Environment

    enum Environment: String, Sendable { case production, sandbox, xcode }
    func isActive(at date: Date) -> Bool { expirationDate > date }
}

/// Pure rules shared by transaction processing and the billing regression checks.
enum BillingPolicy {
    enum RenewalState: Sendable { case subscribed, gracePeriod, billingRetry, expired, revoked, unknown }

    struct Evidence: Sendable {
        var productID: String
        var isVerified: Bool
        var isAutoRenewable: Bool
        var expirationDate: Date?
        var revocationDate: Date?
        var isUpgraded: Bool
        var renewalState: RenewalState
        var renewalInfoVerified: Bool
        var gracePeriodExpirationDate: Date?
        var environment: BillingEntitlement.Environment
    }

    static func entitlement(from evidence: Evidence, allowedIDs: Set<String>,
                            allowXcode: Bool, now: Date) -> BillingEntitlement? {
        guard evidence.isVerified, evidence.isAutoRenewable,
              allowedIDs.contains(evidence.productID), evidence.revocationDate == nil,
              !evidence.isUpgraded, allowXcode || evidence.environment != .xcode else { return nil }
        let end: Date
        let grace: Bool
        switch evidence.renewalState {
        case .subscribed:
            guard let expiry = evidence.expirationDate, expiry > now else { return nil }
            end = expiry
            grace = false
        case .gracePeriod:
            guard evidence.renewalInfoVerified, let expiry = evidence.gracePeriodExpirationDate,
                  expiry > now else { return nil }
            end = expiry
            grace = true
        case .billingRetry, .expired, .revoked, .unknown:
            return nil
        }
        return .init(productID: evidence.productID, expirationDate: end,
                     isInGracePeriod: grace, environment: evidence.environment)
    }

    static func strongest(_ entitlements: [BillingEntitlement], now: Date) -> BillingEntitlement? {
        entitlements.filter { $0.isActive(at: now) }.max { $0.expirationDate < $1.expirationDate }
    }
}

enum BillingOutcome: Equatable, Sendable {
    case purchased, cancelled, pending, restored, nothingToRestore
    case failed(String)
}

enum BillingOperation: Equatable, Sendable {
    case idle, purchasing(BillingPlan), restoring, managing
}

struct BillingProduct: Identifiable, Equatable, Sendable {
    let plan: BillingPlan
    let productID: String
    let displayName: String
    let displayPrice: String
    var id: String { productID }
    var priceWithPeriod: String { "\(displayPrice)/\(plan.periodLabel)" }
}

enum BillingCatalogState: Equatable, Sendable {
    case unavailable, loading, ready, failed(String)
}

enum BillingFailure: LocalizedError {
    case unavailable, busy, productUnavailable, unverified, noActivePurchase, unsupportedProduct, trialConfigured
    var errorDescription: String? {
        switch self {
        case .unavailable: return "Membership purchases aren’t available yet. Please try again later."
        case .busy: return "Another App Store action is already in progress."
        case .productUnavailable: return "This membership isn’t available from the App Store right now. Please try again."
        case .unverified: return "The App Store purchase couldn’t be verified. Please try Restore Purchases."
        case .noActivePurchase: return "The App Store hasn’t confirmed an active membership yet. Please try Restore Purchases."
        case .unsupportedProduct: return "The App Store membership configuration needs attention. Please try again later."
        case .trialConfigured: return "This membership’s offer needs updating before it can be purchased."
        }
    }
}
