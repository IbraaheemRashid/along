# Local reminder implementation

Implemented 1 November 2026. These files provide the scheduling and settings component; the main worktree must wire them into the app before the feature is usable. No notification permission was requested and no notification was sent during development.

## Integration contract

1. Add `@State private var reminders = ReminderStore()` to `AlongApp` and pass `.environment(reminders)` to `RootView`. The initializer does not request permission or schedule anything. `refresh()` is read-only and can be called when the app becomes active.
2. Add `ReminderSettingsView(onboardingChoice: store.journal.onboardingPreferences?.reminder, reflectionDay: store.journal.onboardingPreferences?.reflectionDay)` to the You screen. It already provides an `AlongSection`, native toggles, time pickers, status, denied-permission Settings link and explicit Save button.
3. Each Dev Lab sandbox needs its own `@State ReminderStore(deliveryEnabled: false)` injected into the sandbox root and any separately presented settings sheet. This instance never reads normal reminder preferences or instantiates `UNUserNotificationCenter`. UI-review launch arguments also disable delivery automatically. Do not pass the real reminder store into a sandbox.
4. When the person explicitly deletes all local data, call `await reminders.reset()` as part of that action. Check the returned result: if removal fails, show `reminders.message` and keep a retry available. Skip this real-system operation for disabled development instances. Journal deletion remains a separate operation owned by `JournalStore`.
5. Onboarding reminder answers only seed a suggested time. They do **not** enable reminders or grant permission. Update onboarding copy to say that reminders are optional and can be enabled in You, or present this settings component following a first saved moment. Do not promise delivery before a successful `save`.
6. Regenerate the Xcode project so it includes `ReminderModel.swift`, `ReminderStore.swift` and `ReminderSettingsView.swift`. No packages, entitlements, remote push service or accounts are required for local notifications. Include the app’s UserDefaults required-reason declaration (`CA92.1`, own-app preferences) in its privacy manifest.
7. Run `bash scripts/check-reminders.sh` from the repository root as an additional check. It is independent of existing CoreTests and injects a fake system client. Root should include it in the main verification command if desired.

## Behaviour

- Daily and weekly reminders default off. Save is the only method that can request OS permission. Construction and refresh never prompt or schedule.
- The user chooses local hour/minute and optional reflection weekday. Enabling daily plus weekly schedules six daily requests and one weekly request; the weekly reflection replaces the daily nudge on that day. It never stacks two reminders on one day.
- Times are repeating calendar matches without an absolute date or pinned timezone. OS Focus and notification settings can change delivery. The interface does not guarantee a delivery time.
- Notifications contain generic language only. No preferred name, GLP-1 status, mood, appetite, weight, notes or companion progress is included. There are no badges, streak warnings, urgent prompts or punishment messages.
- A successful save verifies that the expected request identifiers are pending before publishing the new preferences. Partial scheduling failures remove this feature’s requests, retain the last saved choices and expose an error and retry. A request accepted by the OS is called “scheduled,” never “delivered.”
- Denied permission routes to iOS Settings without repeatedly requesting authorization. Provisional or alert-disabled authorization is reported as quiet delivery. Returning from Settings refreshes the state; the person can save again.
- Turning reminders off never requests permission, removes only Along’s known reminder identifiers, and removes those delivered reminders from Notification Centre. It does not affect other app features’ notifications.
- Choices are stored in the app’s own UserDefaults as bounded booleans and integers, under `along.reminders.preferences.v1`. No journal entries are stored there. Invalid persisted values cannot schedule notifications and can be reset explicitly by turning reminders off.

## Verification actually completed

- `bash scripts/check-reminders.sh`: **36 checks passed**. Covers disabled defaults, onboarding suggestion without consent, deduplication, valid weekday coverage, invalid time rejection, persistence, local-time matching across London DST, generic copy, no prompt on construction/refresh, successful explicit authorization, restart, no second authorization prompt, partial failures and cleanup, missing pending requests, denied and quiet permissions, deletion, all review flags, explicit sandbox isolation, and corrupt preference recovery.
- Full native source type-check with the iPhoneSimulator 26.2 SDK and iOS 17 deployment target: **passed**. Includes the new SwiftUI settings view and UserNotifications adapter.
- All test notification clients were fake. The system adapter was not instantiated by the test suite.

Still required after root integration: inspect the settings screen in light/dark and large text; verify no permissions are requested by onboarding or Dev Lab; manually test allow/deny/settings-return, actual local delivery, time changes and deletion on a real signed iPhone. Notification delivery was not verified here.

## Official API references

Apple recommends requesting notification permission in the context of the action that needs it and checking the current authorization before scheduling. Along uses an explicit Save action and no provisional opt-in. [Asking permission to use notifications](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications).

The scheduler uses repeating calendar triggers containing only the relevant time components and cancels requests when the user turns them off. [UNCalendarNotificationTrigger](https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger), [Scheduling a notification locally](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app).

Apple lists `CA92.1` for UserDefaults used to read and write preferences accessible only to the app itself. [Required-reason API categories](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype).
