# Along agent guide

Working name: Along. Along is a peptide protocol tracker for adults who have just bought, or are about to start, peptides. Experienced users are a secondary audience. It keeps the protocol, every dose, reminders and progress in one place. It is a supporting tool: it never sells, recommends or replaces peptides or clinical care. The build plan is [docs/peptide-tracker-plan.md](docs/peptide-tracker-plan.md). The old GLP-1 journal and its companion, Pip, are retired. The old apps/ios/Plateful files are abandoned experiments and must not be compiled into Along.

## Product

- Onboarding is a Cal AI-style flow tailored to peptides, ending in a hard paywall: yearly and monthly plans, no free trial.
- Core: a protocol of tracked peptides with schedules, one-tap dose logging, dose details (amount, time, injection site, note), per-peptide reminders and progress (adherence, history, optional weight trend).
- Visual language: white surfaces, near-black ink, grey tiles and capsule buttons, as defined in `SetupDesign.swift`.

## Stack

- SwiftUI, Observation and URLSession for iOS. No third-party UI libraries.
- Cloudflare Worker with plain fetch handler; D1 with parameterised SQL; KV, R2 and Queues only when needed.
- Better Auth for live identity; OpenRouter/DeepSeek behind Cloudflare AI Gateway for live AI.
- Superwall and StoreKit for native payments, Stripe for web payments, Tinybird for events.
- Optional Firebase Crashlytics only when `GoogleService-Info.plist` is present. Do not enable Firebase Analytics, Auth, Firestore, Messaging or Remote Config.
- React and Vite for the web waitlist. No new vendors, router framework, ORM or UI kit.

## Boundaries

No dosing advice: the app never suggests a peptide, dose amount, schedule, reconstitution volume or cycle length. Dose amounts and schedules come from the person. No treatment, diagnostic or efficacy claims. Missed logs are unknown, not failures; no streak penalties or shaming. Demo mode must be conspicuous. Never present sample records as real history, a mock purchase as a real one, or local test data as real demand. No secrets in clients. Production routes remain disabled until configured and reviewed. AI is optional; do not invent an AI dependency.

Use separate git worktrees for parallel API, iOS and research work. Own only assigned paths. Do not modify another contributor's files.

## Verification

Run `bash scripts/check.sh` and the Xcode UI tests. Build the iOS Simulator target and inspect the running app where the environment permits. Document actual results and remaining account configuration in docs/progress.md. Never deploy production, make purchases, post social content or invent test results.

Named stack dependencies are authorised. Ask before introducing others, including attribution SDKs such as AppsFlyer. Prefer platform APIs.
