import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Pushes / pulls the local journal to Firestore under `users/{uid}/app/state`.
/// No Cloudflare Worker — the signed-in client talks to Firestore directly.
@MainActor @Observable final class CloudSync {
    var lastSyncedAt: Date?
    var isSyncing = false
    var message: String?

    private var pushTask: Task<Void, Never>?

    var isAvailable: Bool {
        #if canImport(FirebaseFirestore)
        Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
        #else
        false
        #endif
    }

    func schedulePush(journal: Journal, setup: SetupDraft, userID: String) {
        guard isAvailable, !userID.isEmpty else { return }
        pushTask?.cancel()
        pushTask = Task {
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            await push(journal: journal, setup: setup, userID: userID)
        }
    }

    func push(journal: Journal, setup: SetupDraft, userID: String) async {
        #if canImport(FirebaseFirestore)
        guard isAvailable else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            FirebaseBootstrap.configureIfNeeded()
            let payload = try encodePayload(journal: journal, setup: setup)
            try await Firestore.firestore()
                .collection("users").document(userID)
                .collection("app").document("state")
                .setData(payload, merge: false)
            lastSyncedAt = .now
            message = nil
        } catch {
            message = "Couldn’t sync to the cloud. Your data is still saved on this iPhone."
        }
        #endif
    }

    /// Returns remote journal/setup when present. Caller decides merge policy.
    func pull(userID: String) async -> (journal: Journal, setup: SetupDraft, updatedAt: Date)? {
        #if canImport(FirebaseFirestore)
        guard isAvailable, !userID.isEmpty else { return nil }
        isSyncing = true
        defer { isSyncing = false }
        do {
            FirebaseBootstrap.configureIfNeeded()
            let snap = try await Firestore.firestore()
                .collection("users").document(userID)
                .collection("app").document("state")
                .getDocument()
            guard let data = snap.data(),
                  let journalB64 = data["journalBase64"] as? String,
                  let setupB64 = data["setupBase64"] as? String,
                  let journalData = Data(base64Encoded: journalB64),
                  let setupData = Data(base64Encoded: setupB64) else { return nil }
            let journal = try JSONDecoder().decode(Journal.self, from: journalData)
            let setup = try JSONDecoder().decode(SetupDraft.self, from: setupData)
            let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
                ?? (data["updatedAtSeconds"] as? Double).map(Date.init(timeIntervalSince1970:))
                ?? .distantPast
            lastSyncedAt = .now
            message = nil
            return (journal, setup, updatedAt)
        } catch {
            message = "Couldn’t download your cloud backup."
            return nil
        }
        #else
        return nil
        #endif
    }

    private func encodePayload(journal: Journal, setup: SetupDraft) throws -> [String: Any] {
        let journalData = try JSONEncoder().encode(journal)
        let setupData = try JSONEncoder().encode(setup)
        return [
            "journalBase64": journalData.base64EncodedString(),
            "setupBase64": setupData.base64EncodedString(),
            "updatedAtSeconds": Date.now.timeIntervalSince1970,
            "schema": 1
        ]
    }
}
