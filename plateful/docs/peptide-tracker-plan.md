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

2. **Protocol model and schedule engine.** `TrackedPeptide` (name, category,
   optional dose amount and unit, schedule, dose times, start date, paused) and
   `DoseLog` (peptide, scheduled slot, time taken, amount, unit, injection
   site, note, taken or skipped). Schedules: every day, chosen weekdays, every
   N days, weekly. A pure engine answers "what is due on this day", matches
   logs to slots and reports adherence. Validation, persistence inside the
   journal file, backup and restore, and tests.

3. **Setup hands over to the protocol.** Finishing setup turns the chosen
   peptides, frequency and dose time into tracked peptides. Dose amounts stay
   empty for the person to fill in: the app never suggests a dose. Store
   actions to add, edit, pause, log, skip, undo and delete, with tests.

4. **App shell and Today.** Replace the Pip tabs with Today, Protocol, Progress
   and Settings in the white setup design language. Today has a week strip,
   a dose ring, the day's scheduled doses with one-tap logging and undo, the
   next dose, and a way to log an unscheduled dose.

5. **Dose details.** A sheet to log or edit a dose: amount and unit, time
   taken, injection site with the last site shown for rotation, and a note on
   how the person feels. Edit and delete from Today and history.

6. **Protocol tab.** The list of peptides with schedule summaries; add and
   edit a peptide from the library or a custom name; set amount, unit,
   schedule, days and times; pause or remove.

7. **Dose reminders.** One reminder per peptide dose time, titled with the
   peptide and amount, on the right days. Respects iOS's 64 pending
   notification limit. Global switch in Settings; reminder copy is about doses,
   not journaling.

8. **Progress.** Adherence for the last 7 and 30 days, a month calendar of
   logged days, per-peptide history with notes, and the weight trend with
   logging for weight-goal users. Missing logs are shown as unknown, never as
   failure.

9. **Settings.** Membership, reminders, units, backup and restore, delete all
   data, privacy, terms and a clear "tracker, not medical advice" statement.

10. **Remove the journal and Pip.** Delete check-ins, routines, milestones, the
    weekly reflection, Pip, the room and their assets and tests. Dev Lab gets
    fictional, labelled sample protocols instead of sample journals.

11. **Local subscriptions.** A StoreKit configuration file with the yearly and
    monthly products so the simulator shows real prices and test purchases
    unlock the app. App Store Connect setup is documented, not performed.

12. **Attribution groundwork.** Store where the person heard about Along and
    their referral code with the profile, behind a small attribution interface
    with a no-op provider. Adding AppsFlyer needs explicit approval, because it
    is a new dependency.

13. **Final review.** Full Swift checks and UI tests, simulator screenshots of
    every screen, and an updated `docs/progress.md` listing what still needs
    accounts or approval.

## Out of scope until approved

Accounts and sign-in (Apple, Google, email), AppsFlyer, any AI features,
reconstitution or dose calculators (dosing guidance), and a production release.
