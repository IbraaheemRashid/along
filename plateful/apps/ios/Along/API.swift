import Foundation
import Security

/// Dormant integration seam. The local journal never calls the server automatically.
struct API {
    let baseURL: URL
    var session = URLSession.shared
    struct Health: Decodable { let service: String; let mode: String; let liveReady: Bool }
    struct Receipt: Decodable { let mode: String; let stored: Bool; let notice: String }
    struct CheckInPayload: Encodable {
        let id: String; let day: String; let mood: Mood; let appetite: Appetite; let routines: [Routine]; let note: String
        init(_ entry: CheckIn) {
            id = entry.id.uuidString
            let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = .current; formatter.dateFormat = "yyyy-MM-dd"
            day = formatter.string(from: entry.day); mood = entry.mood; appetite = entry.appetite; routines = entry.routines.sorted { $0.rawValue < $1.rawValue }; note = entry.note
        }
    }
    enum Failure: Error { case insecureURL, invalidResponse, notPersisted }
    func health() async throws -> Health { try await request("health", body: Optional<Data>.none) }
    func saveCheckIn(_ entry: CheckIn) async throws -> Receipt {
        let result: Receipt = try await request("check-ins", body: JSONEncoder().encode(CheckInPayload(entry)))
        guard result.stored else { throw Failure.notPersisted }
        return result
    }
    private func request<Result: Decodable>(_ path: String, body: Data?) async throws -> Result {
        guard baseURL.scheme == "https" || (baseURL.scheme == "http" && ["localhost", "127.0.0.1", "::1"].contains(baseURL.host ?? "")) else { throw Failure.insecureURL }
        var request = URLRequest(url: baseURL.appendingPathComponent(path)); request.timeoutInterval = 20
        if let body { request.httpMethod = "POST"; request.httpBody = body; request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let token = TokenVault.read() { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw Failure.invalidResponse }
        return try JSONDecoder().decode(Result.self, from: data)
    }
}
enum TokenVault {
    private static let service = "dev.along.prototype.auth"
    static func read() -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "session", kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func store(_ token: String) throws {
        let key: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "session"]
        let data = Data(token.utf8)
        let update = SecItemUpdate(key as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecItemNotFound {
            var item = key; item[kSecValueData as String] = data; item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw API.Failure.invalidResponse }
        } else if update != errSecSuccess { throw API.Failure.invalidResponse }
    }
    static func clear() { SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service] as CFDictionary) }
}
