import CryptoKit
import Foundation
import Observation
#if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
import FirebaseFirestore
import FirebaseAuth
#endif

struct AccountBackup: Equatable {
    var journal: Journal
    var setup: SetupDraft
}

struct AccountBackupRecord {
    var value: AccountBackup
    var revision: String
}

@MainActor protocol AccountBackupClient {
    func read(userID: String) async throws -> AccountBackupRecord?
    func remove(userID: String) async throws
    func write(_ value: AccountBackup, userID: String, replacing revision: String?) async throws -> String
}

private enum BackupError: Error { case unavailable, invalid, changed }

/// Every read, queued edit and write belongs to this one store for the life of the session.
@MainActor @Observable final class CloudSync {
    private(set) var lastSyncedAt: Date?
    private(set) var isSyncing = false
    private(set) var message: String?
    private(set) var conflict: AccountBackupRecord?
    private let store: JournalStore?
    private let backend: any AccountBackupClient
    private var closed = false
    private var ready = false
    private var revision: String?
    private var synced: AccountBackup?
    private var opening: Task<Void, Never>?
    private var debounce: Task<Void, Never>?
    private var writing = false
    private var writeWaiters: [CheckedContinuation<Void, Never>] = []

    private struct Checkpoint: Codable {
        var revision: String
        var files: [String]
    }

    init(store: JournalStore? = nil, backend: any AccountBackupClient = FirebaseAccountBackup()) {
        self.store = store
        self.backend = backend
    }

    func close() {
        closed = true
        debounce?.cancel()
        opening?.cancel()
    }

    func closeAndWait() async {
        close()
        if let opening { await opening.value }
        if writing { await withCheckedContinuation { writeWaiters.append($0) } }
    }

    func prepare() async {
        guard !closed, !ready, conflict == nil, let store, let id = store.accountID else { return }
        if let opening { await opening.value; return }
        let task = Task { await open(store, userID: id) }
        opening = task
        await task.value
        opening = nil
    }

    private func open(_ store: JournalStore, userID: String) async {
        guard !closed, store.canSyncJournal else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let remote = try await backend.read(userID: userID)
            guard !closed, !Task.isCancelled, store.canSyncJournal else { return }
            let local = AccountBackup(journal: store.journal, setup: store.setup)
            revision = remote?.revision
            message = nil
            if let remote {
                let checkpointURL = store.storageDirectory.appendingPathComponent("cloud-checkpoint.json")
                let checkpoint = (try? Data(contentsOf: checkpointURL)).flatMap { try? JSONDecoder().decode(Checkpoint.self, from: $0) }
                let matchesCheckpoint = try checkpoint.map { try store.syncFileHashes() == $0.files } ?? false
                if local == remote.value {
                    try remember(remote, files: store.syncFileHashes(), in: store)
                } else if !store.hasPersonalRecords || matchesCheckpoint {
                    try restore(remote, in: store)
                } else if checkpoint?.revision == remote.revision {
                    synced = remote.value
                } else {
                    conflict = remote
                    message = "This iPhone and your account have different records. Choose which copy you want to keep."
                    return
                }
            }
            ready = true
            changed()
        } catch {
            message = "Couldn’t check your account backup. Your journal is saved on this iPhone."
        }
    }

    private func restore(_ remote: AccountBackupRecord, in store: JournalStore) throws {
        guard remote.value.setup.isValid,
              !remote.value.journal.hasSampleData, remote.value.journal.isDesignPreview != true else { throw BackupError.invalid }
        _ = try JournalBackup.make(from: remote.value.journal)
        guard store.updateJournal({ $0 = remote.value.journal }) else { throw BackupError.invalid }
        guard store.replaceSetup(remote.value.setup) else { throw BackupError.invalid }
        try remember(remote, files: store.syncFileHashes(), in: store)
        store.showToast("Restored from your account")
    }

    private func remember(_ record: AccountBackupRecord, files: [String], in store: JournalStore) throws {
        let stamp = Checkpoint(revision: record.revision, files: files)
        try JSONEncoder().encode(stamp).write(to: store.storageDirectory.appendingPathComponent("cloud-checkpoint.json"),
                                             options: JournalStore.writeOptions)
        synced = record.value
        revision = record.revision
        lastSyncedAt = .now
        message = nil
    }

    func changed() {
        guard !closed, ready, !writing, let store, store.canSyncJournal, store.journal.hasOnboarded,
              !store.journal.hasSampleData, store.journal.isDesignPreview != true else { return }
        debounce?.cancel()
        debounce = Task {
            do { try await Task.sleep(for: .milliseconds(800)) } catch { return }
            await flush()
        }
    }

    func flush() async {
        guard !closed, ready, !writing, let store, let id = store.accountID else { return }
        writing = true
        isSyncing = true
        defer {
            writing = false
            isSyncing = false
            writeWaiters.forEach { $0.resume() }
            writeWaiters.removeAll()
        }
        // An edit made during a network write is sent in order against the new revision.
        while !closed && store.canSyncJournal && store.journal.hasOnboarded &&
              !store.journal.hasSampleData && store.journal.isDesignPreview != true {
            let value = AccountBackup(journal: store.journal, setup: store.setup)
            guard value != synced else { return }
            do {
                let files = try store.syncFileHashes()
                let next = try await backend.write(value, userID: id, replacing: revision)
                guard !closed else { return }
                try remember(AccountBackupRecord(value: value, revision: next), files: files, in: store)
            } catch {
                guard !closed else { return }
                ready = false
                message = "Couldn’t update your account backup. Your journal is saved on this iPhone."
                return
            }
        }
    }

    func resolveConflict(useAccount: Bool) {
        guard !closed, let store, let conflict else { return }
        do {
            if useAccount { try restore(conflict, in: store) }
            else { synced = nil }
            self.conflict = nil
            message = nil
            ready = true
            changed()
        } catch { message = "Couldn’t restore this copy. Your account backup is still available." }
    }
}

struct FirebaseAccountBackup: AccountBackupClient {
    nonisolated init() {}
    #if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
    @MainActor private func reference(_ uid: String) throws -> DocumentReference {
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil,
              Auth.auth().currentUser?.uid == uid else { throw BackupError.unavailable }
        return Firestore.firestore().collection("users").document(uid).collection("app").document("state")
    }

    /// Older Along backups have no revision. Their exact stored bytes identify that version.
    nonisolated private static func revision(of data: [String: Any]) throws -> String {
        if let revision = data["revision"] as? String { return revision }
        guard let journal = data["journalBase64"] as? String, let setup = data["setupBase64"] as? String else {
            throw BackupError.invalid
        }
        return SHA256.hash(data: Data((journal + "." + setup).utf8)).map { String(format: "%02x", $0) }.joined()
    }
    #endif

    func remove(userID: String) async throws {
        #if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        let ref = try reference(userID)
        try await ref.delete()
        #else
        throw BackupError.unavailable
        #endif
    }

    func read(userID: String) async throws -> AccountBackupRecord? {
        #if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        let ref = try reference(userID)
        let document = try await ref.getDocument(source: .server)
        guard document.exists else { return nil }
        guard let data = document.data(), let journalText = data["journalBase64"] as? String,
              let setupText = data["setupBase64"] as? String, let journal = Data(base64Encoded: journalText),
              let setup = Data(base64Encoded: setupText) else { throw BackupError.invalid }
        let value = try AccountBackup(journal: JSONDecoder().decode(Journal.self, from: journal),
                                      setup: JSONDecoder().decode(SetupDraft.self, from: setup))
        guard value.setup.isValid, !value.journal.hasSampleData, value.journal.isDesignPreview != true else { throw BackupError.invalid }
        _ = try JournalBackup.make(from: value.journal)
        return try AccountBackupRecord(value: value, revision: Self.revision(of: data))
        #else
        throw BackupError.unavailable
        #endif
    }

    func write(_ value: AccountBackup, userID: String, replacing revision: String?) async throws -> String {
        #if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
        let ref = try reference(userID)
        let next = UUID().uuidString
        let journal = try JSONEncoder().encode(value.journal).base64EncodedString()
        let setup = try JSONEncoder().encode(value.setup).base64EncodedString()
        _ = try await Firestore.firestore().runTransaction { transaction, errorPointer in
            do {
                let snapshot = try transaction.getDocument(ref)
                let current = try snapshot.data().map { try Self.revision(of: $0) }
                guard current == revision else { throw BackupError.changed }
                transaction.setData(["journalBase64": journal, "setupBase64": setup, "schema": 1,
                                     "revision": next, "updatedAtSeconds": Date.now.timeIntervalSince1970], forDocument: ref)
            } catch { errorPointer?.pointee = error as NSError }
            return nil
        }
        return next
        #else
        throw BackupError.unavailable
        #endif
    }
}
