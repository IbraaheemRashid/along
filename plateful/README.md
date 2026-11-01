# Along

A native SwiftUI prototype for an adult GLP-1 progress companion. A short check-in becomes part of a personal journey, with routines, meaningful milestones and an original companion named Pip. Along and Pip are working names.

## Try the iOS app

Open `apps/ios/Along.xcodeproj` in Xcode, choose the **Along** scheme and an installed iPhone Simulator, then Run. No Apple developer account, server, API key or payment is required for simulator use. iOS 17 or later; tested with Xcode 26.3 and an iPhone 17 Pro simulator running iOS 26.3.

Complete the 26-screen setup to create your first journal entry. Screen 26 is a direct subscription offer with **no trial**. Billing is not connected: Subscribe and Restore do not unlock access. In a Debug build, scroll to **Open app preview · no payment** and confirm **Open design preview** to explore the app locally. This does not create a subscription.

In **You → Review all 26 onboarding screens**, jump to any screen using clearly labelled example answers in a separate review journal. **You → Load the sample journey** loads fictional records; individual entries retain sample labels. You can also export or delete local data. The old `apps/ios/Plateful` folder is an abandoned pantry experiment and is deliberately excluded from the Xcode project.

The working core includes:

- Resumable 26-screen onboarding with journey, progress, routine and companion preferences; an actual first entry before the paywall.
- Daily mood/appetite check-ins, optional routines and notes; same-day edits replace the prior entry.
- Chronological journey, personal milestones and factual weekly recaps.
- Optional weight records with canonical kg storage and kg/lb display.
- Five new transparent Pip renders: welcome, journal, celebration, scarf and flower. Customisation and cumulative keepsakes carry into the app without streak penalties.
- Local file protection, restart persistence, readable export and deletion.
- An explicitly non-purchasable direct subscription preview: $29.99/year or $5.99/month, with immediate-charge disclosure and no trial.

## Dev Lab

In a Debug build, tap **Dev Lab** in the top bar from onboarding or the main app. New scenarios use isolated local storage; the normal journal and credentials are untouched. Release builds omit these tools.

- Jump to any of the 26 onboarding screens, fresh setup, halfway setup or the no-trial offer.
- Load an empty journal, the 14-day example, a sparse week or 30 recorded days.
- Open Today, Journey, Pip, Settings, check-in, milestone, weight, reflection or membership directly.
- Change appearance, text size and app motion inside the sandbox.
- Inspect sandbox JSON, preview a save-error alert, reload saved state from disk or reset the current scenario.
- **Resume last sandbox** returns to the saved test session, including after an app restart. UI tests use a separate Dev Lab storage scope.

Purchases, cloud accounts and notification delivery remain unconnected. Dev Lab displays the connection status and never creates a real subscription.

## What is connected

**iOS works locally.** Entries are not sent to a server, model or analytics system. The API client and Keychain token utility are dormant integration seams; the app does not create accounts or call them automatically. This is not a medical, dosing or nutrition-assessment service.

The companion API uses plain Cloudflare Worker handlers and D1 SQL. Its Node preview is local-only and marks non-persisted submissions honestly. Live Better Auth, OpenRouter/AI Gateway, Superwall, Stripe and Tinybird remain disabled until configured and implemented. The web page uses React + Vite and is a separate validation preview, not the native application.

No production deployment, real waitlist campaign, AI service, purchase, trial, cloud sync or TestFlight distribution has occurred. No new recurring costs were started.

## Local commands

From this folder:

```sh
bash scripts/check.sh
bash scripts/dev-api.sh
bash scripts/dev-web.sh
```

The scripts use an installed Node 22.18+ binary or the bundled Codex Node runtime. Web dependencies need to have been installed in `apps/web`; the lockfile records the versions. Native tests require Xcode. UI tests are run through Xcode’s Test action and use an isolated review directory; they do not reset the normal journal or credentials. The Debug launch argument `--review-onboarding` also opens setup in that isolated directory.

To regenerate the small Xcode project after adding Swift files:

```sh
python3 apps/ios/generate_project.py
```

The generated project and original icon are committed, so regeneration is not needed for normal use.

## Product and validation

Start with [the brief](docs/brief.md), [the niche assessment](docs/phase0-assessment.md), [the one-week validation kit](docs/validation-kit.md), and [actual implementation status](docs/progress.md).

The user authorised this prototype before real market validation. The playbook’s Gate A is **not passed**: the deterministic core scores poorly on the AI-engine criterion and this product has no measured conversion or retention yet. Existing competitors validate a category, not Along’s business. AI is not being added merely to improve a score.
