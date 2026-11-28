# What makes a dose tracker easy to use?

Along product review · 28 November 2026

Someone who took a dose at 10:15 should be able to record it, see 10:15 the next time they open Today, and find it again a month later. Along already offered a one-tap log. Two things made that action hard to trust. The completed row displayed the scheduled time, and the history list omitted entries without notes. Those became the first fixes.

## Six comparisons

I reviewed UK App Store listings, release notes, individual customer reviews, Apple’s medication guide and the Streaks press kit. The sample includes direct competitors, well-rated medication trackers and an award-winning daily-use app. Ratings are rounded storefront snapshots. The sources describe behaviour and individual experiences. They give no access to retention, revenue, or Along user behaviour.

| App and reason for inclusion | What the evidence shows | Implication for Along |
| --- | --- | --- |
| Shotsy · direct GLP-1 competitor · 4.8/5 from about 4,500 ratings | Shotsy supports one-tap logging, different schedules for concurrent medications and a full history. One reviewer found the basic tracker sufficient and saw the extra tracking fields as useful for people with different needs. [UK App Store](https://apps.apple.com/gb/app/glp1-tracker-shotsy/id6499510249) | A blank amount, site or note should still leave a useful record. Give each peptide its own days when the user’s schedules differ. |
| Pep AI · direct peptide competitor · 4.5/5 from 109 ratings | Release notes moved logging onto the next-dose card, added reversible skips and described fixes for records reaching the wrong compound. One paying reviewer praised the scope but was reconsidering because of bugs. [UK App Store](https://apps.apple.com/gb/app/pep-ai-glp-1-peptide-tracker/id6758682710) | Keep the peptide name beside the action and visible on the resulting record. Prioritise retrieving the correct dose before adding more ways to log it. |
| Apple Health Medications · native interaction benchmark | Apple distinguishes scheduled and as-needed medications, supports both taken and skipped, and preserves history when users archive a medication. [Apple Support](https://support.apple.com/en-gb/105064) | A schedule, an extra entry and a skip have different meanings. People can record an extra dose while leaving a schedule undecided. |
| Medisafe · 4.6/5 from about 13,000 ratings | A long-term medication user described entering the actual time on iPhone when recording late and missing that option on their watch. [UK App Store](https://apps.apple.com/gb/app/medisafe-pill-reminder/id573916946) | Use the saved time once a dose is logged. When backfilling a past day, open the time editor so the person can confirm it. |
| MyTherapy · 4.8/5 from about 3,200 ratings | Its release notes distinguish confirming, rescheduling and snoozing. Its calendar lets people inspect previous entries and upcoming days. [UK App Store](https://apps.apple.com/gb/app/pill-reminder-mytherapy/id662170995) | Tapping a date should answer “what happened that day?” Every saved record should be findable, including a skip or an entry without a note. |
| Streaks · 2016 Apple Design Award | Its press kit shows separate views for today’s tasks and statistics. Tasks can carry notes and history without putting those fields in the completion step. [Developer press kit](https://streaks.app/press/) | Keep Today focused on the next action. Put history and its explanation in Progress. A medication-free day needs a date and next scheduled dose, with no completion target. |

## Decisions in this change

1. **Confirm the schedule before making a promise.** A person joining on Friday can select Monday and see the dated next occurrence before checkout. They can record a previous injection, set different days per peptide, or leave a peptide unscheduled. That last state creates no due doses or reminders. The editor in Settings also starts a new peptide with its schedule unset.
2. **Make Today answer one question at a time.** On a dose day, the row names the peptide and allows one-tap logging. The saved row shows the recorded time. On a day off, one line explains that nothing is scheduled. The next dose stays visible when one is known, and the extra-dose action remains available.
3. **Make a saved dose easy to find again.** Progress opens with the calendar and history. Tapping a day shows the actual entries. The list includes taken, skipped and extra doses, plus any recorded amount, site and note. A peptide filter applies to the calendar markings, day detail and history. Weekday headers follow the same calendar convention as the dates below them.
4. **Explain what a percentage counts.** Progress explains when a scheduled dose enters its 7- and 30-day totals. Today counts answered slots, showing the taken and skipped counts separately. Catalogue reference charts now sit behind a disclosure in the editor, away from a person’s actual progress.
5. **Make reminders honour the same schedule.** A future start date delays notifications. An interval continues to use its original start day even years later. Editing the protocol refreshes reminder planning while the app is open.

## Walking through the revised tracker

Apple Health gives scheduled and recorded medications separate places on the same day. GoodRx puts the two answers directly on the reminder. Apple’s Design Award profile of Gentler Streak highlights a summary that puts activity in the context of the person’s own history. For Along, that makes a practical test possible. After a user records an early dose, the reminder, Today row and calendar should all agree. If they change next week’s schedule, the previous week should still read the same. [Apple Health](https://support.apple.com/guide/iphone/track-your-medications-iph811670c81/ios) · [GoodRx screen on Mobbin](https://mobbin.com/screens/95f9bc43-c218-4b83-b008-5a451404b138) · [2024 Apple Design Awards](https://developer.apple.com/design/awards/2024/)

The next-dose card opens the scheduled entry or its future day. Extra doses require a peptide choice when multiple peptides are tracked, so an accidental tap cannot silently attribute an entry to the first one. A taken or skipped entry silences its outstanding reminder. A person can mute one peptide while continuing to log it. The calendar opens the saved record for correction, and schedule edits carry an effective date. These behaviors can be verified with a test journal. Whether people return and choose to pay still needs observation with prospective users.

## The remaining product question

The everyday loop has three actions: find what is due, record it, and retrieve it later. The longest path is before the first record. Acquisition source, product previews and an optional referral step all come before checkout. The next comparison to run with prospective users is the current setup versus one that gets to the person’s protocol earlier. Keep the same membership offer in both versions. Measure whether people can name their next due date, record the first dose unaided and return on the next scheduled day. Along has no observed retention or conversion data yet.

## First-run setup for iPhone

Apple recommends giving people an early chance to do the task they came for and making extended instruction optional. Apple Health asks people to enter their own schedule, review the details, and skip optional customisation. Pep AI’s published feature list also gives each tracked medication its own schedule and reminder times. These references support getting to a real next date early. They do not report how Along users behave. [Apple onboarding guidance](https://developer.apple.com/design/human-interface-guidelines/onboarding) · [Apple Health medication setup](https://support.apple.com/en-us/105064) · [Pep AI](https://apps.apple.com/us/app/pep-ai-glp-1-tracker-app/id6758682710)

Along’s earlier flow always asked how someone heard about the app. Even someone who chose to add their first peptide later had to pick a frequency and visit a dose-time screen. The reminders illustration looked like a permission alert and its “Don’t Allow” text did nothing. The final schedule was already available while a timed loading animation played.

**Set up my tracker** takes a new user through adult confirmation, the peptides they want to track, and the timing they actually know. Someone with a weekly schedule sees their selected day, an optional reminder, an optional previous injection and then the schedule preview. Someone with no peptide goes directly from the selection screen to the empty plan. **Walk me through Along** keeps the guided introduction and personalisation. Both routes reach the existing account and membership screens after preview.

Flo’s iOS pill log places “Set up reminders” underneath the pill group. A later screen in the flow shows the pill and time together on Today. That placement makes the reminder’s purpose clear. [Flo’s pill reminder flow on Mobbin](https://mobbin.com/flows/1cc0ba40-e029-47a6-afae-5df7bdcdc67a?tab=screens)

The reminder decision now shows the person's own schedule. Only an explicit opt-in can request iOS permission. New users can confirm they are adults without providing a date of birth. [Apple notification-permission guidance](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications) · [Apple privacy guidance](https://developer.apple.com/design/human-interface-guidelines/privacy)

For a first-time usability check, give a participant a fictional weekly schedule. Ask them to set it up, decline reminders and say their next scheduled date aloud before checkout. Give a second participant no schedule and see whether they can defer it without inventing a day. Record wrong dates, requests for help and any moment someone believes they have subscribed. Completing automated tests confirms navigation and saved state. Unaided task completion still needs to be observed.

## What to watch in the next usability session

Give each participant a fictional protocol with a weekly day different from the signup day. Ask them to predict the next date before continuing, log a dose at a different time from its schedule, then find yesterday’s entry without writing a note. Also show an off day and ask what Along expects them to do. Record where they hesitate, take a wrong turn or need help. Successful unaided retrieval and correct interpretation of the next date are better tests of this change than how many screens they visited.

These are proposed usability tasks. The test results for this branch, and the outstanding device checks, are in [project progress](progress.md).
