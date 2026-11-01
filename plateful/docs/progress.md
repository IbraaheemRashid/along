# Along — playbook progress

Updated 1 November 2026. Working name: Along; companion: Pip. The user approved the progress-companion direction and explicitly authorised a SwiftUI prototype with mocks. The earlier pantry concept was rejected and is not the current brief. **Market Gate A is not passed.**

This file records the research handoff. The implementation owner must append actual build, test and simulator results; none are inferred from a brief or source scaffold.

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
- [ ] Review the built experience against the detailed brief on a device.

Done: [brief](brief.md), [parked ideas](later.md). The brief specifies intended behaviour; implementation status is below.

## Phase 2: Accounts and repo — ⚠️ partially done

- [x] Playbook cloned and read; separate contributor worktrees established.
- [ ] Verify final repository scaffolding, commands, ignores and appropriate dependencies.
- [ ] Run project checks and commit/push the assembled app. A research-document commit is not a pushed application release.
- [ ] Configure only needed live accounts: Cloudflare/GitHub initially; Apple Developer and Superwall when preparing a real beta/payment test. Other services only when used.

Account availability and login are not assumed. No production infrastructure is required for a local demo.

## Phase 3: Backend and database — pending integration verification

- [ ] Verify local Worker/D1 routes and migrations against the approved scope.
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

## Phase 6: Web — pending implementation-owner results

- [ ] Verify React/Vite waitlist, honest demo/live state, consent and mobile layout.
- [ ] Verify Worker/D1 signup persistence and duplicate handling locally/staging.
- [ ] Live signup, authentication and Stripe test checkout remain unverified; no real payment is intended now.

## Phase 7: iOS — in progress; implementation owner to update

- [ ] SwiftUI onboarding, check-in, journey, optional weight, milestones, recap and Pip customisation.
- [ ] Local persistence, export and deletion; explicit fictional 14-day sample mode.
- [ ] Run core-logic checks, build simulator target and inspect the running app.
- [ ] Staging API/auth connection, App Store Connect setup, Superwall and sandbox entitlements.
- [ ] Android remains parked until the first platform is validated.

## Phase 8: Payments and entitlements — deferred

- [ ] Decide real free/paid boundaries, trial and localised pricing.
- [ ] Superwall/Stripe sandbox setup; signed, idempotent webhooks and server-side entitlements.
- [ ] Disclosures, real Restore Purchases and trial-ending reminders.
- [ ] Verify cross-platform sandbox entitlement behaviour.

The $29.99/year display is a proposal only. No charge, trial or renewal occurs in the prototype.

## Phase 9: Analytics and errors — pending

- [ ] Verify a minimal non-sensitive event schema; exclude record contents and health values.
- [ ] Configure Tinybird pipeline and funnel/retention/error dashboards if moving to a live beta.
- [ ] Test a complete staging event path and intentional error; distinguish sample/test sessions.

## Phase 10: Polish — pending device review

- [ ] Verify first-run and empty/sample/populated states, loading/error handling and restart persistence.
- [ ] Verify accessibility, Dynamic Type, VoiceOver, dark mode, reduced motion and tap targets.
- [ ] Human reviews a real-device build and signs off on the experience.

## Phase 11: Retention — prototype loop specified, outcomes unknown

- [ ] Verify factual weekly recaps and cumulative accessories without streak penalties.
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

Pending parent integration. Append exact commands, outcomes, simulator/device used, screenshots where useful, and remaining limitations. Do not promote a phase to complete solely because its files exist.
