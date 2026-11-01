# Along: competitor and product audit

Research date: 1 November 2026. Native source baseline: `dedfb28`. This is a research snapshot, not a claim about the final integrated build. Read the implementation verification in `docs/progress.md` alongside it.

**Recommendation: continue the adult progress companion, and make keeping and retrieving a useful record the paid product. Pip should make that routine enjoyable.** A mascot, a graph and attractive onboarding are already common in this category. The strongest opportunity suggested by this audit is a simpler, dependable experience for people who want to remember their days without managing a large nutrition or medication dashboard. This is a hypothesis to test, not proven demand.

## Evidence and limits

- **Officially described:** features stated on a developer's current website, help centre or App Store listing. This verifies the public claim, not implementation quality, clinical effectiveness or every subscription tier.
- **User reported:** dated App Store reviews obtained from Apple's public US customer-review JSON feeds. These are unverified individual experiences, not reproduced defects.
- **Source inspected:** Along code at the baseline above. No competitor app was installed or purchased for this audit.
- **Recommendation:** our product judgment. No revenue, acquisition cost, retention or clinical result is inferred from marketing copy or ratings.

Mobbin is a separate design-research workstream. Public websites and store descriptions here do not establish the exact native onboarding, navigation or paywall flow. Sensor Tower grossing data, TikTok/Reels comments, Meta ad results and Google Trends time series remain unverified by this audit.

## What the named competitors actually offer

| Product | Publicly described functionality | Verified offer information | Consequence for Along |
|---|---|---|---|
| **Shotsy** | Shot/pill and side-effect records, weight and nutrition history, schedules/reminders, charts, estimated medication levels, Apple Health import and private iCloud sync. Website also describes PDF reports and injection-site rotation. | The US store lists several products: monthly $9.99/$14.99; yearly $39.99/$49.99/$59.99. These are listed SKUs, not a verified universal checkout offer. Its official free page describes basic tracking as free. | History, export, reliability and quick retrieval set a demanding baseline. Medication modelling is outside Along's approved scope. [Store](https://apps.apple.com/us/app/shotsy-glp-1-tracker/id6499510249), [official site](https://shotsyapp.com/), [free tier description](https://shotsyapp.com/free-glp-1-tracker/). |
| **MeAgain** | Food via photo, voice, barcode and search; protein/fibre/water; dose and side-effect records; weight, progress photos and Journey Cards; Capy companion and widgets. The store describes Capy assistance in the app and iMessage. | US store shows multiple “Unlimited” prices, including $14.99 and $119.99, without a dependable period mapping. Do not label them monthly/annual. Current in-app offer not observed. | The closest positioning competitor already combines GLP-1 records, progress and a character. Along must win on specific ease and usefulness, not claim that the combination is new. [Official site](https://meagain.com/), [store](https://apps.apple.com/us/app/meagain-glp-1-tracker-app/id6744178534). |
| **Appetide** | Food and feelings become next-meal suggestions; photo/voice/text entry with user review; protein/fibre/hydration; preferences, recipes, history/trends, shareable reports and coach. FAQ also claims optional injection/dose history. | Website says getting started is free; full access terms are in-app. No paid price verified. | Its central job is the next food decision. Along's approved job is remembering progress and maintaining chosen routines. Do not revive the rejected ingredients workflow. Symptom-aware suggestions and safety claims were not clinically evaluated. [Official site](https://appetide.app/en-us/). |
| **Little & Often** | Personal four-week small-meal plan, recipe swaps, supermarket shopping lists, phone-friendly plan and PDF printing; sample day after a quiz. | Website explicitly offers **£19 once**, delivered by email, with no subscription and **no app**. | This is an adjacent packaged outcome, not an iOS subscription benchmark. Its useful lesson is to make the purchased result concrete before payment. [Official site](https://eatlittleandoften.co.uk/). |
| **Finch** | Chosen goals/activities generate energy; start an adventure; return to a story and response choice; some choices create saved discoveries. Outfits, room items, quests, wellness activities and events give continued reasons to return. | Official help says core self-care is free and Plus optional. Plus adds customization/content options and event benefits. No current universal Plus price verified. | Borrow the relationship between an action, visible progress and a lasting change. Use original Pip artwork, stories and rules. The paid health record must remain useful independently of pet content. [New-user guide](https://help.finchcare.com/hc/en-us/articles/42149821015693-New-User-Guide), [adventures](https://help.finchcare.com/hc/en-us/articles/37779979512845-Going-on-an-Adventure), [Plus](https://help.finchcare.com/hc/en-us/articles/37780200600589-Benefits-of-Finch-Plus). |

**Name correction:** the earlier phrase “little and doften” appears to mean **Little & Often**, also linked in the existing design research. Searches did not identify an independently verified GLP-1 product called Doften. This audit therefore does not invent a separate competitor. If another product was intended, its identity remains unresolved.

Two additional official pages exposed relevant overlap. [Tilly](https://tilly.day/) advertises journal-based assistance, meals, dose/weight trends, a doctor report, reminders, Apple Health and free core features, with $59.99/year or $9.99/month premium and a seven-day trial. [Needled](https://needled.app/get) markets free injection/weight tracking and a mascot named **Pip**. Neither was tested. Needled's use of that name is a concrete reason to leave Along/Pip brand clearance open; it is not evidence of trademark ownership or a reason to silently change the user's chosen name.

## Verified 1–3★ review sample

On 1 November 2026, Apple's public US RSS endpoint returned **50 most-recent reviews per app**. Filtering the explicit `im:rating` field produced **14 Shotsy**, **5 MeAgain** and **5 Finch** reviews rated 1–3★. This is a bounded convenience sample: store, recency, release timing and willingness to review all affect it. These counts are not user dissatisfaction rates or a comparison of overall product quality. One MeAgain low-star entry said the reviewer had only just started and could not yet judge it.

Reproducible source feeds: [Shotsy US reviews](https://itunes.apple.com/us/rss/customerreviews/id=6499510249/sortBy=mostRecent/json), [MeAgain US reviews](https://itunes.apple.com/us/rss/customerreviews/id=6744178534/sortBy=mostRecent/json), [Finch US reviews](https://itunes.apple.com/us/rss/customerreviews/id=1528595748/sortBy=mostRecent/json). Feeds rotate; the selected IDs below identify the observations at retrieval. Summaries are paraphrases, not quotations.

| App | Date, stars, review ID | Reported experience | Along requirement suggested by it |
|---|---|---|---|
| Shotsy | 2026-10-30 · 1★ · `14729980846` | Three months of records appeared missing and charts empty. | Protect old data during upgrades; provide recovery and an understandable error state. |
| Shotsy | 2026-10-24 · 2★ · `14707512417` | Scale/Apple data import did not show current weight or several weeks. | If sync is added, make freshness and source visible. Do not add it without reconciliation tests. |
| Shotsy | 2026-10-23 · 1★ · `14702797432` | Returning user saw newcomer questions/payment instead of existing history. | Subscription state, onboarding state and journal existence must be separate. |
| Shotsy | 2026-10-20 · 2★ · `14691836057` | Finding the last injection site and weigh-in was cumbersome. | Make a date or remembered moment easy to retrieve. |
| Shotsy | 2026-10-20 · 1★ · `14690318539` | Reviewer reported an unexpected annual charge after trying the app. | Show full billed price and timing before confirmation; no trial wording. |
| Shotsy | 2026-10-18 · 2★ · `14684309889` | Basic tracking alone did not justify renewal at the price paid. | Test payment for Along's narrower bundle; competitor payment does not prove willingness to pay for ours. |
| MeAgain | 2026-10-27 · 3★ · `14718125452` | Friendly appearance but confusing navigation. | One primary daily action; clear routes to history, Pip and settings. |
| MeAgain | 2026-10-24 · 1★ · `14707890466` | Advertised food/reaction guidance felt more specific than the delivered help. | Demonstrate exactly what Along does; promise records and reflection, not treatment guidance. |
| MeAgain | 2026-10-22 · 3★ · `14697178915` | Added AI and upsells obscured valued basics. | Keep AI optional and outside the daily core unless evidence justifies it. |
| MeAgain | 2026-10-21 · 3★ · `14692876588` | Wanted basic tracking/widget without paying for unwanted food features. | Make the paid bundle coherent; do not add features merely to make it longer. |
| Finch | 2026-10-30 · 2★ · `14730559010` | Subscription discovery after character setup and questions caused frustration. | Preserve paid-membership disclosure on screen 1 and a clear way back from the offer. |
| Finch | 2026-10-29 · 2★ · `14726367682` | Streak pressure and forced content felt discouraging. | Cumulative progress, no lost rewards, optional stories and no guilt when returning. |

Other low-star Shotsy entries also described missing records, onboarding interruptions and import reliability. These reports do not establish root cause, scope or that data was permanently deleted. The [developer's release history](https://apps.apple.com/us/app/shotsy-glp-1-tracker/id6499510249) independently discusses recovery, backup, sync and date/unit fixes; those notes justify testing these classes of failure, not assuming our implementation will avoid them automatically.

There is a mismatch worth preserving: Shotsy's website describes free tracking while some reviewers perceive a mandatory paid offer; Finch's help describes free core use while some reviewers perceive a forced subscription. Public descriptions and user perception can differ. We did not reproduce either checkout, so neither perception should overwrite the official tier description.

## The pattern and the product decision

The recurring sequence is **capture something quickly → put it in context → make it easy to revisit → give a reason to return**. In nutrition apps the return is a food decision. In tracking apps it is a schedule or progress record. In Finch it is both completing one's own goals and discovering what the companion does next. This synthesis is our inference from the sources above.

Along's defensible promise should stay narrow:

> For adults on a GLP-1 journey, Along turns a short check-in into a personal record of how life is changing, with Pip growing alongside the routines they choose.

“Under a minute” should remain a usability target until measured. Useful changes to ship within the approved scope:

1. **Today does something.** Check in, update a chosen routine and save a personal milestone with little navigation. A routine checkbox records what happened; it never implies clinical adequacy.
2. **Journey retrieves something.** Find a date, note, milestone or previous weekly chapter; correct an entry; view optional weight in the chosen unit; export the record. Missing days remain unknown.
3. **Pip develops through participation.** Explain the next unlock and show an earned visual change. Preserve earned items after gaps. A story response becomes an optional fictional discovery, separate from health data.
4. **The record survives mistakes.** Atomic saves, visible failures, migration coverage, backup/restore and recoverable import matter more than additional decorative screens.
5. **The offer matches the app.** The user chose 26 screens and a hard paywall with no trial. Retain those decisions, disclose payment early and demonstrate an actual saved first entry. No fake success, invented social proof or alleged personalized clinical plan.

Do not make the release larger by adding dosing calculators, medication-level forecasts, symptom treatment, AI diet prescriptions, food-photo estimation, social feeds or pediatric diabetes features. Existing competitors do not establish that these are necessary for Along's record-and-companion proposition.

## Specific baseline gaps

These observations refer to `dedfb28`; fixes need verification in the integrated release candidate.

| Area | Inspected implementation | Work required |
|---|---|---|
| Paid access | `RootView` uses `hasOnboarded`; native purchase/restore buttons show unconnected alerts. | Real products, authoritative entitlement state and restore/expiry/error paths. Keep onboarding completion separate from membership. |
| Pip progression | Three accessories; onboarding can give any one immediately; total check-in count unlocks the others. Three stories are immediately reachable/replayable. | Distinguish starter choices from earned items; qualify real participation; explain next reward; provide more than a seven-day ceiling if advertising ongoing growth. |
| Routine interaction | Today rows open the whole check-in. Frequency preference is not a schedule. | Make selected routines directly actionable, or clearly label the route to editing today. Define whether frequency is display-only or scheduled. |
| Weekly reflection | Rolling last-seven-day counts/milestones; chosen weekday changes a label. | Let users revisit a particular period; show dates and source entries; make a chosen notification day do what it promises. |
| History | Chronological feed and milestone filter; check-in editing; deletion through a context menu. | Search/date access and discoverable edit/delete; correct milestone/weight records without delete/recreate. |
| Persistence | Protected atomic JSON; file excluded from backup; no import/sync. Several methods mutate in-memory state before persistence succeeds. | Commit UI state after successful write; test failures; provide a recoverable transfer/backup route. |
| Reminders | Preference only, explicitly disabled in preview. | Implement opt-in local scheduling or remove the promise from release copy. |
| Development surfaces | Dev Lab is Debug-only, but sample/blank journal actions also appear in regular Settings. | Keep destructive fixture tools isolated from release data and membership. |

## Payment validation with no trial

The playbook's `30% trial start × 30% trial-to-paid` model does **not** describe this app. For an annual-only scenario at the proposed $29.99, use `downloads × direct paid conversion × $29.99`. Monthly subscribers require their own realised revenue and retention model.

| Illustrative download-to-paid rate | Gross first-year revenue per download | After an assumed 15% fee | After an assumed 30% fee |
|---:|---:|---:|---:|
| 2% | $0.60 | $0.51 | $0.42 |
| 5% | $1.50 | $1.27 | $1.05 |
| 9% | $2.70 | $2.29 | $1.89 |

These are arithmetic sensitivities, not conversion forecasts, confirmed fee eligibility or acquisition budgets. Refunds, taxes, service fees, support, content/art, hosting, developer costs and marketing still come out. The deterministic local core makes no model calls. Actual App Store product prices must replace hardcoded proposal prices before payment.

The new review evidence closes a narrow research gap: we now have a verified low-star sample for these three apps. It does **not** pass market Gate A. Along still needs observed interest, repeated use and direct paid conversion at the no-trial offer. Prioritize testing whether someone can find a meaningful past moment and wants to keep the record, not merely whether they like Pip's appearance.
