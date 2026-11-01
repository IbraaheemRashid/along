import SwiftUI
import UniformTypeIdentifiers

struct JournalBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw JournalBackup.Failure.unreadableFile }
        _ = try JournalBackup.decode(data)
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard data.count <= JournalBackup.maximumBytes else { throw JournalBackup.Failure.tooLarge }
        return FileWrapper(regularFileWithContents: data)
    }
}

/// The replacement closure must persist atomically before publishing state and
/// return false on failure. Membership/authentication are owned by the caller.
struct JournalBackupView: View {
    let journal: () -> Journal
    let replace: (Journal) -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var document: JournalBackupDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var isReading = false
    @State private var pending: JournalBackup?
    @State private var confirmRestore = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Keep a copy of your story", systemImage: "externaldrive")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                    Text("Save a backup you can restore in Along. This is separate from the readable journal export.")
                }
                Section("Your private information") {
                    Text("The backup is an unencrypted JSON file. It contains your notes, mood, appetite, optional weight, routines, preferences and Pip’s progress. Anyone who can open the file can read it.")
                    Text("Choose a trusted place in Files. If you choose a cloud provider, that provider will store your copy. Along does not enable automatic cloud or device backup here.")
                    Text("Membership, sign-in credentials and payment information are not included. Deleting data in Along will not remove copies you saved elsewhere.")
                }.font(.subheadline)
                Section("Save a backup") {
                    recordCounts(journal())
                    Button { exportBackup() } label: {
                        Label("Save backup to Files", systemImage: "square.and.arrow.up")
                    }.accessibilityIdentifier("backup.export").disabled(isReading)
                }
                Section("Restore a backup") {
                    Text("Restoring replaces this device’s journal and preferences. It does not combine two journals. Save a backup of your current journal first if you want to keep it.")
                        .font(.subheadline)
                    Button { pending = nil; showImporter = true } label: {
                        Label("Choose backup file", systemImage: "square.and.arrow.down")
                    }.accessibilityIdentifier("backup.import").disabled(isReading)
                    if isReading { ProgressView("Checking backup…") }
                }
                if let pending {
                    Section("Backup ready to restore") {
                        LabeledContent("Saved", value: pending.exportedAt.formatted(date: .abbreviated, time: .shortened))
                        LabeledContent("Check-ins", value: "\(pending.content.checkIns.count)")
                        LabeledContent("Milestones", value: "\(pending.content.milestones.count)")
                        LabeledContent("Weight records", value: "\(pending.content.weights.count)")
                        LabeledContent("Routine-only days", value: "\(pending.content.routineDays?.count ?? 0)")
                        if pending.content.hasSampleData {
                            Label("Contains fictional sample records", systemImage: "exclamationmark.circle").font(.subheadline)
                        }
                        Text("Your current journal will be replaced. Membership and purchase status stay unchanged.").font(.subheadline)
                        Button("Replace current journal", role: .destructive) { confirmRestore = true }
                            .accessibilityIdentifier("backup.restore.confirm")
                        Button("Keep current journal", role: .cancel) { self.pending = nil }
                            .accessibilityIdentifier("backup.restore.cancel")
                    }.accessibilityIdentifier("backup.preview")
                }
            }
            .scrollContentBackground(.hidden).background(Theme.paper).tint(Theme.accent)
            .navigationTitle("Backup & restore").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.disabled(isReading) } }
            .fileExporter(isPresented: $showExporter, document: document, contentType: .json,
                          defaultFilename: filename) { result in
                switch result {
                case .success: message = "Your backup was saved to the location you chose. Keep it somewhere private."
                case .failure(let error):
                    if !isCancellation(error) { message = "The backup could not be saved. Your journal is unchanged. Please try again." }
                }
                document = nil
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    isReading = true
                    Task { @MainActor in
                        defer { isReading = false }
                        do {
                            let backup = try await Task.detached(priority: .userInitiated) { try JournalBackup.read(from: url) }.value
                            pending = backup
                        } catch { message = importError }
                    }
                case .failure(let error):
                    if !isCancellation(error) { message = importError }
                }
            }
            .confirmationDialog("Replace your current journal?", isPresented: $confirmRestore, titleVisibility: .visible) {
                Button("Replace journal", role: .destructive) { restoreBackup() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This replaces the records and preferences on this device. It cannot be undone without another backup. Your membership is unchanged.")
            }
            .alert("Backup & restore", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) { message = nil }
            } message: { Text(message ?? "") }
        }
    }

    @ViewBuilder private func recordCounts(_ value: Journal) -> some View {
        LabeledContent("Check-ins", value: "\(value.checkIns.count)")
        LabeledContent("Milestones", value: "\(value.milestones.count)")
        LabeledContent("Weight records", value: "\(value.weights.count)")
        LabeledContent("Routine-only days", value: "\(value.routineDays?.count ?? 0)")
    }
    private var filename: String {
        let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"
        return "Along-backup-\(formatter.string(from: .now))"
    }
    private var importError: String {
        "This file could not be restored. Choose a valid Along backup smaller than 5 MB from a supported version. Your current journal is unchanged."
    }
    private func isCancellation(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError
    }
    private func exportBackup() {
        do {
            document = JournalBackupDocument(data: try JournalBackup.make(from: journal()).encoded())
            showExporter = true
        } catch {
            message = "A backup could not be prepared. Your journal is unchanged. Please try again."
        }
    }
    private func restoreBackup() {
        guard let pending else { return }
        do {
            // Read destination flags at confirmation, not when the picker opened.
            let replacement = try pending.restoring(into: journal())
            guard replace(replacement) else {
                message = "The restored journal could not be saved. Your current journal has been kept. Please try again."
                return
            }
            self.pending = nil
            message = "Your journal was restored. Your membership is unchanged."
        } catch { message = importError }
    }
}
