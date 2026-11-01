# Along release refinement

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
- Independent optional routine records, editable timeline records and search. Weekly reflections show explicit date ranges, earlier/later weeks, factual counts and links back to the underlying records.
- A Save/Cancel preferences sheet for routine wording, encouragement, intention and journey start date; current name, routines, weight visibility/unit and reminders remain editable in You.
- Stable civil-date keys keep check-ins, weights, milestones and routines on their chosen date after travel. Schema-2 backups preserve these keys; schema-1 imports normalize using their source timezone. Open check-in editors retain their original record identity during day/timezone refresh.
- Validated, bounded local backup/export/import with explicit replacement confirmation; no credentials or membership grants in backups. Restore generation fences stale onboarding ownership after interruptions.
- Optional local daily/weekly reminders with explicit permission on Save, denial/error handling and disabled delivery in review/sandbox contexts.
- Pinned Superwall 4.18.3, verified StoreKit entitlement checks, actual localized product prices, purchase/restore/pending/cancel/expiry/revocation handling, and no-trial offer validation. SDK test grants and event analytics disabled. Release access requires a verified entitlement independently of setup completion.
- Native privacy manifest for app-owned UserDefaults preferences. Full SDK/privacy-label/legal review remains an owner release gate.

## Verification record and remaining work

`bash scripts/check.sh` passes: 30 Node tests, 140 core Swift checks, 49 billing-policy/configuration checks, 36 mocked reminder checks, 56 Debug backup checks, 57 Release backup checks and 66 stable-date checks. The Vite production build passes. Log: `.build/release-final-checks.log`.

The integrated Debug app builds against pinned Superwall 4.18.3 and Superscript 1.0.15. The final unsigned **Release build for iPhone hardware** passes, with 35 app Swift sources and signing disabled. Log: `.build/release-candidate-device.log`. This verifies compilation, not a signed install, a real purchase or App Store approval.

Native evidence on iPhone 17 Pro / iOS 26.3:

- `.build/release-integrated-ui-v2.xcresult`: 21 cases, 17 initially passed, including all-26-screen capture, complete setup to the hard gate, routine history, earned keepsake/relaunch, pet interaction/discoveries, Dev Lab isolation, backup/reminder availability and data reset.
- `.build/release-review-ui.xcresult`: corrected large-text annual/monthly plan interaction and 60-day room preview passed. Other failures exposed test targeting of nested sheets/alerts and missing fixture links; they were fixed and rerun.
- `.build/release-final-focused-ui.xcresult`: milestone creation, pounds editing without conversion drift, check-in/edit/relaunch and unpaid data controls passed. The remaining Dev Lab shortcut failed because a partially visible Save control was tapped under a sheet boundary.
- `.build/release-dev-lab-final.xcresult`: the Dev Lab shortcut, save, reload and resume passed after using the foreground scroll view and bringing Save fully into view. All 23 pre-preferences UI cases now have passing evidence across the integrated and focused runs. This is not a claim that a single final full-suite run passed.

Compact iPhone SE (3rd generation) / iOS 26.3: `.build/release-compact-ui.xcresult` passed the largest-text dark paywall and earned-routine/relaunch cases. Its setup test tapped a partly covered choice and advanced twice; a failure screenshot showed screen 10 while the test expected 9. Choice and field helpers now scroll controls into the usable content area. The corrected setup plus new preferences/weekly-history cases all passed in `.build/release-compact-final.xcresult` (3 cases, zero failures). Save/relaunch and Cancel preservation were exercised for preferences. All 24 UI cases now have passing evidence across the recorded runs.

iPad mini (A17 Pro) / iOS 26.3: the first run exposed the development strip covering the tablet top navigation. The Debug strip now sits at the bottom on iPad, and tests use the native tablet tab-button representation. `.build/release-ipad-final.xcresult` passes both the whole-app screen/navigation review and largest-text dark check-in/paywall case (2 cases, zero failures). This is simulator portrait coverage, not complete tablet/landscape/VoiceOver certification.

Final test-target compilation also passes in `.build/release-final-test-build.log`. Xcode printed an auxiliary diagnostic-collection warning about locating `simctl` after several completed runs; test result bundles still report their explicit outcomes above. No test success was inferred from that warning.

Review artifacts: [screen gallery](screenshots/release-refinement/index.html), [Pip before/after](screenshots/release-refinement/pip-comparison.html). Captures are actual simulator output, with sample/Dev Lab labels retained. Finch is one example for Pip progression, not independent evidence of retention or conversion. The baseline captures remain unchanged.

Recovery checks cover corrupt journals, failed disk writes, stale/missing setup files, interrupted restore, routine/check-in consolidation, stable IDs and sample provenance, date-line travel, DST, old archive migration and precision-preserving weight edits. Native reminder delivery, complete VoiceOver review, signed-device cold start/resume/offline checks and App Store sandbox purchases remain unverified.

No valid code-signing identity was found in the accessible local keychain (`0 valid identities found`). Real App Store products, the public Superwall configuration, published terms/privacy URLs, support/ownership details and signed-device evidence remain outstanding. The implementation deliberately fails closed without those settings. A public paid release is **not** ready to submit. See `release-readiness.md`, `billing-integration.md`, `release-reminders.md` and `local-backup-integration.md` for acceptance criteria.

Apple describes backup exclusion as guidance to the system, not a guarantee. Along's in-app privacy language reflects that limitation. [Apple: optimizing data for iCloud Backup](https://developer.apple.com/documentation/foundation/optimizing-your-app-s-data-for-icloud-backup).
