import Foundation

@main struct BillingTests {
    static func main() {
        var count = 0
        func expect(_ condition: Bool, _ message: String) {
            precondition(condition, message)
            count += 1
        }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let ids: Set<String> = ["app.along.yearly", "app.along.monthly"]
        let base = BillingPolicy.Evidence(productID: "app.along.yearly", isVerified: true,
            isAutoRenewable: true, expirationDate: now.addingTimeInterval(3600), revocationDate: nil,
            isUpgraded: false, renewalState: .subscribed, renewalInfoVerified: true,
            gracePeriodExpirationDate: nil, environment: .production)
        func evaluate(_ change: (inout BillingPolicy.Evidence) -> Void = { _ in }, allowXcode: Bool = false) -> BillingEntitlement? {
            var evidence = base
            change(&evidence)
            return BillingPolicy.entitlement(from: evidence, allowedIDs: ids, allowXcode: allowXcode, now: now)
        }

        expect(evaluate()?.productID == base.productID, "A verified unexpired configured subscription grants access")
        expect(evaluate { $0.renewalInfoVerified = false } != nil, "A verified unexpired transaction works offline without renewal metadata")
        expect(evaluate { $0.isVerified = false } == nil, "An unverified purchase never unlocks membership")
        expect(evaluate { $0.productID = "other.app.yearly" } == nil, "Another product cannot unlock Along")
        expect(evaluate { $0.isAutoRenewable = false } == nil, "A non-consumable or consumable cannot masquerade as membership")
        expect(evaluate { $0.revocationDate = now } == nil, "A refunded transaction immediately loses access")
        expect(evaluate { $0.isUpgraded = true } == nil, "An upgraded old plan cannot keep access alive")
        expect(evaluate { $0.expirationDate = now } == nil, "The exact expiry boundary is inactive")
        expect(evaluate { $0.expirationDate = now.addingTimeInterval(-1) } == nil, "An expired transaction is not a cached paid flag")
        expect(evaluate { $0.expirationDate = nil } == nil, "Missing subscription expiry fails closed")
        for renewal in [BillingPolicy.RenewalState.billingRetry, .expired, .revoked, .unknown] {
            expect(evaluate { $0.renewalState = renewal } == nil, "A non-entitling renewal state cannot reuse an old expiry")
        }
        let grace = evaluate {
            $0.expirationDate = now.addingTimeInterval(-10)
            $0.renewalState = .gracePeriod
            $0.gracePeriodExpirationDate = now.addingTimeInterval(7200)
        }
        expect(grace?.isInGracePeriod == true, "A verified billing grace period continues service")
        expect(grace?.expirationDate == now.addingTimeInterval(7200), "Grace uses its own verified end, not the expired billing period")
        expect(evaluate {
            $0.renewalState = .gracePeriod
            $0.renewalInfoVerified = false
            $0.gracePeriodExpirationDate = now.addingTimeInterval(7200)
        } == nil, "Unsigned grace information cannot extend membership")
        expect(evaluate { $0.renewalState = .gracePeriod } == nil, "Missing grace end fails closed")
        expect(evaluate {
            $0.renewalState = .gracePeriod; $0.gracePeriodExpirationDate = now
        } == nil, "Expired grace does not extend access")
        expect(evaluate { $0.environment = .sandbox } != nil, "Verified Apple Sandbox transactions support TestFlight")
        expect(evaluate { $0.environment = .xcode } == nil, "Release policy rejects local Xcode StoreKit purchases")
        expect(evaluate({ $0.environment = .xcode }, allowXcode: true)?.environment == .xcode,
               "Explicit development policy marks local StoreKit transactions as Xcode")
        expect(BillingPolicy.strongest([], now: now) == nil, "An empty fresh entitlement snapshot locks access")
        let active = evaluate()!
        expect(!active.isActive(at: active.expirationDate), "In-memory access also checks the clock")
        let expired = BillingEntitlement(productID: base.productID, expirationDate: now, isInGracePeriod: false, environment: .production)
        expect(BillingPolicy.strongest([expired, active], now: now) == active, "An expired plan cannot hide another active membership")
        expect(BillingPolicy.strongest([active, grace!], now: now) == grace, "The longest valid entitlement wins when plans overlap")

        let values: [String: Any] = [
            "ALONG_BILLING_ANNUAL_PRODUCT_ID": "app.along.yearly",
            "ALONG_BILLING_MONTHLY_PRODUCT_ID": "app.along.monthly",
            "ALONG_SUPERWALL_PUBLIC_KEY": "pk_public_configuration_fixture",
            "ALONG_BILLING_ENTITLEMENT_ID": "membership",
            "ALONG_TERMS_URL": "https://along.test/terms",
            "ALONG_PRIVACY_URL": "https://along.test/privacy"
        ]
        expect(BillingConfiguration.load(values: values).value?.productIDs == ids, "Complete public configuration maps only the two approved products")
        expect(BillingConfiguration.load(values: [:]).value == nil, "A clean install with no keys remains unconfigured")
        for key in values.keys {
            var missing = values
            missing.removeValue(forKey: key)
            expect(BillingConfiguration.load(values: missing).value == nil, "Every required billing setting must be configured: \(key)")
        }
        for placeholder in ["", "  ", "$(ANNUAL_PRODUCT_ID)", "${ANNUAL_PRODUCT_ID}", "REPLACE_ME", "your_product", "com.example.yearly"] {
            var invalid = values
            invalid["ALONG_BILLING_ANNUAL_PRODUCT_ID"] = placeholder
            expect(BillingConfiguration.load(values: invalid).value == nil, "Placeholders cannot enable production purchases")
        }
        var invalid = values
        invalid["ALONG_BILLING_MONTHLY_PRODUCT_ID"] = values["ALONG_BILLING_ANNUAL_PRODUCT_ID"]
        expect(BillingConfiguration.load(values: invalid).value == nil, "Two price buttons cannot map to the same SKU")
        invalid = values; invalid["ALONG_BILLING_ANNUAL_PRODUCT_ID"] = "app.along annual"
        expect(BillingConfiguration.load(values: invalid).value == nil, "Malformed product identifiers fail closed")
        for url in ["http://along.test/terms", "https://localhost/terms", "not-a-url", "https://user:secret@along.test/terms"] {
            invalid = values; invalid["ALONG_TERMS_URL"] = url
            expect(BillingConfiguration.load(values: invalid).value == nil, "Legal URLs must be public HTTPS without credentials")
        }
        let configuration = BillingConfiguration.load(values: values).value!
        expect(configuration.plan(for: "other") == nil, "Remote Superwall products outside the allowlist cannot choose a plan")
        expect(configuration.productID(for: .annual) != configuration.productID(for: .monthly), "Annual and monthly map independently")
        print("\(count) billing checks passed")
    }
}
