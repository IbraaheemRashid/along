import Foundation

/// Where an install came from. Values stay local until an approved MMP is added.
struct AttributionSnapshot: Equatable, Codable {
    var heardFrom: String?
    var referralCode: String?
    var provider: String
    var capturedAt: Date
}

/// MMP seam. AppsFlyer (or another provider) needs explicit approval before a
/// real implementation is linked; the no-op keeps Superwall attributes empty.
@MainActor protocol AttributionProviding {
    var name: String { get }
    func start() async
    func record(heardFrom: String?, referralCode: String?) async -> AttributionSnapshot
    /// Optional conversion data for Superwall `setUserAttributes` later.
    func campaignAttributes() async -> [String: String]
}

@MainActor final class NoOpAttributionProvider: AttributionProviding {
    let name = "none"
    private var latest: AttributionSnapshot?

    func start() async {}

    func record(heardFrom: String?, referralCode: String?) async -> AttributionSnapshot {
        let snapshot = AttributionSnapshot(heardFrom: heardFrom, referralCode: referralCode,
                                           provider: name, capturedAt: .now)
        latest = snapshot
        return snapshot
    }

    func campaignAttributes() async -> [String: String] { [:] }
}

@MainActor @Observable final class AttributionStore {
    private(set) var latest: AttributionSnapshot?
    private let provider: any AttributionProviding
    private let defaults: UserDefaults
    private let storageKey = "along.attribution.v1"

    init(provider: (any AttributionProviding)? = nil, defaults: UserDefaults = .standard) {
        self.provider = provider ?? NoOpAttributionProvider()
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(AttributionSnapshot.self, from: data) {
            latest = decoded
        }
    }

    func start() async { await provider.start() }

    @discardableResult
    func capture(from profile: SetupDraft?) async -> AttributionSnapshot {
        let snapshot = await provider.record(heardFrom: profile?.heardFrom?.rawValue,
                                             referralCode: profile?.referralCode.isEmpty == false ? profile?.referralCode : nil)
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: storageKey)
        }
        latest = snapshot
        return snapshot
    }

    func campaignAttributes() async -> [String: String] { await provider.campaignAttributes() }
}
