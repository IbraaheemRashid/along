import Foundation
import Observation

/// The original, unowned journal stays on this device. Account journals are opened by authenticated UID.
@MainActor @Observable final class AccountJournals {
    let device: JournalStore
    private(set) var chooseDeviceJournal: Bool
    private(set) var active: JournalStore
    private(set) var sync: CloudSync
    private let backend: any AccountBackupClient

    init(device: JournalStore, backend: any AccountBackupClient = FirebaseAccountBackup()) {
        self.device = device
        active = device
        chooseDeviceJournal = device.hasPersonalRecords && FileManager.default.fileExists(
            atPath: device.storageDirectory.appendingPathComponent("Accounts").path)
        self.backend = backend
        sync = CloudSync()
    }

    func select(_ userID: String?) {
        guard active.accountID != userID else { return }
        sync.close()
        chooseDeviceJournal = userID == nil && device.hasPersonalRecords
        if let userID, !userID.isEmpty {
            active = JournalStore(directory: device.storageDirectory, accountID: userID, arguments: [])
            sync = CloudSync(store: active, backend: backend)
        } else {
            active = device
            sync = CloudSync()
        }
    }

    func openDeviceJournal() {
        guard active === device else { return }
        chooseDeviceJournal = false
    }

    /// Only the explicit account step or checkout may carry the draft the person just submitted.
    /// A returning account's existing journal and an unrelated device journal are never copied over.
    func continueSetup(_ draft: SetupDraft, from source: JournalStore, userID: String) async -> JournalStore? {
        let destination = active
        guard destination.accountID == userID else { return nil }
        if source !== destination {
            guard source === device, !source.journal.hasOnboarded, source.setup == draft,
                  draft.step == .account || draft.step == .paywall else { return nil }
        }
        let session = sync
        await session.prepare()
        guard active === destination, sync === session, destination.canSyncJournal else { return nil }
        if source !== destination {
            guard source.setup == draft, !source.journal.hasOnboarded else { return nil }
            if !destination.hasPersonalRecords {
                guard destination.replaceSetup(draft) else { return nil }
                _ = device.replaceSetup(SetupDraft())
            }
        }
        return destination
    }
}
