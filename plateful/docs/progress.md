# Along — playbook progress

Updated 1 November 2026. Working name: Along; companion: Pip. The user approved the progress-companion direction and explicitly authorised a SwiftUI prototype with mocks. The earlier pantry concept was rejected and is not the current brief. **Market Gate A is not passed.**

The native prototype is implemented and verified in Simulator. Local API and web verification are complete; live services and commercial validation remain pending. Results below distinguish source, local tests and unverified integrations.

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

- [x] SwiftUI onboarding, check-in, journey, optional weight, milestones, recap and Pip customisation.
- [x] Local persistence, export and deletion; explicit fictional 14-day sample mode. Persistence and deletion are UI-tested; the export share-sheet destination has not been round-trip tested.
- [x] Run 21 core checks, build the simulator target and inspect the running app. Four UI flows passed.
- [ ] Staging API/auth connection, App Store Connect setup, Superwall and sandbox entitlements.
- [ ] Android remains parked until the first platform is validated.

## Phase 8: Payments and entitlements — deferred

- [ ] Decide real free/paid boundaries, trial and localised pricing.
- [ ] Superwall/Stripe sandbox setup; signed, idempotent webhooks and server-side entitlements.
- [ ] Disclosures, real Restore Purchases and trial-ending reminders.
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
- [ ] Welcome/trial emails and real trial reminder only when those services exist.
- [ ] Measure return behaviour; no retention claim until a cohort matures.

## Phase 12: Launch — not started

- [ ] Privacy/security review, store listing, labels, terms, screenshots and name clearance.
- [ ] TestFlight signing and real-device beta; account configuration may be needed.
- [ ] Human-controlled submission and production deployment with rollback plan.
- [ ] Store approval and production health check. No production release is currently authorised.

## Phase 13: First 1,000 downloads — not started

- [ ] Human-run content and creator test, attributed links and transparent spend accounting.
- [ ] Sharing/referrals only if requested by users and with explicit privacy controls.
- [ ] Measure downloads, activation, trial start, payment and acquisition cost separately.

## Phase 14: Grow to profit — not started

- [ ] Weekly measured revenue, costs, errors and D7/D30 retention report.
- [ ] Improve one demonstrated user problem and test one commercial change at a time.
- [ ] Scale only when net economics and retention support it; no infrastructure expansion for hypothetical AI volume.

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
