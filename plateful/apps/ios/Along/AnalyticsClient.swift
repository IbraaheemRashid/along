import Foundation

/// Low-detail product events. Disabled until an API base URL is configured.
/// Never send peptide names, doses, notes, sites or weight values.
struct AnalyticsEvent: Equatable {
    var name: String
    var feature: String
    var surface: String
    var result: String
    var platform = "ios"
}

@MainActor @Observable final class AnalyticsClient {
    private(set) var isEnabled: Bool
    private let endpoint: URL?
    private let session: URLSession

    init(info: [String: Any] = Bundle.main.infoDictionary ?? [:], session: URLSession = .shared) {
        self.session = session
        if let raw = info["ALONG_ANALYTICS_URL"] as? String,
           let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
           url.scheme == "https", let host = url.host, host.contains(".") {
            endpoint = url.appending(path: "events")
            isEnabled = true
        } else {
            endpoint = nil
            isEnabled = false
        }
    }

    func track(_ event: AnalyticsEvent) {
        guard isEnabled, let endpoint else { return }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "name": event.name,
            "properties": [
                "platform": event.platform,
                "feature": event.feature,
                "surface": event.surface,
                "result": event.result,
            ],
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        Task {
            _ = try? await session.data(for: request)
        }
    }
}
