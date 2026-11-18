import Foundation

enum BillingPlan: String, CaseIterable, Identifiable, Sendable {
    case annual, monthly
    var id: String { rawValue }
    var title: String { self == .annual ? "Yearly" : "Monthly" }
    var periodLabel: String { self == .annual ? "year" : "month" }
}

/// Public identifiers only. App Store / Superwall secret keys never belong in the app.
struct BillingConfiguration: Equatable, Sendable {
    let annualProductID: String
    let monthlyProductID: String
    let superwallPublicKey: String
    let entitlementID: String
    let termsURL: URL
    let privacyURL: URL

    var productIDs: Set<String> { [annualProductID, monthlyProductID] }
    func productID(for plan: BillingPlan) -> String {
        plan == .annual ? annualProductID : monthlyProductID
    }
    func plan(for productID: String) -> BillingPlan? {
        BillingPlan.allCases.first { self.productID(for: $0) == productID }
    }

    enum State: Equatable, Sendable {
        case unconfigured([String])
        case ready(BillingConfiguration)

        var value: BillingConfiguration? {
            if case .ready(let configuration) = self { return configuration }
            return nil
        }
        var issues: [String] {
            if case .unconfigured(let issues) = self { return issues }
            return []
        }
    }

    static func load(bundle: Bundle = .main) -> State {
        load(values: bundle.infoDictionary ?? [:])
    }
    static func forCurrentLaunch(arguments: [String] = ProcessInfo.processInfo.arguments, bundle: Bundle = .main) -> State {
        #if DEBUG
        let reviewFlags = ["--ui-testing", "--onboarding-step", "--review-onboarding", "--setup-step", "--sample-journey", "--reset-demo"]
        if arguments.contains(where: reviewFlags.contains) { return .unconfigured(["Isolated development review"]) }
        #endif
        return load(bundle: bundle)
    }

    static func load(values: [String: Any]) -> State {
        var issues: [String] = []
        func required(_ key: String) -> String {
            guard let raw = values[key] as? String else {
                issues.append("Missing \(key)")
                return ""
            }
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowered = value.lowercased()
            guard !value.isEmpty, !value.contains("$("), !value.contains("${"),
                  !lowered.contains("replace_me"), !lowered.contains("your_"),
                  !lowered.contains("placeholder"), !lowered.contains("example.") else {
                issues.append("Configure \(key) with a real value")
                return ""
            }
            return value
        }
        let annual = required("ALONG_BILLING_ANNUAL_PRODUCT_ID")
        let monthly = required("ALONG_BILLING_MONTHLY_PRODUCT_ID")
        let key = required("ALONG_SUPERWALL_PUBLIC_KEY")
        let entitlement = required("ALONG_BILLING_ENTITLEMENT_ID")
        let terms = required("ALONG_TERMS_URL")
        let privacy = required("ALONG_PRIVACY_URL")
        if !annual.isEmpty && annual == monthly { issues.append("Annual and monthly product IDs must differ") }
        for identifier in [annual, monthly, entitlement, key] where !identifier.isEmpty {
            if identifier.contains(where: { $0.isWhitespace }) {
                issues.append("Billing identifiers must not contain whitespace")
            }
        }
        func legalURL(_ value: String, key: String) -> URL? {
            guard let url = URL(string: value), url.scheme == "https",
                  let host = url.host, host.contains("."), host != "localhost",
                  url.user == nil, url.password == nil else {
                if !value.isEmpty { issues.append("\(key) must be a public HTTPS URL") }
                return nil
            }
            return url
        }
        let termsURL = legalURL(terms, key: "ALONG_TERMS_URL")
        let privacyURL = legalURL(privacy, key: "ALONG_PRIVACY_URL")
        guard issues.isEmpty, let termsURL, let privacyURL else { return .unconfigured(issues) }
        return .ready(.init(annualProductID: annual, monthlyProductID: monthly,
                            superwallPublicKey: key, entitlementID: entitlement,
                            termsURL: termsURL, privacyURL: privacyURL))
    }
}
