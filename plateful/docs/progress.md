# Along — playbook progress

Updated 23 November 2026. Working name: Along. Along is a peptide protocol tracker (supporting tool, not medical advice). The GLP-1 journal and Pip companion are retired. **Market Gate A is not passed.**

## Latest — 3D injection-site picker, 23 November 2026

Branch `feature/3d-injection-site-picker`: choosing a peptide in the dose sheet opens a full-screen SceneKit body (gender-neutral mannequin). Drag spins it 360°; tapping an area (abdomen quadrants, delts, triceps, love handles, ventroglute, dorsoglute, outer thigh) zooms the camera in and shows that area's exact spots with recent-use heat. Logs store the exact spot in the new optional `DoseLog.spot` (e.g. `abdomen.left.lower.3`) and the nearest legacy `site`, so Progress, exports and old logs keep working; backups accept and validate `spot`. The body and spots come from `tools/body-model` and ship as two data assets. The picker records history only and never ranks or suggests a spot.

**Verified 23 November 2026** (Xcode 27.2, iOS 27.2 Simulator; iPhone 18 Pro, iPhone SE 3rd gen, iPad Pro 11-inch):

- The patch compiled without changes: no errors and no warnings from the new files. `bash scripts/check.sh` passes: 30/30 Node tests, 194 domain, 81 protocol (including the new spot tests), 49 billing, 45 reminder, 60 + 61 backup and 66 day-identity checks. The web build was skipped because `apps/web` dependencies aren't installed.
- `testTodayLogsDosesAndDoseSheetSavesDetails` passes, picking `abdomen.left.lower.1` through the picker. Full `AlongUITests`: 13 passed, 13 skipped (retired Pip tests), 4 failed. The same 4 fail identically on `main` (Health chart, Protocol tab, Journey and Dev Lab scenarios), so none comes from this branch.
- Checked in the Simulator, using temporary UI-test drivers and screenshots (`docs/screenshots/3d-site-picker/`):
  - The body renders light grey with smooth lighting, no inverted faces and no z-fighting.
  - Drag spins it through Right side → Back → Left side.
  - Tapping a zone zooms in and fades the other zones. The spot counts are 16 abdomen, 3 ventroglute, 4 dorsoglute, 3 love handles, 2 delts, 2 triceps and 4 outer thigh.
  - Tapping the hip on the screen's right opens Ventroglute · Left. The Left/Right toggle and every area chip work.
  - Choosing a spot fills the card ("Abdomen · Lower left", "Spot 3 · Not in your recent logs") and the dose row ("Abdomen · Lower left · Spot 3"). Today shows "L abdomen, lower #3".
  - Heat counts and the last-used clock icon show. Editing a log zooms straight to its saved spot. Skip clears the site and Back changes nothing.
  - With Reduce Motion on, spots appear about 0.7 s sooner because the camera move is skipped. VoiceOver reads each spot's title and history.
- Two fixes were made after running it:
  - **Rotation and resize:** spots were re-projected before SceneKit had its new viewport, so they drifted off the zone after an iPad rotation. They are now re-projected from the `SCNView`'s own layout.
  - **Dark mode:** quadrant labels, spot badges and the selected spot used the adaptive ink, which turned white over the always-light body. They now use a fixed dark ink, so light mode is unchanged.
- Known issues, left for a re-export of `tools/body-model`:
  - zone edges are stair-stepped, because decals are whole mesh triangles;
  - love-handle spots 2 and 3 overlap, because the `flank` focus yaw is too side-on;
  - abdomen spots crowd and overlap, worst on iPhone SE and iPad landscape, because the abdomen `halfHeight` is fixed in `export_asset.py`.
- Release momentum still adds about 15° even after a pause before lifting the finger. This was seen with synthesized touches and hasn't been checked on a device.

## Latest — peptide tracker core, 20 November 2026

Local commits (not pushed) deliver the build plan in `docs/peptide-tracker-plan.md`: protocol model, setup handover, Today / Protocol / Progress / Settings in the white onboarding design language, dose sheet, dose reminders, Settings rebuild, Pip UI removal, local StoreKit + Superwall `onboarding_end` placement, attribution no-op, peptide Tinybird event allowlist, and optional Crashlytics gated on `GoogleService-Info.plist`.

Still needs accounts or approval: real App Store Connect products and Superwall key (Debug uses `Along.storekit` + `pk_local_storekit`), published legal URLs, Tinybird workspace + Worker deploy, Crashlytics plist, AppsFlyer, Sign in with Apple/Google/email, TestFlight and market validation. No push, purchase or production deploy from this work.

Older sections below remain historical.

## Historical — Pip retained, 1 November 2026

Pip remains the original 2D companion. The app keeps plum, cream and apricot, all 26 onboarding screens and a hard membership gate with **no trial**. New work includes cumulative earned keepsakes and room decorations, one-tap routines, searchable/editable history, historical weekly reflections, editable personal preferences, local backup/restore, optional local reminders and the native Superwall/StoreKit purchase foundation.

Journal writes are transactional. Restores cannot grant membership or revive stale setup ownership. Date-only records retain their civil dates after travel; untouched weight edits retain the exact stored measurement. Debug fixtures and reminder/purchase services remain isolated from real journal data.

Current validation and exact result bundles are recorded in [release implementation](release-implementation.md). The final local check script passes **30 Node tests; 140 core Swift, 49 billing, 36 mocked-reminder, 56 Debug backup, 57 Release backup and 66 date checks; plus the Vite build**. The unsigned Release app compiles for iPhone hardware. Simulator integration and focused corrections provide passing evidence for all 24 UI cases across the recorded runs. The compact iPhone SE checks cover full onboarding, the largest-text dark paywall, earned rewards, preferences Save/Cancel/relaunch and historical reflections. The iPad mini whole-app/navigation and largest-text dark checks also pass after moving its Debug toolbar below content. Full physical-device/VoiceOver review remains open.

[Review the app and 26-screen gallery](screenshots/release-refinement/index.html) · [Pip comparison](screenshots/release-refinement/pip-comparison.html).

This is a working local implementation, **not a public paid release**. Real App Store products/Superwall settings, signing, published legal/support information, sandbox subscriptions, physical-device accessibility/notification review and market validation remain open. No deployment, purchase, external message or submission occurred. Older sections below are historical and describe earlier prototype states.

## Phase 0: Find and validate the niche — ⚠️ partially done

- [x] Ask about audience access, repeated prompts, complaints and paid apps. User response: investigate; no existing audience confirmed.
- [x] Compare three directions with the seven exact criteria, references and watch-outs.
- [ ] Verify a 1–3★ review cohort and current category/grossing context. Access limitations are documented.
- [x] Draft ten video hooks and one-week test plan.
- [x] Draft waitlist copy; Worker + D1 implementation/verification is owned by the API/web contributor.
- [ ] Human publishes videos and waitlist and runs the one-week test.
- [x] Calculate first-year economics at the $29.99/year hypothesis, including store-fee and full annual AI sensitivities.
- [ ] Gate A: ≥25/35, no 1s, demand signals and sufficient acquisition economics. Along is 23/35 with AI-engine 1; no observed Along commercial funnel exists.

Done: [assessment](phase0-assessment.md), [validation kit](validation-kit.md), [references](references.md).

Verified: primary competitor pages and the mixed Shotsy payment discussion were read; score totals and scenario economics were recomputed in Python. No revenue, review-star, retention or acquisition result was fabricated.

Your turn: no permission is needed to continue the already-authorised local prototype. Public validation remains a later human-led activity.

Money: no paid services or spending initiated by research; all funnel values are assumptions.

## Phase 1: Brief — ⚠️ partially done

- [x] Record one-liner, core action, first win, onboarding, pricing preview, boundaries, references, distribution and economics.
- [x] User approved the progress-companion direction.
- [x] Map one reference pattern to each main screen.
- [ ] Complete reference screenshots, full onboarding/paywall teardowns and visual comparison.
- [x] Review the built experience against the brief in iPhone Simulator. Real-device review remains pending.

Done: [brief](brief.md), [parked ideas](later.md). The brief specifies intended behaviour; implementation status is below.

## Phase 2: Accounts and repo — ⚠️ partially done

- [x] Playbook cloned and read; separate contributor worktrees established.
- [x] Verify repository scaffolding, generated Xcode project, commands and ignores.
- [x] Run native build, domain and simulator checks; assemble local commits.
- [ ] Push to an authorised remote repository; no remote application release has occurred.
- [ ] Configure only needed live accounts: Cloudflare/GitHub initially; Apple Developer and Superwall when preparing a real beta/payment test. Other services only when used.

Account availability and login are not assumed. No production infrastructure is required for a local demo.

## Phase 3: Backend and database — local preview verified

- [x] Verify Worker fetch handlers and actual SQL migrations/queries using Node SQLite. Local HTTP smoke passed. Cloudflare/Wrangler runtime and a live D1 binding remain unverified.
- [ ] Create staging bindings and deploy only after the appropriate account is available.
- [ ] Verify staging health, parameterised SQL, error handling and restricted origins.
- [ ] Production resources/migrations remain out of scope for this prototype.

## Phase 4: Auth — deferred for local prototype

- [ ] Better Auth anonymous/session/linking flows and Apple credentials.
- [ ] Rate limits and Turnstile where needed; native bearer and web cookie verification.
- [ ] Verify account deletion once accounts exist. Local-data deletion is a separate day-one requirement.

## Phase 5: AI — deliberately absent from the core

- [x] Decide that day-one check-ins and recaps are deterministic.
- [ ] If later justified: AI Gateway/OpenRouter configuration, model selection, ≥20 grounded-summary eval inputs, quotas, timeouts and cost events.

No mock AI result is claimed as a model-backed feature. This is an explicit product decision, not a completed playbook AI phase.

## Phase 6: Web — local validation preview verified

- [x] Build React/Vite and verify an honest interactive preview at desktop and 390px mobile widths. The visible waitlist remains disabled; no email collection or consent claim is simulated.
- [x] Verify signup adapter gates and API consent/challenge/duplicate/retention logic in local tests with SQLite and mocked Turnstile. Staging D1 and the real Turnstile service remain unverified.
- [ ] Live signup, authentication and Stripe test checkout remain unverified; no real payment is intended now.

## Phase 7: iOS — working local prototype

- [x] All 26 SwiftUI onboarding screens, resumable choices, an actual first entry, a direct paid offer with no trial, and a separate confirmed Debug preview route.
- [x] Check-in, journey, optional weight, milestones, recap and Pip customisation. Five new transparent character renders are used throughout the native app.
- [x] Local persistence, export and deletion; explicit fictional 14-day sample mode. Persistence and deletion are UI-tested; the export share-sheet destination has not been round-trip tested.
- [x] Run domain checks, build the simulator target and inspect the running app. Latest onboarding verification is recorded below.
- [ ] Staging API/auth connection, App Store Connect setup, Superwall and sandbox entitlements.
- [ ] Android remains parked until the first platform is validated.

## Phase 8: Payments and entitlements — deferred

- [x] User chose a hard paywall with no trial. Direct paid pricing hypothesis: US$29.99/year or US$5.99/month; no free introductory period.
- [ ] Configure localised App Store products and verified entitlements.
- [ ] Superwall/Stripe sandbox setup; signed, idempotent webhooks and server-side entitlements.
- [x] Show immediate-charge/renewal disclosures, Terms and Privacy in the native offer.
- [ ] Connect and verify real purchases and Restore Purchases. The local alerts do not unlock access or claim success.
- [ ] Verify cross-platform sandbox entitlement behaviour.

The $29.99/year display is a proposal only. No charge, trial or renewal occurs in the prototype.

## Phase 9: Analytics and errors — pending

- [x] Verify a minimal non-sensitive API event schema; exclude record contents and health values. No native events are emitted and no live pipeline is connected.
- [ ] Configure Tinybird pipeline and funnel/retention/error dashboards if moving to a live beta.
- [ ] Test a complete staging event path and intentional error; distinguish sample/test sessions.

## Phase 10: Polish — pending device review

- [x] Verify first-run, empty/sample/populated states and restart persistence in Simulator. Save/read failures have explicit UI handling; filesystem fault injection remains pending.
- [x] Inspect Today in dark mode and accessibility-extra-large text; fix title scaling and verify the result. Native controls and accessibility labels are present.
- [ ] Complete all-screen VoiceOver, reduced-motion and real-device accessibility review.
- [ ] Human reviews a real-device build and signs off on the experience.

## Phase 11: Retention — prototype loop specified, outcomes unknown

- [x] Verify factual weekly recaps, personal milestone inclusion and cumulative accessory retention without streak penalties.
- [ ] Optional reminders/widget only after user value and permission; timezone/quiet-hour controls.
- [ ] Optional welcome messages only if those services are later introduced; no trial or trial reminder is planned.
- [ ] Measure return behaviour; no retention claim until a cohort matures.

## Phase 12: Launch — not started

- [ ] Privacy/security review, store listing, labels, terms, screenshots and name clearance.
- [ ] TestFlight signing and real-device beta; account configuration may be needed.
- [ ] Human-controlled submission and production deployment with rollback plan.
- [ ] Store approval and production health check. No production release is currently authorised.

## Phase 13: First 1,000 downloads — not started

- [ ] Human-run content and creator test, attributed links and transparent spend accounting.
- [ ] Sharing/referrals only if requested by users and with explicit privacy controls.
- [ ] Measure downloads, activation, paywall reach, direct purchase and acquisition cost separately.

## Phase 14: Grow to profit — not started

- [ ] Weekly measured revenue, costs, errors and D7/D30 retention report.
- [ ] Improve one demonstrated user problem and test one commercial change at a time.
- [ ] Scale only when net economics and retention support it; no infrastructure expansion for hypothetical AI volume.

## Onboarding, Pip and Dev Lab — 1 November 2026

The 26-screen setup now persists answers and the first entry before a direct paid offer. There is no trial. The intended prices are US$29.99/year and US$5.99/month. Checkout and restore show honest unavailable-service alerts; the confirmed Debug preview does not create an entitlement. Five original transparent Pip renders replace the earlier drawn character throughout the app.

Debug builds include **Dev Lab** from both onboarding and the main app. It provides the 26-screen catalogue; fresh/halfway/paywall setups; empty, 14-day, sparse and 30-day journals; direct feature shortcuts; appearance, text-size and reduced-motion controls; JSON inspection; a save-error alert preview; reset/reload controls; and a saved sandbox that can be resumed after restart. Each new scenario has its own protected storage, separate from the normal journal and credentials. Automated UI tests have a separate Dev Lab storage scope. Release builds exclude the tools.

[Screen review and captures](onboarding-review.md) · [Pip art and provenance](pip-art-direction.md).

Completed onboarding UI evidence:

- `.build/onboarding-final-ui.xcresult`: all 26 screen captures, full setup-to-gate flow, interrupted-setup resume, unconnected purchase/restore, sample check-in/edit/relaunch, weekly reflection, weight entry and local deletion passed. The initial run also contained two failing scrolling checks.
- `.build/onboarding-accessibility-final.xcresult`: the two follow-up cases passed after correcting gesture bounds, adding milestone keyboard dismissal, applying an explicit dark-review appearance and compacting the paywall footer at accessibility text sizes. These cover milestone creation and screens 21/26 with the largest Dynamic Type setting.
- Native light/dark captures were inspected. Pip's ambient animation now transforms one render instead of crossfading two character poses.

Final Dev Lab verification:

- `.build/dev-lab-verified.xcresult`: three UI cases passed, covering empty/sample/sparse/month scenarios, the 26-screen catalogue, feature shortcuts, save/reload/restart/resume and preservation of the original onboarding.
- `.build/dev-lab-setup.xcresult`: the fourth case passed for fresh, halfway and paywall shortcuts. [Dev Lab captures](onboarding-review.md#dev-lab) were exported unchanged and visually inspected.
- Debug and Release native builds passed. The Release binary excludes the Dev Lab strings and controls. The initial sandbox reinitialization loop was fixed by creating its store once in the launch action; disposable directories from the failed test were removed.
- All **83 domain checks passed directly in iOS Simulator**, using the existing `CoreTests.swift` compiled for `arm64-apple-ios17.0-simulator` and run with `simctl spawn`. The final macOS-host rerun encountered Cocoa 513/EPERM on protected writes while the Mac was locked; an ordinary temporary-file write succeeded. Production file protection and test assertions were retained.
- All **30 Node checks** and the Vite production build passed. No live service, payment or deployment occurred.

The existing four app tabs are Today, Journey, Pip and You. Live billing, cloud accounts, reminder delivery, analytics, real-device checks and market validation remain pending.

## Finch reference pass — 1 November 2026

Mobbin MCP became available on the latest retry. Inspected Finch home, wardrobe and onboarding images directly, plus broader self-care search results. Applied two Finch patterns to **Today and Pip** in native SwiftUI, using the user's confirmed plum, cream and apricot direction and the existing original Pip renders.

- [Finch home](https://mobbin.com/screens/e7f40efd-01a8-4f03-828e-31db0c35dbc2): a character room above compact daily actions. Along now uses an original reading nook, a direct check-in button and individual routine rows. Tapping the room opens Pip. No energy, currency or health-task reward system was added.
- [Finch wardrobe](https://mobbin.com/screens/fd25240a-f998-4164-bbcf-abbe3fff15d4): character preview above visual choices, with a selected state. Along's three existing keepsakes now appear directly below Pip with a “Wearing” label. Their existing availability and persistence rules are retained.
- The room is drawn locally with SwiftUI. It adds no image service, package or animation. At accessibility text sizes, the speech moves above the room and keepsake choices become vertical rows.
- The 26-screen onboarding, no-trial offer, journey records, weekly reflection and Dev Lab remain available. This pass changes Today and Pip; it does not redesign all 26 onboarding screens.

Comparison files contain the actual simulator captures, embedded so the HTML opens independently: [Today light](screenshots/finch-refresh/today-light.html), [Pip light](screenshots/finch-refresh/pip-light.html), [Today dark](screenshots/finch-refresh/today-dark.html), [Pip dark](screenshots/finch-refresh/pip-dark.html).

Evidence limitation: the applied reference patterns come from one product, Finch. They are visual design references, not proof of retention, conversion or demand.

Verification for this pass:

- `bash scripts/check.sh`: **30 Node tests, 83 Swift domain checks and the Vite production build passed** on the host. Log: `.build/finch-checks.log`.
- `.build/finch-redesign.xcresult`: review captures, keepsake persistence and the existing check-in/edit/relaunch flow passed (3 tests).
- `.build/finch-final.xcresult`: light/dark/largest-text actions, keepsake persistence and Dev Lab setup shortcuts passed (3 tests).
- `.build/finch-delivery.xcresult`: final layout and keepsake persistence passed (2 tests), including check-in and selection at the largest accessibility text size. Verified the running simulator through the native UI as well.
- `.build/finch-screen-captures.xcresult`: the design review case passed again with full-screen capture. The runner intermittently omitted native bars in Today captures; its light/dark comparison panes use the earlier `.build/finch-final.xcresult` captures, whose layout was checked against the final running app. Pip panes use the final screen-capture run. This is a capture limitation, not a claim of completed real-device review.
- Release simulator build passed; log `.build/finch-release-delivery.log`. No payment, deployment or external service was activated.

## Full app styling and 2D Pip — 1 November 2026

This pass extends the confirmed plum, cream and apricot direction to all 26 onboarding screens, Journey, check-ins, milestones, optional weight entry, weekly reflections, You, Privacy and membership views. Shared components provide rounded choice cards, coloured icon tiles, consistent fields and companion headings. Existing records and the hard paywall remain intact: **no trial**. Checkout and restore are still disconnected and cannot grant access. Debug preview remains an explicitly labelled development route.

Pip now uses five original transparent 2D illustrations and a matching opaque app icon. The reading nook remains native SwiftUI. The new interactions are:

- Tap or hold Pip for a friendly reaction and haptic feedback. Reduced Motion suppresses movement. Petting has no effect on records or rewards.
- Choose a reply in one of three original, scripted stories. A discovery is saved locally and can be revisited; it survives restarting, appears in export as fictional companion content and clears with local data. There is no live AI chat.
- Preview locked keepsakes without equipping or unlocking them. Available keepsakes retain the existing recorded-day rules and persistence.

References inspected through Mobbin: Finch’s [petting](https://mobbin.com/flows/3644cfb2-cfe3-42d4-b910-02eb4f8ce3b5), [chatting with a pet](https://mobbin.com/flows/6af44145-2846-4ab8-857a-3225dc3f8760), [outfit preview](https://mobbin.com/flows/8d11ddab-533c-4a91-aa43-1c5541c6fd33) and [onboarding](https://mobbin.com/flows/80ef83ef-f872-4825-b18d-6b193d60a9aa). Applied patterns are a visible companion, short story exchanges, saved discoveries and a character preview above visual choices. Artwork, writing, palette and room are Along’s. No Finch currency, energy or penalties were introduced. These are references from one product, not conversion or retention evidence.

Review: [all 26 screens and app gallery](screenshots/whole-style/index.html), [onboarding review](onboarding-review.md), [2D artwork provenance and prompts](pip-art-direction.md).

Verification for this pass:

- `bash scripts/check.sh`: **30 Node tests, 91 Swift domain checks and the Vite production build passed**. The added domain checks cover discovery validation, persistence, replacement, export, reset and separation from health records and entitlement state. Log: `.build/whole-style-checks.log`.
- `.build/whole-style-ui.xcresult`: 17 UI cases ran. Fourteen passed, including all 26 onboarding captures, petting/story/discovery persistence, keepsake persistence, journal editing, interrupted setup, weekly reflection, Dev Lab isolation and the disconnected purchase/restore gate. Three failures exposed two layout issues: the Journey add button was obscured by the Debug strip, and the companion name field sat too low above the fixed footer.
- Moved the Journey menu into its page header and the companion name field above Pip’s room. `.build/whole-style-fixed.xcresult`: **all four focused cases passed**, covering milestone creation, complete onboarding to the hard gate, weight entry/deletion and refreshed app screenshots. Across the initial and focused runs, all 17 UI cases have passing results.
- `.build/whole-style-accessibility.xcresult`: the dark-mode/largest-text case passed again with stronger assertions that both annual and monthly plans can actually be selected. The test scrolls their centres into the usable content area before tapping; the selected price also appears in the fixed footer.
- Debug and final Release simulator builds passed. Release log: `.build/whole-style-release-final.log`. Inspected all 26 opening screens, app screens, story states and dark/large-text captures. Also inspected Today, Journey’s corrected add button and Pip directly in the running Simulator. Native bars are intermittently absent from XCTest screenshots; the captures are preserved unchanged, and the running app was checked separately.
- [Pip comparison](screenshots/whole-style/pip-comparison.html) and [welcome comparison](screenshots/whole-style/welcome-comparison.html) embed their before/after screenshots and open independently. The complete gallery keeps the original screenshot files alongside its HTML. Screen 20 and Journey captures were refreshed after their fixes.

Pip remains Along’s original companion. Live billing, cloud accounts, reminder delivery, analytics, full VoiceOver and real-device review remain pending. No payment, deployment or external service was activated.

## Implementation verification log

Native: Xcode 26.3, iPhone 17 Pro simulator, iOS 26.3. Project: `apps/ios/Along.xcodeproj`, scheme Along. No signing or Apple Developer account needed for the simulator build.

- `xcodebuild ... test` completed the three main UI flows with **0 failures**: blank onboarding/milestone, sample onboarding/check-in/edit/relaunch, optional weight/local-data deletion/relaunch. Result: `.build/AlongVerified2.xcresult`.
- A focused fourth UI test of the completed weekly reflection and two sample milestones passed: `.build/AlongReflection.xcresult`.
- `swiftc apps/ios/Along/Models.swift tests/ios/CoreTests.swift ...` and the resulting binary passed **21 checks**: same-day replacement and identity, date boundaries, routine removal, note/title limits, kg/lb conversion, persistent cosmetic unlocks, sample provenance and Codable round-trip.
- The weight UI test initially scrolled past the chart. Smaller bidirectional scrolling corrected the test. The chart was also updated to separate fictional sample records from personal records, with a dashed sample series and legend.
- Today was visually inspected in light/dark appearance and accessibility-extra-large text. Serif titles now use SwiftUI `ScaledMetric`; original simulator settings were restored. Full VoiceOver and device testing is still pending.
- Screenshots: [Today](screenshots/along-today.png), [Journey](screenshots/along-journey.png), [Pip](screenshots/along-companion.png), [Welcome](screenshots/along-welcome.png), [dark](screenshots/along-dark.png), [large text](screenshots/along-large-type.png).

API: 25 Node tests pass, including actual SQL migrations executed against in-memory SQLite. A parent-run localhost HTTP smoke test also passed: health 200 with `liveReady:false`, check-in response `stored:false`, disabled waitlist 503. No provider calls occurred. `apps/api/README.md` documents all activation boundaries.

The app uses protected local JSON excluded from device backups. Failed reads do not silently overwrite the journal. Per-entry sample labels survive editing and export. Keychain/URLSession utilities exist as dormant seams; there is no account or cloud connection. Pricing is a non-purchasable preview. Live services, TestFlight and real market results remain unverified.


Web: 5 Node checks pass; Vite 8.3.5 production bundle builds with pinned React/ReactDOM 19.3.1. Headless Chrome/Playwright verified desktop and 390px mobile layout, explicit mood/appetite choice, 500-character note cap, save/journey, same-day edit, milestone accuracy, reset cancellation/confirmation, disabled waitlist, no browser storage and no external requests. Screenshots were visually inspected. Browser-only state deliberately clears on refresh; native local persistence is separate. A test assertion was made case-insensitive to account for CSS text capitalisation.

Run commands from `plateful`: `bash scripts/check.sh`, `bash scripts/dev-api.sh`, `bash scripts/dev-web.sh`. The web preview is localhost-only. All source is assembled on `codex/glp1-nutrition`; no remote push or publication occurred.
