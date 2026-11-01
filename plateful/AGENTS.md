# Plateful agent guide

Working name: Along; original mascot: Pip. On 1 November 2026 the user explicitly approved: "A personal record of your GLP-1 journey, with a companion that helps you notice progress and maintain the routines you choose." Build an adult progress-led companion. Core: short daily check-ins, optional routines, personal milestones, a chronological journey, optional weight records, a factual weekly recap and gentle mascot development. Nutrition and strength support the journey. No pantry-first workflow or pediatric diabetes product. The old apps/ios/Plateful files are abandoned experiments and must not be compiled into Along.

Follow the cloned ai-app-playbook. The user explicitly authorised building an iOS Swift app with mocks where accounts are unavailable. Build and test the prototype; market Gate A remains unverified and no production release is authorised.

## Stack

- SwiftUI, Observation and URLSession for iOS. No third-party UI libraries.
- Cloudflare Worker with plain fetch handler; D1 with parameterised SQL; KV, R2 and Queues only when needed.
- Better Auth for live identity; OpenRouter/DeepSeek behind Cloudflare AI Gateway for live AI.
- Superwall for native payments, Stripe for web payments, Tinybird for events.
- React and Vite for the web waitlist. No new vendors, router framework, ORM or UI kit.

## Boundaries

Demo mode must be conspicuous. Never present sample records as real history, a mock trial as a real purchase, or local test data as real demand. No medication advice, symptom treatment, calorie prescriptions or diagnostic claims. The mascot never suffers, loses progress or rewards weight loss, under-eating, doses or glucose readings. No streak penalties. Missing records are unknown. No secrets in clients. Production routes remain disabled until configured and reviewed. AI is optional; do not invent an AI dependency to inflate the niche score.

Use separate git worktrees for parallel API, iOS and research work, as chapter 01 instructs. Own only assigned paths. Do not modify another contributor's files.

## Verification

Run the provided Node tests and Swift checks. Build the iOS Simulator target and inspect the running app where the environment permits. Document actual results and remaining account configuration in docs/progress.md. Never deploy production, make purchases, post social content or invent test results.

Named stack dependencies are authorised by the user's instruction. Ask before introducing other dependencies. Prefer platform APIs.
