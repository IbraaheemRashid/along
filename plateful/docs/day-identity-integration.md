# Stable journal dates

This change covers check-ins, routine-only days, weight records and milestones. Each retains its original serialized `Date` and gains an optional Gregorian `YYYY-MM-DD` identity (`dayKey` or `dateKey`). A date stays attached to its record when the device timezone changes. It does not change the profile's treatment start date or reminder scheduling.

## Model contract

- `Journal.save(CheckIn, calendar:)` and `save(WeightEntry, calendar:)` stamp new keys in the supplied/current timezone. They update by existing UUID first, then by stable day key. An update retains the existing UUID, raw timestamp, key and sample provenance. Check-in conversion removes a routine-only record on the same stable day; a sample routine remains sample when converted.
- `toggleRoutine`, `recordedRoutines`, `week`, `checkIn(on:calendar:)` and `weight(on:calendar:)` compare stable keys. The week is seven civil date labels ending on the viewer's selected date. It deliberately excludes a record labelled tomorrow relative to that viewer, even if travel made that record legitimate.
- `reconcileProgress` normalizes missing keys before reconciliation. Crediting uses the stable key. Existing credited UUIDs and recorded-day strings are never rewritten, recalculated or awarded again. Normalization and backup decoding alone do not award credits.
- `entry.isOn(date, calendar:)` is the replacement for comparing its raw timestamp with `Calendar.isDate`. `displayDay` / `displayDate` reconstruct local noon for date controls, charts and sorting. `dayText()` / `dateText()` format the date label directly and accept a `Date.FormatStyle`.
- Prefer the text helpers for labels and exports. A historical date skipped in the viewer's timezone, such as Samoa's 2011-12-30, cannot be represented by a local `Date`; the text helpers still display it correctly. `displayDate` falls back to UTC noon in that case.

## Required store and UI integration

1. Include `DayIdentity.swift` anywhere the model sources are compiled, including `scripts/check.sh` and `scripts/check-backup.sh`. The app project generator must include the new source. Add the focused command below to the verification script if desired.
2. Native load/recovery must normalize once and persist the result before presenting editable history. Existing `reconcileProgress` now performs normalization; do not run a second migration in a different timezone. `normalizeDayKeys()` uses the saved Pip ledger timezone, falling back to the current timezone only when no valid source is available.
3. Replace `JournalStore.today` with `journal.checkIn(on: .now)`. Replace raw `isDate` comparisons in onboarding record reconciliation, routine/week counts and history lookup with `isOn` or the journal lookup helpers. Count/filter date keys for date ranges, using `DayIdentity.range`; avoid `Calendar.startOfDay(for: record.day)`.
4. Render check-in/routine labels using `dayText`, and weights/milestones using `dateText`. Use reconstructed display dates for charts, editor initialization and chronological date ordering. Raw timestamps remain storage data. Date ordering can also compare the validated keys directly.
5. Preserve the existing record ID when editing check-ins and weights. A store edit API should accept an optional editing UUID, reject a missing UUID, retain that record's raw date/key, and validate its existing date with `JournalValidation.storedRecordDate`. This permits editing a legitimate Tokyo date while the viewer is still on the previous New York day. Validate its text/weight separately. New records use `recordDate`/`checkIn`, which reject a future selection in the current timezone. Do not reject an unchanged existing date through new-entry validation.
6. All manual appends must stamp the current selected civil key before `updateJournal`/`reconcileProgress`. In particular, onboarding-created records and milestones bypass `Journal.save` in the current store. Pass `dayKey: DayIdentity.key(for: day)` or `dateKey: DayIdentity.key(for: date)`; otherwise the nil value is treated as legacy and uses the original ledger timezone. Prefer `Journal.save` for check-ins/weights to consolidate routine-only records and preserve identity. An onboarding archive's owned record should continue to be found by UUID after travel, not by reinterpreting its raw saved date.
7. For milestone edits, an unchanged selected civil date retains the original raw date and key. An intentional date change receives the selected date's new key and must pass new-entry date validation. Retain its existing UUID and sample flag. Use `old.isOn(selectedDate)` to distinguish these cases; text validation remains independent.
8. Replace the current `addWeight`/`addMilestone` start-of-day guards with `JournalValidation.recordDate` for new/changed dates. Restrict new-entry date pickers to supported dates from 1900-01-01 through local today. Existing editors must still show an unchanged travelled date ahead of the viewer without silently clamping it to today.

## Validation and migration limits

Keys must be exactly ten ASCII characters, a real Gregorian date, and in years 1900 through 9999. Present-but-null, non-string, malformed, unrelated and unknown fields are rejected by backup shape/semantic validation. A raw timestamp must be compatible with the key under a real-world UTC offset between −12 and +14 hours. New-record validation requires a finite supported date no later than local today. Notes allow newline and tab, but reject other control characters consistently with backup validation.

A stored key can legitimately be one day ahead of the viewer after crossing the date line. It is therefore bounded by the latest civil date currently possible (UTC+14), together with the raw timestamp compatibility check. The retained `Date` is a date-picker selection, not an observed event timestamp: its clock time may still be later on that selected date. Rejecting it merely because that clock time is in the future would break date-only records on import. This validation establishes internal date consistency; it does not prove where the user was or that an activity occurred. It grants no payment access. A key after the latest possible current civil date is rejected.

Schema 2 writes stable keys. The decoder still accepts schema 1, validates its timestamp-only records against the archive's explicit source timezone, and stamps missing keys before returning a schema-2 value. Subsequent imports preserve those keys regardless of destination timezone. Unknown-field checks, limits, sample flags and access-flag exclusions remain in force. Prior versions that only support schema 1 will reject newly exported schema-2 archives.

Legacy native records do not contain their original per-record timezone. The ledger timezone is the best available native source; the archive source timezone is used on import, even if its ledger has another timezone. If an old file already contains records created across several zones, their original intent cannot always be recovered. This migration never silently guesses different dates to resolve a collision, deletes records or invents reward credit. Ambiguous duplicate days remain a validation failure that needs recovery with known source information.

## Focused verification

`tests/ios/DayIdentityTests.swift` covers London-to-New-York day collapse; stable edits and upserts; separate weights; routine consolidation; unchanged sample provenance; week boundaries; schema-1 migration; cross-timezone schema-2 round trips; unchanged existing ledger credits; DST gaps and folds; skipped historical civil dates; malformed/unrelated/duplicate keys; date-line and date-only records; strict legacy future dates; and public date/text validation.

Run from the repository app directory:

```sh
mkdir -p /tmp/along-day-identity-check
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -D DEBUG \
  -module-cache-path /tmp/along-day-identity-check/ModuleCache \
  apps/ios/Along/Models.swift apps/ios/Along/OnboardingModel.swift \
  apps/ios/Along/PipProgression.swift apps/ios/Along/DayIdentity.swift \
  apps/ios/Along/JournalBackup.swift tests/ios/DayIdentityTests.swift \
  -o /tmp/along-day-identity-check/tests
/tmp/along-day-identity-check/tests
```

Existing backup test fixtures need two intentional updates: use `JournalBackup.currentSchema + 1` for an unsupported version, and move the impossible future ledger date to 2026-11-03 for the fixed 2026-11-01T12:00Z test clock (2026-11-02 already exists in UTC+14). When testing a duplicate day, change the stable key as well as any raw timestamp; changing only a timestamp now tests key/timestamp consistency instead.
