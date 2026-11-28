# Walk through Along on iPhone

Along helps someone following their own protocol answer three questions: what’s due, what did I record, and when is the next one? These screens were captured from the SwiftUI app on an iPhone simulator. They use a fictional journal.

## 1. Choose a schedule

Add the peptide you want to track and enter your own days and times. The plan shows the next scheduled occurrence before checkout. You can leave a peptide unscheduled or opt out of reminders.

<img src="screenshots/walkthrough/setup-plan.png" width="270" alt="The setup plan showing the schedule before checkout">

## 2. Record today’s dose

Tap the circle beside a scheduled peptide to mark it taken. Today shows the time you recorded it. Tap the same circle again to undo. Tap the row when you want to record a skip or add a time, an amount, a site or a note. You can save an entry with those optional details blank. When you log an extra dose and track multiple peptides, choose which one it belongs to.

| Today | Optional injection site |
| --- | --- |
| <img src="screenshots/walkthrough/today-fresh.png" width="250" alt="Today showing the scheduled entries and the next dose"> | <img src="screenshots/walkthrough/site-picker.png" width="250" alt="Site picker with an optional location selected"> |

## 3. Find and correct a record

Open **Progress**, tap the calendar date, then the entry. Edit it and save. The calendar and history show the corrected record, including after you quit and reopen Along. If the next scheduled entry is tomorrow, tapping it on Today opens that day’s plan.

| An entry opened from the calendar | Upcoming day |
| --- | --- |
| <img src="screenshots/walkthrough/calendar-corrected-dose.png" width="250" alt="A calendar day showing the corrected dose"> | <img src="screenshots/walkthrough/next-planned-day.png" width="250" alt="Tomorrow’s plan opened from the next-dose card"> |

## Try the build

[Open the verified iPhone Simulator build and screenshots](https://github.com/IbraaheemRashid/along/actions/runs/46153005387/artifacts/15267733453). Unzip the download and then unzip `Along-iPhone-Simulator.zip`. With an iPhone Simulator open on an Apple silicon Mac, drag `Along.app` onto it. You can also run the **Along** scheme from [the Xcode project](../apps/ios/Along.xcodeproj).

Complete setup and choose **Open design preview** on the paywall to explore a labelled local journal. The account walkthrough used a local StoreKit subscription. It created a disposable account, recorded a dose, read the saved dose directly from the account backup, deleted the account in Settings and verified that both the login and backup were gone. A separate returning user requested a password reset and signed in with the new password. The downloadable default build saves its journal on the simulator.

[Verification run](https://github.com/IbraaheemRashid/along/actions/runs/46153005387) · [Research and design decisions](tracking-ux-research.md)
