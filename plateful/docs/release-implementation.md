# Along release refinement — in progress

The active goal is to turn the approved adult GLP-1 progress companion into a usable release candidate. Keep Pip, the original 2D artwork, plum/cream/apricot, 26 onboarding screens, and a hard membership gate with **no trial**. This is local implementation work, not authorization to deploy or submit to the App Store.

## Screen decisions and reference evidence

Baseline: `dedfb28`. Existing style screenshots remain in `docs/screenshots/whole-style`. The companion had petting and three immediate stories, three accessories, and no clear next milestone. Routine rows all opened a full check-in. Journey hid removal in a long-press menu. The paywall used illustrative prices and could not purchase.

Five moves in the first refinement pass:

1. **Today:** tap a selected routine to record or undo it without inventing mood/appetite. Keep the full check-in separate. [Finch goal completion](https://mobbin.com/flows/2d8a4c8a-20d1-4239-b528-c4fbd26742a7) shows direct completion followed by feedback. Along omits currency, energy meters and streak repair.
2. **Pip:** show cumulative recorded days, the next keepsake and a clear claim state. [Finch milestone claiming](https://mobbin.com/flows/f9db79f5-0f15-474a-8756-5ff201c81062) and [daily quest claims](https://mobbin.com/flows/f6d05d67-c3af-4e77-9ca4-e6326ed0862a) distinguish progress, eligible rewards and collected rewards. Along counts distinct non-sample days, keeps rewards after absences/deletion, and never uses weight, appetite or medication as reward criteria.
3. **Pip's room:** notebook at 1 day, scarf at 3, bloom at 7, plant at 14, light at 30, stars at 60. Starter accessory remains a gift. Stories open at corresponding stages; completed discoveries can be revisited. Room art uses original native shapes and the existing Pip assets.
4. **Journey:** visible edit/delete controls, searchable notes/milestones and routine-only records. [Bears Gratitude editing](https://mobbin.com/flows/21a2b32f-12a3-457a-b7e0-75bd7a8a7677) makes editing an explicit action; [5 Minute Journal editing](https://mobbin.com/flows/882d4eae-e7bb-40c7-bb78-c84ee3067da4) returns a saved record to a readable view. Along retains its chronological timeline and native forms.
5. **Membership:** separate current membership management from purchase selection; provide restore and direct App Store management. [Ro subscription management](https://mobbin.com/screens/39dc1f21-1599-4f25-a377-bfd3a64f19d3) makes account actions explicit. Along keeps data/reminder controls outside paid access. No conversion or retention effect is inferred from these reference screens.

## Implementation now present

- Transactional journal updates publish only after a successful protected atomic file write. Backup-exclusion metadata is set on the containing directory before the write, so a metadata error cannot create an apparent failed transaction after replacing the journal.
- A persistent day/reward ledger, claimed keepsakes, room props, six stories, locked previews and development scenarios at 1/30/60 days.
- Independent optional routine records, editable timeline records, search and a rolling seven-day recap that includes routines.
- Validated, bounded local backup/export/import with explicit replacement confirmation; no credentials or membership grants in backups. Restore generation fences stale onboarding ownership after interruptions.
- Optional local daily/weekly reminders with explicit permission on Save, denial/error handling and disabled delivery in review/sandbox contexts.
- Pinned Superwall 4.18.3, verified StoreKit entitlement checks, actual localized product prices, purchase/restore/pending/cancel/expiry/revocation handling, and no-trial offer validation. SDK test grants and event analytics disabled. Release access requires a verified entitlement independently of setup completion.
- Native privacy manifest for app-owned UserDefaults preferences. Full SDK/privacy-label/legal review remains an owner release gate.

## Verification record and remaining work

Intermediate integrated Debug simulator build passed against the real pinned SDK. At the pre-review snapshot, all 30 Node checks, 116 core Swift checks, 49 billing-policy/configuration checks, 36 mocked reminder checks, 56 Debug backup checks and 57 Release backup checks passed; Vite production build passed. A macOS-only test failure was traced to unsupported iOS `completeFileProtection`; production iOS writes retain that protection. Final review fixes still need their own regression results.

The first native progression test passed end to end: a real routine earns one day, sample history earns none, a notebook can be claimed, undo does not remove it, and it survives relaunch. The full integrated native suite is in progress; its all-26-screen capture and backup/reminder preview cases have passed. It exposed a large-text paywall layout issue and a milestone visibility assertion that are being resolved. Do not interpret these intermediate results as final candidate validation.

Read-only review identified recovery from corrupt files, stale/missing setup drafts, routine/check-in consolidation after restore, weight-unit initialization, expired-member data controls and preview isolation. Fixes are being integrated and regression tests added. A further stable calendar-date identity fix is in progress to protect records and backups when travelling across timezones.

No valid code-signing identity was found in the accessible local keychain (`0 valid identities found`). No real App Store products, Superwall key, published terms/privacy URLs or signed-device purchase evidence have been provided. These remain concrete release gates; no fake values are substituted. See `release-readiness.md`, `billing-integration.md`, `release-reminders.md` and `local-backup-integration.md` for their specific acceptance criteria.

Apple describes backup exclusion as guidance to the system, not a guarantee. Along's in-app privacy language reflects that limitation. [Apple: optimizing data for iCloud Backup](https://developer.apple.com/documentation/foundation/optimizing-your-app-s-data-for-icloud-backup).
