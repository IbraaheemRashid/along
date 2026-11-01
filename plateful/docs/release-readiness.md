# Along: release acceptance and remaining configuration

Audit date: 1 November 2026. Source baseline: `dedfb28`. This document records the baseline and acceptance criteria for the next release candidate; it does not certify work merged after that commit. The current implementation/test results belong in `docs/progress.md`.

**Baseline status: useful local prototype, not ready for a public paid release.** The missing essentials are functioning membership, dependable recovery/transfer of the personal record, promised reminder behaviour, sustained Pip progression, release configuration and real-device verification. No account creation, signing, purchase, deployment or store submission was performed by this audit.

The release product is an **adult GLP-1 personal record with Pip**, in plum, cream and apricot. Keep the original 2D character, 26-screen setup and hard no-trial offer. The product does not prescribe nutrition or medication, diagnose, interpret symptoms, or serve children with diabetes.

## Integrated status after this audit

The implementation now includes earned Pip development, transactional editing, versioned backup/restore, stable dates, reminder scheduling, editable preferences, earlier weekly reflections and a pinned Superwall/StoreKit billing foundation. Use [the current implementation record](release-implementation.md) for actual test evidence. The baseline table below is preserved as the audit trail, not a description of the current source.

R1/R2 remain open for real configured product and sandbox purchase evidence. R6/R9 need physical-device notification/accessibility verification. R8/R10/R11 need final legal/support/privacy/signing/brand ownership inputs. R12 has no observed commercial results. Passing local tests does not close these gates. Native billing uses Superwall's direct purchase API; remote dashboard placements are only required if a remote paywall is later introduced.

## Screen jobs: onboarding

Each row is an acceptance condition, not a claim that the baseline already satisfies it. Names correspond to `OnboardingView.titles`; source indices are zero-based but user-facing steps below are one-based.

| Screen | User's job | Required result and verification |
|---|---|---|
| 01 · Your journey. A little company. | Understand what this app is and whether it costs money. | Explain adult personal record + Pip; show paid membership after setup and no-trial expectation before collecting answers. Start and resume work. |
| 02 · First, what should we call you? | Choose a comfortable name. | Optional nickname; bounded input; blank is valid; keyboard never hides Continue. |
| 03 · Where are you in your journey? | Add context without clinical questions. | Preparing/recent/established/maintenance choice persists and changes relevant context, not medical advice. |
| 04 · Every story has a beginning. | Optionally record a start date. | Skip works; no future date; user can later change it. Distinguish treatment start from the first Along check-in. |
| 05 · What brings you here? | Say what would be useful. | Chosen priority appears in the personal-space summary or useful content. No unused questionnaire step. |
| 06 · What gets in the way? | Explain the tracking obstacle. | Tailor explanation/help to the answer. Never claim to diagnose a barrier. |
| 07 · The little things tell a bigger story. | See the app's output before investing more time. | Demonstrate the check-in → history → reflection sequence with clearly marked examples. |
| 08 · What would you like to notice? | Choose meaningful kinds of progress. | Select 1–3 areas, enforce limit, use them in future prompts. No measured improvement inferred from a selection. |
| 09 · Keep your why close by. | Save a personal intention. | Optional text appears in the journal/profile and can be changed. Avoid displaying private text on notifications. |
| 10 · Your journal. Your kind of progress. | Decide whether weight belongs here. | Hiding weight is a real opt-out; weight-free onboarding and app remain complete. |
| 11 · A starting point, if you'd like one. | Optionally add baseline weight. | Clear unit; validated number; decimal separator handling; skip; no target or reward. If weight is hidden, do not imply it is required. |
| 12 · There's room for all of your progress. | Understand the journal being created. | Preview reflects selected areas and weight preference; no invented history or prediction. |
| 13 · Make room for a little routine. | Choose a manageable set of actions. | Zero to two selected routines; no health requirement or score. |
| 14 · Make it your own. | Give routines personally useful wording. | Saved names appear consistently in Today, check-in, history and export; later editing works. Empty selection is handled. |
| 15 · Find a rhythm that fits real life. | Set expectations for frequency. | Flexible/few days/daily changes actual presentation or scheduling. Otherwise explain it as a preference; no implied automatic plan. |
| 16 · A moment that works for you. | Choose an optional reminder. | A chosen time leads to contextual notification permission, accurate enabled/denied state and a settings route. Off schedules nothing. |
| 17 · A little time to look back. | Choose when to reflect. | Day preference drives a real optional reminder or honest display. Recap names match the period shown. |
| 18 · Your kind of encouragement. | Choose Pip's tone. | Gentle/straightforward/celebratory changes relevant copy. None imply guilt, disappointment or diagnosis. |
| 19 · A little more personality. | Make Pip feel like theirs. | Choose from starter cosmetics; show earned rewards separately. Setup cannot silently grant all later progression. |
| 20 · A name for your little companion. | Keep Pip or use a nickname. | Bounded optional name; Pip fallback; propagates through headings and accessibility labels. |
| 21 · Let's begin with today. | Make the first real check-in. | Mood/appetite choices clearly describe self-reports. No healthy/unhealthy label; no score or dose advice. |
| 22 · One small moment. Worth remembering. | Add something worth keeping. | Optional note; counter and keyboard handling; no fabricated answer. |
| 23 · Your first page. Already yours. | See that the input became a record. | Write succeeds before “saved”; show actual entry; back/next/relaunch across midnight must not duplicate it. |
| 24 · A space that feels like you. | Review what setup produced. | Accurate name, routines, priorities and first entry. Can return to correct choices; a preview fixture stays labelled. |
| 25 · One membership. Your whole journey. | Understand ongoing value. | Describe delivered record, routines, reflections and Pip content. No feature or cloud promise that is absent. Explain that subscribing charges now. |
| 26 · Your next chapter. | Choose annual/monthly membership knowingly. | Localized store product price/period; full billed annual total; no trial/introductory offer; restore, terms/privacy, purchase pending/cancel/error states. Closing returns to setup/offer, never grants access. |

Across all 26: persist and resume the correct step; maintain Back and optional Skip semantics; show selected controls to VoiceOver; support long content and Dynamic Type without a hidden CTA; prevent fixture records from entering the real journal. A long funnel is the user's chosen design, not evidence of better conversion.

## Screen jobs: the daily product

| Screen or state | User's job | Release acceptance |
|---|---|---|
| Today · before check-in | Know what to do next. | One clear check-in action; chosen routines with honest completion state; Pip communicates invitation and next progress step. Empty data never looks like failure. |
| Today · after check-in | Know the save worked and act on a routine. | Saved feedback appears after durable save; edit today's entry; routine changes persist without duplicate check-ins or extra progress awards. |
| Check-in editor | Record or correct a day quickly. | Existing values load; future dates rejected; date collision behaviour explicit; cancel preserves original; failure preserves the draft for retry. |
| Journey | Find what happened. | Chronological history plus usable search/date navigation; open a day; filters indicate empty results; edit/delete discoverable without knowing a hidden gesture. |
| Personal milestone | Keep a moment that matters beyond weight. | Title/date/note/category; edit, cancel and confirmed delete; no award proportional to physical change. |
| Optional weight | Keep an accurate numerical record. | Unit conversion, precision and dates correct in form/chart/export; same-day update policy explicit; hide does not delete or change Pip. Accessible text alternative to the chart. |
| Weekly reflection | Revisit a particular week and its source records. | Visible start/end dates; factual counts; recorded/unrecorded distinction; previous periods reachable; no causal medical claim. Link back to notes/milestones. |
| Pip's place | See relationship progress and interact. | Tap/hold works with accessible alternative; current stage and next unlock are understandable; locked preview is separate from equip; selection persists. |
| Pip story | Share an optional fictional moment. | Original story, bounded choice and saved discovery; skipping is allowed; replay cannot earn again; no simulated clinician or emergency relationship. |
| Keepsakes/room | Use what has been earned. | Clear locked/unlocked/equipped states; visible persistent change; content runway beyond the first week; no currency purchase or random paid reward needed for v1. |
| You/preferences | Change the routine as life changes. | Names, chosen routines and their wording, reminder time/day, encouragement, start date, units and weight visibility are editable. Changes persist and are reflected elsewhere. |
| Membership | Understand current access and control renewal. | Actual status/expiry where appropriate, restore, manage subscription link, clear expired/revoked state. Deleting journal data does not purport to cancel Apple billing. |
| Export/backup/restore | Keep or move the personal record. | Readable export and versioned restorable archive; validate imports before mutation; show replacement consequences; failed import preserves current data; privacy warning before sharing. |
| Privacy/terms/support | Understand data use and contact the owner. | Production wording and working URLs/contact, matching the actual build. No claim of cloud sync, encryption or AI processing that has not been implemented and reviewed. |
| Delete local data | Remove personal content deliberately. | Confirmation; clear journal, setup draft and applicable credentials/notifications; distinguish external exports and subscriptions. Handle write/delete failure honestly. |
| Dev Lab | Reproduce every important state safely. | Debug only; isolated storage; jump to all 26 steps; empty/day 1/threshold/established data; purchase simulation clearly fake; error and accessibility scenarios; never leak fixture access into Release. |

## Pip: acceptance contract

Pip development is an original retention feature, not medical progress. Record participation once per qualifying day, exclude sample/review fixtures, and define how backdated entries behave. A saved ledger or equivalent migration-safe model must prevent replayed stories, edited entries, repeated saves and duplicate imports from generating repeated rewards. Preserve previously earned items after a gap or removal of a journal entry; never create a reason to keep incorrect health data.

Show a small first-session reward, a visible next milestone and a longer sequence of meaningful changes. Starter accessories are gifts; earned accessories/room items/stages have transparent conditions. The exact milestones and content count are product decisions, but three total items and three immediately available stories do not support a strong ongoing-development promise.

Required scenarios: fresh first entry; same-day edit; empty routine selection; sample data; deleting and re-entering a day; backfill; midnight/timezone change; missed week; replay; reinstall/restore; legacy journal migration; all currently available content completed. Pip remains welcoming throughout. No rewards depend on weight loss, low appetite, eating less, a dose, glucose or severity of symptoms.

## Release gates and evidence

These are project acceptance criteria. Where an Apple rule informs a gate, the relevant source is linked; a checklist does not guarantee store approval.

| Gate | Baseline evidence | Required proof before calling the paid app ready |
|---|---|---|
| R1 · Actual membership | Purchase/restore actions are preview alerts; `hasOnboarded` selects access. | App Store products + Superwall configured with the approved stack; purchase and restore verified in sandbox; product fetch failure, cancellation, pending purchase, renew/expire/revoke/reinstall and offline access policy exercised. Entitlement is not a local onboarding flag. |
| R2 · No trial, honest pricing | Preview displays proposed $29.99/year and $5.99/month. | Both real products have no introductory free period; UI matches localized product data and period; annual full price prominent; no fake discount or trial copy. Subscriber benefits delivered immediately; earned cosmetics described as progression. |
| R3 · Durable personal record | Atomic protected file, excluded from backups; readable text export; no import/sync. Some actions mutate memory before successful write. | Safe write/migration/recovery path; injected failures cannot claim a save; backup/restore round trip preserves IDs, dates, units, notes, preferences and Pip state; corrupt/oversized/future-version import rejected without loss. |
| R4 · Everyday utility | Basic check-ins, milestones, weight, feed and rolling recap exist. | A real person can record today, update a routine, find an older note, correct each record type and revisit a past week. No placeholder action in these paths. |
| R5 · Earned development | Three accessories/stories; onboarding gift can be a later unlock. | Integrated progression contract above passes tests; empty, early and established states visually inspected. No fixture inflation. |
| R6 · Reminder promise | Choices saved; notifications explicitly not enabled. | Native local notification scheduling, permission denial, editing/cancelling, timezone/daylight-saving and deep-link destination tested on a device; notification copy exposes no health details by default. |
| R7 · Scope and claims | Adult record-only boundaries documented; deterministic recap. | Review every product string, store screenshot and character response for consistency. No diagnostic, clinical-outcome or dosing claims; no medicine-level graph or nutrition prescription added without a separate reviewed scope. |
| R8 · Privacy and security | Local file protection and deletion exist; live services absent. | Data inventory matches actual native/backend/SDK behaviour; production privacy terms and labels; no health text in logs/analytics; tests for deletion and secret exclusion. If accounts/sync are added, auth, authorization, account deletion and recovery need their own staging proof. |
| R9 · Native quality | Prior `docs/progress.md` records simulator/domain/UI verification. | Build/test the final merged commit; inspect all screens plus errors in light/dark and large text; VoiceOver/Reduce Motion; small iPhone and supported iPad sizes; real-device cold start/resume/offline/storage failure. Record actual results, not just test names. |
| R10 · Release artifact | Development bundle ID and preview version/copy; Debug lab plus regular Settings sample controls. | Final bundle/version/signing/icon/launch configuration; release build excludes developer access/fixtures; current screenshots/metadata; test signed archive on TestFlight. |
| R11 · Ownership and support | Along/Pip are working names; Needled publicly uses Pip for a GLP-1 mascot. | Human brand clearance/ownership review and support contact. Keep chosen name in development; do not claim clearance from a web search. |
| R12 · Commercial evidence | Approved local prototype; Gate A not passed. | Keep product readiness separate from business validation. Measure actual interest/activation/return and no-trial paid conversion before assuming profitability or scaling acquisition. |

Apple's current guidelines require a complete submission and on-device testing (2.1), clear subscription value/information (3.1.2), appropriate health-related claims (1.4), accessible developer contact (1.5), and accurate handling of privacy/security (1.6, 5.1). The review criteria are broader than this audit; the owner must check the final product against the current rules. [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).

## Configuration that cannot be invented locally

Prepare these only when the relevant account is available. Credentials belong in the approved secret store, not source, chat or screenshots. User authorization covers continued local work; these missing resources are facts, not reasons to stop implementation that can be completed safely.

| Owner/account work | Concrete inputs needed | What can be prepared without it |
|---|---|---|
| Apple Developer / App Store Connect | Legal seller, team/signing access, final bundle ID/app record, agreements/tax/banking, subscription group/product IDs and sandbox testers. | Product adapter/config validation, local StoreKit test scenarios, no-trial disclosures, receipt/entitlement state handling, release checklist. Local StoreKit simulations are not sandbox verification. |
| Superwall | Approved app, public configuration key, product mappings, `onboarding_end`/`feature_gate`/`settings_upgrade` placements and entitlement integration. | Adapter, disabled-state handling, placement contract and integration tests. Never invent a live key or claim a configured dashboard. |
| Backend, only if enabled | Cloudflare staging account/domain, bindings and deployment credentials; Better Auth providers/secrets where accounts exist; signed billing integration. | Local handlers/schema/tests and deployment/rollback commands. Keep production routes gated until staging behaviour is verified. |
| Privacy/legal/support owner | Operating entity, support address, launch territories, actual data practices, published privacy and terms URLs, brand decision. | Data inventory, draft in-app explanations and metadata. No claim that a generic template is legal sign-off. |
| Analytics, only if enabled | Tinybird project/credentials and agreed non-sensitive event schema/retention. | Local events with test/sample separation; no entry contents, appetite, weight or story text in event payloads. No dashboard or real cohort metrics claimed before connection. |
| Device review / release owner | Signed TestFlight build, supported real devices, owner review and submission authorization. | Simulator QA, candidate archive, store assets and exact submission steps. Build completion is not App Store approval. |

No OpenRouter account is needed for the current deterministic core. No Stripe integration is needed merely to charge through the iOS app. Cloud sync, Android, social features, a widget and AI summaries are not prerequisites for an honest focused v1 unless marketed as included. A recoverable local backup route is compatible with a device-local v1; it must not be described as automatic cloud sync.

## Candidate handoff record

At integration, record the final commit, native build configuration, device/OS, passed domain/UI checks and inspected states in `docs/progress.md`. Attach separate evidence for StoreKit simulation, App Store sandbox, signed TestFlight and production configuration; do not collapse them into “billing works.”

The audit itself performed source inspection, official-page research and public review-feed retrieval. It made documentation changes only and did not rerun the application test suite. Passing tests from an earlier commit does not establish that a later integrated candidate is ready. Unfinished gates remain open until their specific evidence exists.
