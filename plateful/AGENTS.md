# Plateful agent guide

Working name: Plateful. For adults using GLP-1 medication, turn available ingredients and food preferences into three practical meal options in seconds. This is a local prototype with sample meals, not a clinical service.

Follow the cloned ai-app-playbook. The user explicitly authorised building an iOS Swift app with mocks where accounts are unavailable. Build and test the prototype; market Gate A remains unverified and no production release is authorised.

## Stack

- SwiftUI, Observation and URLSession for iOS. No third-party UI libraries.
- Cloudflare Worker with plain fetch handler; D1 with parameterised SQL; KV, R2 and Queues only when needed.
- Better Auth for live identity; OpenRouter/DeepSeek behind Cloudflare AI Gateway for live AI.
- Superwall for native payments, Stripe for web payments, Tinybird for events.
- React and Vite for the web waitlist. No new vendors, router framework, ORM or UI kit.

## Boundaries

Demo mode must be conspicuous. Never present sample nutrition as verified, a mock trial as a real purchase, or local test data as real demand. No medication advice, symptom treatment, calorie prescriptions or diagnostic claims. Hard dietary exclusions must fail closed. No secrets in clients. Production routes remain disabled until configured and reviewed.

Use separate git worktrees for parallel API, iOS and research work, as chapter 01 instructs. Own only assigned paths. Do not modify another contributor's files.

## Verification

Run the provided Node tests and Swift checks. Build the iOS Simulator target and inspect the running app where the environment permits. Document actual results and remaining account configuration in docs/progress.md. Never deploy production, make purchases, post social content or invent test results.

Named stack dependencies are authorised by the user's instruction. Ask before introducing other dependencies. Prefer platform APIs.
