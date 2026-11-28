import Foundation

@MainActor private final class TestAccountBackups: AccountBackupClient {
    var records: [String: AccountBackupRecord] = [:]
    var writes: [String] = []
    var removalError = false
    var readError = false
    var pauseRead = false
    var pauseWrite = false
    var pendingRead: CheckedContinuation<Void, Never>?
    var pendingWrite: CheckedContinuation<Void, Never>?

    func remove(userID: String) async throws {
        if removalError { throw CocoaError(.fileWriteUnknown) }
        records.removeValue(forKey: userID)
    }

    func read(userID: String) async throws -> AccountBackupRecord? {
        let result = records[userID]
        if pauseRead {
            pauseRead = false
            await withCheckedContinuation { pendingRead = $0 }
        }
        if readError { throw CocoaError(.fileReadUnknown) }
        return result
    }

    func write(_ value: AccountBackup, userID: String, replacing revision: String?) async throws -> String {
        if pauseWrite {
            pauseWrite = false
            await withCheckedContinuation { pendingWrite = $0 }
        }
        guard records[userID]?.revision == revision else { throw CocoaError(.fileWriteFileExists) }
        let next = UUID().uuidString
        records[userID] = AccountBackupRecord(value: value, revision: next)
        writes.append(userID)
        return next
    }
}

enum AccountSyncTests {
    @MainActor static func run(in root: URL) async throws -> Int {
        var checks = 0
        func expect(_ result: Bool, _ explanation: String) {
            precondition(result, explanation)
            checks += 1
        }
        func record(_ name: String) -> AccountBackupRecord {
            var journal = Journal()
            journal.name = name
            journal.hasOnboarded = true
            journal.reconcileProgress()
            return AccountBackupRecord(value: AccountBackup(journal: journal, setup: SetupDraft()), revision: UUID().uuidString)
        }
        let backend = TestAccountBackups()
        let device = JournalStore(directory: root, arguments: [], clearCredentials: {})
        _ = device.updateJournal { $0 = record("legacy device journal").value.journal }
        let profiles = AccountJournals(device: device, backend: backend)
        backend.records["A"] = record("A history")
        backend.records["B"] = record("B history")
        profiles.select("A")
        await profiles.sync.prepare()
        expect(profiles.active.journal.name == "A history", "Returning A restores A without adopting the unowned device history")
        expect(backend.writes.isEmpty && device.journal.name == "legacy device journal", "Opening a profile preserves the legacy file and both backups")
        let aDirectory = profiles.active.storageDirectory
        _ = profiles.active.updateJournal { $0.name = "A offline edit" }
        profiles.sync.changed()
        let ended = profiles.sync
        profiles.select(nil)
        await ended.flush()
        expect(profiles.active === device && backend.writes.isEmpty, "Signing out cancels the outstanding upload and closes A’s store")
        expect(profiles.chooseDeviceJournal, "Signing out never automatically displays the unowned journal")
        let signedOutRelaunch = AccountJournals(device: JournalStore(directory: root, arguments: []), backend: backend)
        expect(signedOutRelaunch.chooseDeviceJournal, "The signed-out choice also applies after restarting the app")
        signedOutRelaunch.openDeviceJournal()
        expect(!signedOutRelaunch.chooseDeviceJournal && signedOutRelaunch.active.journal.name == "legacy device journal", "The original local journal can still be opened deliberately")
        profiles.select("B")
        await profiles.sync.prepare()
        expect(profiles.active.storageDirectory != aDirectory && profiles.active.journal.name == "B history", "A and B use different local files")
        expect(backend.records["B"]?.value.journal.name == "B history", "Signing in to B never publishes A’s edit")
        _ = profiles.active.updateJournal { $0.name = "B edit" }
        await profiles.sync.flush()
        expect(backend.writes == ["B"] && backend.records["B"]?.value.journal.name == "B edit", "B edits can only go to B")
        profiles.select("A")
        await profiles.sync.prepare()
        expect(profiles.active.journal.name == "A offline edit", "A’s pending edit survives sign-out")
        await profiles.sync.flush()
        expect(backend.records["A"]?.value.journal.name == "A offline edit", "A’s offline change is uploaded to the original account")
        expect(backend.records["B"]?.value.journal.name == "B edit", "B’s saved data survives the return to A")

        backend.pauseRead = true
        profiles.select("B")
        let oldSync = profiles.sync
        let oldRead = Task { await oldSync.prepare() }
        while backend.pendingRead == nil { await Task.yield() }
        profiles.select("C")
        await profiles.sync.prepare()
        expect(!profiles.active.journal.hasOnboarded && !profiles.active.hasPersonalRecords, "A new UID with no backup opens a fresh journal")
        backend.pendingRead?.resume()
        await oldRead.value
        expect(!profiles.active.hasPersonalRecords && backend.records["C"] == nil, "A late B download cannot display or write B’s records in C")

        profiles.select("A")
        await profiles.sync.prepare()
        _ = profiles.active.updateJournal { $0.name = "A in-flight edit" }
        backend.pauseWrite = true
        let inFlightSync = profiles.sync
        let inFlight = Task { await inFlightSync.flush() }
        while backend.pendingWrite == nil { await Task.yield() }
        profiles.select("B")
        await profiles.sync.prepare()
        backend.pendingWrite?.resume()
        await inFlight.value
        expect(profiles.active.journal.name == "B edit" && backend.records["B"]?.value.journal.name == "B edit",
               "An already-dispatched A write stays bound to A after switching accounts")
        expect(backend.records["A"]?.value.journal.name == "A in-flight edit", "The in-flight edit reaches only its owner")

        backend.records["B"] = record("B on another device")
        _ = profiles.active.updateJournal { $0.name = "B on this device" }
        await profiles.sync.flush()
        expect(backend.records["B"]?.value.journal.name == "B on another device", "A concurrent remote change fails the version check")
        await profiles.sync.prepare()
        expect(profiles.sync.conflict != nil && profiles.active.journal.name == "B on this device", "Both copies survive a conflict")
        profiles.sync.resolveConflict(useAccount: true)
        expect(profiles.active.journal.name == "B on another device", "Explicit restore opens the selected account copy")

        profiles.select(nil)
        profiles.select("B")
        backend.readError = true
        await profiles.sync.prepare()
        let count = backend.writes.count
        _ = profiles.active.updateJournal { $0.name = "B after network loss" }
        await profiles.sync.flush()
        expect(backend.writes.count == count && profiles.sync.message != nil, "A failed server read never counts as an empty backup")
        backend.readError = false
        await profiles.sync.prepare()
        await profiles.sync.flush()
        expect(backend.records["B"]?.value.journal.name == "B after network loss", "A retry preserves the offline edit")

        profiles.select("C")
        await profiles.sync.prepare()
        let previous = device.journal
        let draft = SetupDraft.example(at: .paywall)
        device.setup = draft
        let rejected = await profiles.continueSetup(draft, from: device, userID: "C")
        expect(rejected == nil && !profiles.active.hasPersonalRecords, "A completed unowned journal cannot seed checkout")
        let checkoutDevice = JournalStore(directory: root.appendingPathComponent("fresh-install"), arguments: [])
        let checkout = AccountJournals(device: checkoutDevice, backend: backend)
        checkoutDevice.setup = draft
        checkout.select("C")
        let c = await checkout.continueSetup(draft, from: checkoutDevice, userID: "C")
        expect(c === checkout.active && c?.setup == draft && c?.journal.name != previous.name, "Explicit checkout transfers only its submitted setup")
        expect(checkoutDevice.setup == SetupDraft(), "A successfully transferred draft is no longer on the signed-out screen")
        _ = c?.finishSetup()
        await checkout.sync.flush()
        expect(backend.records["C"]?.value.journal.protocolPeptides.map(\.name) == draft.compounds, "A new buyer’s protocol survives the account handoff")
        expect(device.journal == previous, "No legacy journal is erased during account setup")
        checkoutDevice.setup = draft
        checkout.select("B")
        let b = await checkout.continueSetup(draft, from: checkoutDevice, userID: "B")
        expect(b?.journal.name == "B after network loss" && b?.setup != draft, "Checkout preserves a returning user’s journal and setup")
        expect(checkoutDevice.setup == draft, "A draft that was not transferred to a returning account stays on the device")
        let stale = await checkout.continueSetup(draft, from: checkoutDevice, userID: "A")
        expect(stale == nil, "A stale provider completion cannot transfer a draft to a different account")
        let relaunched = AccountJournals(device: JournalStore(directory: checkoutDevice.storageDirectory, arguments: []), backend: backend)
        relaunched.select("C")
        await relaunched.sync.prepare()
        expect(relaunched.active.journal.protocolPeptides.map(\.name) == draft.compounds, "Cold launch reopens only the authenticated UID’s files")

        _ = relaunched.active.updateJournal { $0.name = "C local choice" }
        backend.records["C"] = record("C remote choice")
        await relaunched.sync.flush()
        await relaunched.sync.prepare()
        expect(relaunched.sync.conflict != nil, "Independently edited copies wait for a choice")
        relaunched.sync.resolveConflict(useAccount: false)
        await relaunched.sync.flush()
        expect(backend.records["C"]?.value.journal.name == "C local choice", "Explicitly keeping local data updates only the accepted remote revision")
        let journalName = checkoutDevice.journal.name
        let unrelated = backend.records["B"]?.revision
        backend.removalError = true
        var identitiesDeleted = 0
        do {
            try await relaunched.eraseAccount("C", prepareIdentity: {}, deleteIdentity: { identitiesDeleted += 1 })
            preconditionFailure("An unavailable backup service must interrupt deletion")
        } catch {}
        expect(relaunched.deletionPending && identitiesDeleted == 0, "Deletion can retry with the authenticated identity intact")
        let reopened = AccountJournals(device: checkoutDevice, backend: backend)
        reopened.select("C")
        expect(reopened.deletionPending, "An interrupted deletion is recovered on launch")
        let beforeWrites = backend.writes
        await reopened.sync.prepare()
        await reopened.sync.flush()
        expect(backend.writes == beforeWrites, "A pending deletion cannot upload a new backup")
        backend.removalError = false
        do {
            try await reopened.eraseAccount("B", prepareIdentity: {}, deleteIdentity: { identitiesDeleted += 1 })
            preconditionFailure("Another UID cannot authorize this deletion")
        } catch {}
        let removedDirectory = reopened.active.storageDirectory
        try await reopened.eraseAccount("C", prepareIdentity: {}, deleteIdentity: { identitiesDeleted += 1 })
        let remaining = try FileManager.default.contentsOfDirectory(atPath: removedDirectory.path)
        expect(remaining.isEmpty && backend.records["C"] == nil && identitiesDeleted == 1, "Retry removes the account backup, local files and identity")
        expect(backend.records["B"]?.revision == unrelated && checkoutDevice.journal.name == journalName && reopened.active === checkoutDevice, "Deleting one account preserves other journals")
        return checks
    }
}
