# Along design and onboarding proposal

Implementation direction · 1 November 2026

User decision: build all 26 screens and use a direct paid membership with no trial. Pip now has five original rendered assets; see pip-art-direction.md.

Along should feel like a personal journal for an adult's GLP-1 journey, with Pip helping them record ordinary days and recognise progress. The proposed experience combines a substantial, personalised onboarding with a subscription gate after the first real journey entry. The continuing value is a useful personal history, manageable routines and reflections grounded in that history.

This proposal covers visual direction, navigation, a 26-screen onboarding, the hard paywall and the first week. The 26-screen flow is implemented as a local SwiftUI design preview; real billing remains unconfigured.

**Product promise:** “A personal record of your GLP-1 journey, with a companion that helps you notice progress and maintain the routines you choose.”

**Commercial premise:** A mascot can make this enjoyable to return to. The record and the reflections must make it worth subscribing to.

## Reference apps and evidence

Sensor Tower's live **iPhone App Store, Health & Fitness, Top Grossing** charts were checked for 1 November 2026, around 17:10 UTC, with IAP set to All. These are category ranks, not revenue estimates. Rankings can change during the day.

| App | US | UK | Reference priority for Along |
| --- | ---: | ---: | --- |
| MyFitnessPal | 1 | 4 | Fast access to the daily task |
| LADDER | 2 | 9 | A concrete reason to return tomorrow |
| Flo | 4 | 3 | Relevant questions and explanations |
| Calm | 6 | 10 | Calm presentation and space |
| Cal AI | 9 | 21 | Questionnaire, personalised result and subscription offer |
| Finch | 10 | 18 | Companion attachment and user-chosen routines |
| Headspace | 14 | 12 | Illustration, reassuring copy and clear question layouts |

Sources: [Sensor Tower US chart](https://app.sensortower.com/top-charts?category=6013&country=US&device=iphone&os=ios&date=2026-11-01), [UK chart](https://app.sensortower.com/top-charts?category=6013&country=GB&device=iphone&os=ios&date=2026-11-01). These ranks help select references; they do not establish which design choices caused commercial success.

**Direct visual references.** Mobbin's public [Headspace onboarding](https://mobbin.com/explore/flows/7cdc08c0-3bcb-4882-90dd-5cf92019616f) shows a breathing introduction, warm illustrations, benefit explanations, a goal question and a related introduction to the product. Its 18 captured images include repeated interaction states, so they are not 18 distinct onboarding questions. Finch's full Mobbin flow required login and was not inspected.

Cal AI's public early screens use a question at the top, large choice rows, a progress indicator and a fixed bottom Continue button. Its [recorded flow's chapter descriptions](https://screensdesign.com/apps/cal-ai-calorie-tracker/) describe questions followed by a plan summary and subscription offer; later screenshots are gated. Separately, [Superwall's Cal AI case study](https://superwall.com/case-studies/cal-ai) publishes an actual three-page offer image: product preview, reminder reassurance, then a trial timeline and plan selection. That example shows a three-day trial and annual/monthly choices. It is a published variant, not verification of every current user's checkout. The case study reports 61 onboarding-paywall experiments, reinforcing the need to test our own sequence.

| GLP-1 reference | Verified design or product evidence | Consequence for Along |
| --- | --- | --- |
| [MeAgain](https://meagain.com/) | Public dashboard has dense metric cards and a mascot; [its provider page](https://meagain.com/providers) confirms a free Basic tier. [ScreensDesign](https://screensdesign.com/showcase/meagain-glp-1-all-in-one-app) describes a long setup and a soft paywall in its recording. | A pet plus GLP-1 tracking already exists. Put personal history and reflection at the centre of our experience. |
| [Shotsy](https://shotsyapp.com/) | Public Summary screen uses readable charts, date ranges and clear dose records. [Core tracking is free without a time limit](https://shotsyapp.com/free-glp-1-tracker/). | Match its clarity when displaying records. Our subscription needs value beyond basic logging. |
| [DreamMe](https://www.dreamme.life/) | Public home screen combines a fish companion and habitat with treatment tasks and results; the site markets outfits, missions and pearls. | Give Pip a recognisable role in the user's journal and reflections. Character collection alone is already competitive. |
| [Glowise](https://screensdesign.com/apps/glowise-glp-1-tracker-diary/) | Early public screens use pale backgrounds, olive accents, choice rows and a bottom CTA. Public chapter descriptions alternate questions, empathy, explanations and a plan preview; later paywall screens are gated. | Alternate input with useful feedback so a long flow feels purposeful. |
| [Appetide](https://appetide.app/en-us/) | Public site has green gradients, large type and a specific symptom-to-food proposition. Its linked quiz returned 404 during this review. | Be equally specific about the job Along does. Its live onboarding and offer remain unverified. |
| [Little & Often](https://eatlittleandoften.co.uk/) | Offers a free sample before a £19 one-off meal plan delivered by email; explicitly says no app. The first public quiz stage uses cream/yellow styling and a four-stage indicator. | Show an understandable output before asking for payment. Treat this as an adjacent product, not an iOS subscription benchmark. |

Competitor App Store listings contain multiple subscription SKUs, sometimes with unclear durations. They do not identify the offer a particular new user will receive. The proposal below uses our own test prices.

## Visual direction

Keep the warmth of the prototype and make its useful content easier to find. The existing Today screen devotes most of its first viewport to a greeting and a large Pip scene. Journey similarly places a large introduction above the records. Reduce those introductions and bring actions, recent entries and history higher.

| Element | Proposed treatment |
| --- | --- |
| Overall character | A warm, carefully illustrated personal journal for adults |
| Background | Warm ivory `#F8F4EC`; white or near-white reading surfaces |
| Text and primary action | Deep plum `#3D304B`; a clear, filled primary CTA |
| Supporting colours | Sage `#DDE8D3`, apricot `#F0B88F`, restrained lavender; dark text on pale fills |
| Typography | Native serif for occasional emotional headlines and chapter titles; SF Pro for questions, controls, records and charts |
| Hierarchy | Approximately 32–36 pt onboarding headlines, 24–28 pt daily-screen titles, readable 17 pt body copy; Dynamic Type throughout |
| Layout | 24 pt horizontal margins, consistent spacing, roughly 56 pt primary buttons, fewer nested cards, mostly 16–20 pt card corners |
| Illustration | One original Pip character with a coherent silhouette, soft shading, expressive face and a small set of accessories |
| Motion | Brief reactions to a saved entry, a chapter opening or a chosen accessory; reduced-motion alternatives |
| Data | Clear dates, units and labels. Pastel colours never carry meaning alone. No invented forecasts or scores. |

Pip should have six initial states: welcoming, listening, thinking, quietly encouraging, celebrating a user-marked win, and resting. The character remains welcoming after an absence. Cosmetic progress comes from cumulative participation; weight loss, food restriction and perfect streaks do not determine rewards.

Use large Pip illustrations on the welcome, companion customisation, chapter reveal and milestone screens. On Today, keep Pip small enough for the main action and useful context to appear together. Avoid repetitive generic encouragement; connect the copy to a saved entry or an explicit choice.

## Main app layout

Use three tabs: **Today, Journey, Pip**. Put profile, preferences and subscription management behind the profile button at the top. Journey is the main record; Today is the quickest entrance into it.

| Screen | Layout and purpose |
| --- | --- |
| Today | Compact date/journey context; small Pip reaction; prominent check-in; up to two chosen routines; a recent personal moment; first reflection or weekly chapter. At normal text size, the first viewport should show a useful action and personal context. |
| Check-in | One short sheet for mood and appetite, optional routine ticks and a note. Make completing it comfortably possible in about 30 seconds, with an obvious edit route. |
| Journey | Week/month navigation followed by actual entries. Offer Timeline and Trends views; simple filters distinguish check-ins and user-marked wins. Optional weight history gets dates and units, with no predicted target date. |
| Entry detail | Date, original user text, recorded values and edit controls. The user can mark their own moment as a win. |
| Weekly chapter | A readable cover, recorded days/routines, selected user moments and an optional reflection prompt. Every summary statement must be traceable to entries. A single entry gets a single-entry summary. |
| Pip | Companion scene, earned accessories and a shelf of completed journal chapters. Give people a pleasant place to revisit their story. |
| Profile | Reminder preferences, weight visibility, journey context, subscription, restore, export and deletion. |

The recurring loop is **record a day → see it in the journey → revisit a chapter → choose what to keep doing**. A paid experience needs the history, chapter and routine features to work together; attractive onboarding cannot substitute for them.

## Onboarding sequence

Propose a **26-screen maximum path**, targeting approximately **3–5 minutes**. Optional branches shorten it. This is a design hypothesis to test, not a competitor conversion benchmark.

Use a four-part progress indicator: **Your journey → Your routine → Your companion → Your space**. Show one main task per screen, keep Continue in a stable location, preserve answers when going back or reopening the app, and provide Skip on optional questions. Routine setup should have usable defaults. Questions must affect the product as described below.

| Screen | Content | What it changes or demonstrates |
| ---: | --- | --- |
| 1 | Welcome and Pip: “A place for your whole GLP-1 journey.” Explain the personal record and show a short preview. Include setup duration and a discreet subscription-required note. | Establishes the product and commercial expectation. |
| 2 | Optional preferred name. | Personalises the journal and greetings. |
| 3 | “Where are you in your journey?” Preparing, recently started, established routine, maintenance. | Sets stage-appropriate prompts and language. |
| 4 | Optional start date, with “I'm not sure.” | Adds journey-week context. Without a date, use days recorded in Along and avoid inventing a treatment week. |
| 5 | “What would you most like Along to help with?” Notice progress, keep a clear record, maintain routines. | Prioritises the relevant Today card and reflection prompts. |
| 6 | “What makes that difficult?” Remembering details, noticing changes, finding time to record. | Selects memory prompts, comparison prompts or a compact default check-in. |
| 7 | A brief product explanation tied to the previous answer. | Demonstrates how a day becomes a useful record. Any sample content is labelled as an example. |
| 8 | Choose up to three things the user would like to notice: everyday comfort, energy, confidence, strength/function, routines, or their own category. | Sets available milestone tags and reflection prompts; makes no health prediction. |
| 9 | Optional personal intention: “What would you like to remember you're doing this for?” | Becomes the opening note of the journal, using the user's words. |
| 10 | “Would you like weight in your journal?” Show it or leave it out. | Controls the visibility of weight inputs and charts. |
| 11 | Optional current weight and units, only if selected. | Creates an editable first measurement. Skipping still permits later entries. |
| 12 | Progress preview reflecting the selected categories and weight preference. | Shows what the record can contain. A chart with insufficient data shows that state honestly. |
| 13 | Choose up to two routines to record, with editable examples and a custom option. | Sets the user's Today checklist. |
| 14 | Adjust the chosen routine wording or keep the suggested wording. | Makes the checklist specific and manageable for this person. |
| 15 | Pick a comfortable frequency for those routines, including a flexible option. | Sets the schedule without treating unplanned days as failures. |
| 16 | Choose a check-in time or no reminder. | Stores a reminder preference; requests system permission only later in context. |
| 17 | Choose a weekly reflection day. | Schedules recurring chapters after the introductory reflection. |
| 18 | Choose an encouragement style: gentle, straightforward or celebratory. | Selects matching prompt and reaction copy. |
| 19 | Make Pip feel personal with one starter accessory. | Applies a real cosmetic choice to the companion. |
| 20 | Optional companion name; Pip is the default. | Applies the name throughout the experience. |
| 21 | Complete a real first check-in: mood and appetite. | Creates the first record locally. |
| 22 | Optional first moment: “What would you like to remember about today?” | Adds the user's own words to that record. |
| 23 | Reveal the first dated journey entry with a brief Pip reaction. | Delivers the first useful outcome before the paywall. The entry remains saved. |
| 24 | Reveal the personalised space: first entry, chosen routines, preferred progress categories and first reflection timing. | Makes the subscription's ongoing value concrete. |
| 25 | Explain the membership and its continuing value. | Shows the personal history, reflections and routines included, with payment starting at subscription. |
| 26 | Hard paywall with annual and monthly plans. | Starts StoreKit checkout only after an explicit purchase action. |

Do not add height, gender, target weight, medication dose or detailed medical history merely to lengthen the questionnaire. The proposed product does not need those inputs. Do not insert fake analysis delays, invented testimonials, or weight-loss promises. A short transition can assemble the user's actual choices immediately.

A mandatory account form is unnecessary for the local first experience. If optional sync is later offered, introduce account creation when the user chooses it. Request notification permission after a successful subscription and only if the user asked for reminders. Camera and Health permissions belong with the feature that uses them.

## Hard paywall and subscription offer

**Initial US pricing hypothesis:** $29.99 per year or $5.99 per month, charged immediately when subscribed. No trial or free introductory period. Keep annual selected by default and make the monthly option clear. Localised store products must be configured before payment is enabled. Later, test an annual $39.99 variant while keeping other variables stable.

The first real entry and personalised space demonstrate value before the direct paid offer. After subscription, reflections use only the records the user actually keeps. The first week must make the ongoing value clear.

| Paywall area | Proposed content |
| --- | --- |
| Header | “Keep your journey with Pip.” Use the chosen companion name if changed. |
| Visual | The user's first journey card and Pip, with private text protected from unintended external sharing. |
| Benefits | A complete personal history; reflections from recorded days; chosen routines and a companion that grows with participation. |
| Plan selection | Annual total and billing period prominently displayed. Monthly option adjacent or immediately beneath. Equivalent monthly pricing is secondary. |
| Purchase CTA | “Subscribe for $29.99 / year” or “Subscribe for $5.99 / month”, matching the selected plan. |
| Billing explanation | The amount charged immediately and the renewal cadence. Explain automatic renewal and how to cancel. |
| Other controls | Visible back/close, Restore Purchases, terms and privacy. |

**Hard gate behaviour:** Closing the offer returns to a locked, saved preview. It does not open the core app. Reopening resumes that preview or offer without repeating onboarding. A successful subscription opens the personalised Today screen with the first entry already present. Failed or pending purchases preserve all setup and give an appropriate retry/wait state. Restore must work for returning subscribers. Existing users retain access to export and deletion even when a subscription lapses.

Do not show trial language, reminder timelines, false discounts, countdowns or guilt about abandoning Pip. The local build shows an honest unavailable-purchase alert; its explicit design-preview route exists only in DEBUG builds and does not activate an entitlement.

The hard gate is a deliberate business-model choice. [Finch Plus is optional](https://help.finchcare.com/hc/en-us/articles/42149821015693-New-User-Guide), and the GLP-1 references above include free core tiers. [RevenueCat's 2026 report](https://www.revenuecat.com/state-of-subscription-apps) reports median day-35 download-to-paid conversion of 10.7% for hard-paywall apps versus 2.1% for freemium apps. Its sample consists of qualifying RevenueCat apps with subscription revenue, primarily using 2025 data. This is an observational comparison across different products, not proof that adding a gate multiplies Along's conversion.

## First week and measurement

| Moment | Intended experience |
| --- | --- |
| First session | The personal entry survives checkout, Today reflects the onboarding choices, and the user knows what to do on their next visit. |
| Days 1–2 | Check-in is quick, routines are editable, and Pip's response refers to a real action or entry. |
| Day 3 | A short introductory reflection makes the growing record useful. It does not fabricate trends from sparse data. |
| First week | A fuller first chapter based on the days actually recorded. |
| Following weeks | Chapters accumulate into a useful history; people can revise routines, hide weight and return after gaps without penalties. |

Measure completion/drop-off for each onboarding screen, time to first entry, paywall reach, successful purchase/restore, first reflection viewed, first-week use, paid conversion, refunds and day-30 retained use. Compare net revenue per install alongside retention; a rise in checkout starts alone is insufficient.

Keep analytics to screen and event identifiers and coarse experiment assignments. Journal text, weight, appetite and other personal entries do not belong in marketing event payloads.

Begin with one coherent 26-screen flow. Once traffic supports an interpretable test, compare it with a roughly 20–22-screen variant that retains the same personal preview and hard gate. Change length first, offer framing next, and price later. Record hypotheses and sample-size needs before testing; do not call a winner from a handful of purchases.

## Design work after review

The next design deliverable should show eight representative surfaces together: welcome, question, companion choice, first-entry reveal, membership explanation, paywall, Today and Journey. Check that they feel like one product, then expand the remaining onboarding states and the weekly chapter.

Before implementation, review the experience at a small iPhone size, with large text, reduced motion and VoiceOver. Include returning users, skipped optional questions, hidden weight, interrupted onboarding, no notification permission, unavailable billing and failed purchases. Existing prototype entries must be retained during any later redesign migration.

The user authorised implementation of the 26 screens and improved Pip. Production checkout, push delivery and account services remain outside this local design preview.
