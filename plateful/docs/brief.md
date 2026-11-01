# Along — prototype brief

Updated 1 November 2026. Working name only; brand and store availability have not been cleared. Pip is an original companion character.

**For adults using GLP-1 medication, Along turns a short daily check-in into a personal record of routines, feelings and milestones in under a minute.** The timing is a usability target, not a measured claim.

The user approved exploring a GLP-1 progress companion and explicitly authorised building a SwiftUI prototype with mocks where services are unavailable. This brief replaces the ingredients-to-meals concept, which the user rejected. It does not establish commercial validation: [Gate A remains incomplete](phase0-assessment.md).

## Who and why

Start with adults who want an easy way to remember their GLP-1 journey and notice the routines and moments they personally value. The central hypothesis is that an appealing, brief daily ritual plus a useful history earns repeat use. The difficult question is whether that is worth a separate subscription alongside existing tracking apps.

The app records what someone chooses to report. It does not assess whether medication is working, diagnose symptoms, prescribe routines, or infer causes from weight, mood or appetite.

## First useful session

1. Explain the promise; ask for a preferred name and optional routine choices. Keep weight optional. No medication brand, dose or diagnosis is needed.
2. Offer a fresh start or a clearly labelled fictional 14-day sample journey. Sample records must remain distinguishable from the user's records.
3. Let the person report mood, appetite and chosen routines, with an optional note. Neutral choices and the ability to skip prevent a check-in becoming a test.
4. Save immediately and show the new entry in their journey. This is the first win: “I have a record of today.”
5. Let them explore their history, record a personal milestone, or change Pip's accessory. A recap becomes useful once records exist; a fresh account must not invent one.

## Day-one scope and acceptance

| Capability | Required behaviour |
|---|---|
| Onboarding | Preferred name, routine choices and explicit sample-data choice; no account needed for local use. |
| Daily check-in | Mood, appetite, selected routines and optional note persist after relaunch. Editing a day's check-in must not create extra reward credit. |
| Journey | Chronological entries with readable dates; sample entries clearly identified. |
| Optional weight | Store one canonical kilogram value per record; display kg or lb with conversion. Switching units must not change the stored measurement. No target date, predicted loss or judgement about direction. |
| Personal milestones | User-authored title and note; no automatic reward for losing weight or restricting food. |
| Weekly recap | Deterministic summary of the chosen week's actual records: check-in count, routine records and milestones. Describe missing days as missing, not failure. No medical interpretations or causal claims. |
| Pip | Original artwork, optional accessory selection and cumulative check-in unlocks. No punishment, loss of accessories, distress or broken-streak messaging after absence. |
| Data controls | Local persistence, user-initiated export and clear deletion of local records. Explain that an exported file is a separate copy. No claimed cloud backup. |

Build the native loop first using SwiftUI and platform APIs. The local experience requires no model call or subscription. Associated web/API scaffolding follows the playbook: React + Vite, plain Cloudflare Worker fetch handlers and D1 SQL. Better Auth, Superwall, Stripe and Tinybird are the later integration choices; OpenRouter through AI Gateway is reserved for a justified future AI feature. Do not activate vendors just to fill a stack checklist.

## Product and business hypotheses

The proposed advantage is the quality and focus of the daily ritual: quick recording, calm presentation, a useful personal timeline and customisation that feels adult and welcoming. This must be tested against existing products; neither progress tracking nor a mascot is unique. Reference evidence and screen mappings are in [references.md](references.md).

**Price hypothesis: US$29.99/year.** Any pricing screen is a conspicuous non-purchasable preview, ideally available after the first useful result or from settings. There is no real trial, charge, entitlement or renewal. Do not show a successful purchase or restore when none occurred. Trial length and paid/free feature boundaries remain research questions. The playbook's default three-day trial is not a promise made by this prototype.

Distribution begins with ten short demonstrations and an honest waitlist test, described in [validation-kit.md](validation-kit.md). No testimonials, outcome statistics or paid-demand claims are invented. The base funnel assumption produces about $2.29 per download after a modelled 15% store fee and before other costs, not $2.70 profit. See the full sensitivity in [phase0-assessment.md](phase0-assessment.md).

## Boundaries

No dose advice, medication-level modelling, calorie targets, weight-loss rewards, clinical risk scoring, symptom treatment or diagnosis. No chatbot giving health advice. No streak penalties, public comparisons, body scoring or pressure to disclose weight. Health-related notes require private handling; do not put note contents, weights or mood values in marketing analytics. Keep optional weights and recaps accessible without implying a clinical service.

Further ideas are parked in [later.md](later.md). Build and simulator results belong in [progress.md](progress.md); the brief describes intended behaviour, not proof that every item has shipped.
