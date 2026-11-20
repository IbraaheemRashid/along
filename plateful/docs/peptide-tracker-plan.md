# Along: peptide tracker build plan

Along is a supporting tool for people who have just bought, or are about to
start, peptides. It keeps their protocol, every dose, reminders and progress in
one place. It never recommends peptides, doses or schedules. Experienced users
are a secondary audience.

The onboarding (shipped in `0e35b05`) promises a one-tap dose log, a schedule
per peptide, reminders, a note with any dose and progress over time. This plan
builds the app behind the paywall so every promise is true, then prepares it
for launch. Each segment below is one commit.

## Segments

1. **Product brief and plan.** Rewrite `AGENTS.md`, `CLAUDE.md` and the README
   for the peptide tracker so contributors stop following the GLP-1 journal
   brief. Add this plan.

2. **Protocol model and schedule engine.** `TrackedPeptide` and `DoseLog`,
   schedules, adherence engine, backup and tests.

3. **Setup hands over to the protocol.** Finishing setup turns chosen peptides
   into tracked peptides. Dose amounts stay empty.

4. **App shell and Today.** Today, Protocol, Progress and Settings in the white
   setup design language.

5. **Dose details.** Sheet for amount, time, injection site and note.

6. **Protocol tab.** Add/edit/pause peptides from the library.

7. **Dose reminders.** Per-peptide reminders under the 64 pending limit.

8. **Progress.** Adherence, calendar, notes history, optional weight trend.

9. **Settings.** Membership, reminders, units, backup, legal, disclaimer.

10. **Remove the journal and Pip.** Delete Pip UI/assets; Dev Lab uses sample
    protocols.

11. **Local subscriptions and Superwall A/B.** StoreKit configuration for
    simulator purchases; real Superwall keys present `onboarding_end` with
    `.superwallOnly` tracking. SwiftUI paywall remains the fallback.

12. **Attribution groundwork.** Local heardFrom/referral behind a no-op
    provider. AppsFlyer needs separate approval.

13. **Peptide analytics events and Crashlytics.** Tinybird allowlist for
    peptide-tracker events (no names/doses/notes). Optional Crashlytics when
    `GoogleService-Info.plist` is supplied; Analytics stays off.

14. **Final review.** Full checks, UI tests, screenshots, `docs/progress.md`.

## Out of scope until approved

Accounts and sign-in (Apple, Google, email), AppsFlyer, Firebase beyond
Crashlytics, any AI features, reconstitution or dose calculators, and a
production release.
