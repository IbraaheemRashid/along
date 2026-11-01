# Local backup and restore integration

Current archives use schema 2 with stable civil-date keys; schema 1 remains readable. See [date migration details](day-identity-integration.md).

Current integration status: the root app now wires this module. See [release implementation](release-implementation.md) for the latest checks and remaining device/account verification. The original module-specific verification notes below remain historical.

This feature saves a user-chosen, unencrypted JSON file and can restore that file after reinstalling or on another device. It does not turn on iCloud/device backups, create accounts, transfer credentials or grant membership. A file saved to a cloud provider in Files follows that provider's storage rules; the choice is explicit.

## Integration contract

Add `JournalBackup.swift` and `JournalBackupView.swift` to the native target (the existing project generator discovers new Swift files). The model depends on the current `Models.swift`, `OnboardingModel.swift` and `PipProgression.swift`, including optional `Journal.pipProgress` and `routineDays`. It adds no dependencies or changes to existing files.

Present the view from Settings using a current journal getter and a transactional replacement:

```swift
JournalBackupView(
    journal: { store.journal },
    replace: { replacement in
        store.updateJournal { $0 = replacement }
    }
)
```

`replace` must return `true` only after the entire replacement has been durably saved and published. On failure it must leave the existing in-memory journal and file unchanged. If the root store has additional pending setup state, clear/rebuild it transactionally after a successful restore so a stale onboarding archive cannot later overwrite restored records. Reschedule optional local notifications from restored preferences only after success; the backup never changes system notification authorization.

The getter is read again at confirmation. `restoring(into:)` preserves the destination's current `hasOnboarded` and `isDesignPreview`; the archive format contains neither. Membership is separately authoritative and is never imported. The backup component must remain available in any intended data-recovery route without being used to unlock paid access. Existing readable-text export can stay alongside it.

## Format and validation

Schema 1 has a fixed format marker, version, export time, source timezone and explicit journal-content DTO. Dates use Foundation's default Codable seconds since 1 January 2001, preserving subsecond values from existing journals. The format omits auth tokens, credentials, entitlements and the onboarding draft archive/record-ownership envelope. Onboarding preferences in the journal, including the selected plan as a preference, are included.

Limits are 5 MiB per file, 10,000 records per record type, 10,000 cumulative progress days and 50,000 credited entry IDs. Known-field checks reject unknown/future payloads instead of silently dropping data. Decoding/semantic checks cover enums, timestamps, input lengths, finite weights, known story choices, duplicate IDs across record types, duplicate check-in/weight/routine dates, competing routine-only and check-in entries on one day, set duplicates, ledger timezone/dates and premature room rewards. Legacy accessory gifts are retained. Historical deleted-record credits are allowed because earned Pip progress is permanent.

The source timezone governs archive date uniqueness; the ledger retains its own original timezone. Dates before 1900, future calendar days and export times more than five minutes ahead are rejected. Device clocks therefore need to be correct. The archive is not cryptographically signed: these validations protect app integrity, not the truth of a person's self-entered journal or cosmetic progress.

Debug builds accept clearly flagged sample archives. Release builds reject both importing and exporting sample history. Files with sample entries but no outer sample flag are invalid in both builds. No import changes provenance flags to make demo records look real.

The native view explains sensitive contents before export, previews counts/date before import, and asks again before replacing the existing journal. It reads through a scoped URL in a background task with a bounded file handle, displays generic errors, and never prints notes or file contents to logs. Cancelling the picker or confirmation does not mutate data.

## Verification

`tests/ios/BackupTests.swift` is a separate executable with its own `@main`; do not compile it with `CoreTests.swift` in one binary. Compile it with Models, OnboardingModel, PipProgression and JournalBackup. Run both `-D DEBUG` and Release configurations to check sample isolation. It covers round trip, destination access preservation, malformed/oversized/future/duplicate content, optional legacy fields, provenance, progress and bounded file reading.

Verified on 1 November 2026 against a temporary snapshot of the root agent's current Models/OnboardingModel/PipProgression: **56 Debug checks passed; 57 Release checks passed**. Release adds an independent sample-import rejection. The new model and SwiftUI file component also passed focused iOS Simulator typechecking against the iOS 26.2 SDK with deployment target 17.0 and the app's actual Theme definitions. No existing source files were copied into this branch or overwritten to perform these checks.

After integration, the CLI compile input is:

```sh
xcrun swiftc -D DEBUG -module-cache-path .build/ModuleCache \
  apps/ios/Along/Models.swift apps/ios/Along/OnboardingModel.swift \
  apps/ios/Along/PipProgression.swift apps/ios/Along/JournalBackup.swift \
  tests/ios/BackupTests.swift -o .build/backup-tests
.build/backup-tests
```

Repeat without `-D DEBUG` for the Release test executable. The new standalone files require the root progression model additions; the older research-worktree baseline alone does not contain those types.

The full integrated iOS build and device Files flow still need verification: export to Files, cancel, re-import, inspect counts, confirm, relaunch and compare records; corrupt file; denied/unavailable provider; replacing a nonempty journal; restore failure; and restore without a subscription. A local CLI round trip does not establish cloud-provider behaviour or signed-device compatibility.
