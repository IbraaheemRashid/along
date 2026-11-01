# Along iOS membership integration

Current integration status: the root app now wires this module. See [release implementation](release-implementation.md) for the latest checks and remaining device/account verification. The original module-specific verification notes below remain historical.

Along sells an auto-renewing monthly or yearly membership with **no free trial**. The billing service is implemented; the App Store Connect products, Superwall project, live legal URLs, and end-to-end Sandbox checks still need configuration. No purchase, account mutation, production deployment, or real entitlement was created by this work.

## Native architecture

`BillingStore` is the app-lifetime, main-actor observable service. `BillingConfiguration` reads public settings from the built Info.plist. Missing settings, placeholders, or an absent Superwall module produce an explicit unconfigured state. There is no default SKU, hard-coded production price, fake paid flag, or Release demo fallback.

The app's SwiftUI paywall can retain Along's design. `purchase(plan:)` sends the actual StoreKit product through `Superwall.shared.purchase`. Superwall invokes `SuperwallBillingBridge`, the custom purchase controller, which performs and verifies the StoreKit transaction. This follows [Superwall's custom purchase controller contract](https://superwall.com/docs/ios/sdk-reference/PurchaseController) and [direct purchase API](https://superwall.com/docs/ios/guides/direct-purchasing). Do not set `shouldObservePurchases = true`; that option conflicts with this direct purchase API.

The bridge mirrors verified status to Superwall and disables Superwall test mode. **Nothing reads Superwall's status, a paywall callback, or `hasOnboarded` as authorization.** SDK grants, a dashboard experiment that skips a paywall, or a dismissed payment sheet cannot unlock the journal. Do not add `grantedEntitlements` or change this direction of authority. Superwall requires developers using a custom controller to maintain [subscriptionStatus](https://superwall.com/docs/ios/sdk-reference/subscriptionStatus).

StoreKit's verified `Transaction.currentEntitlements` provides the on-device membership snapshot. Transactions must belong to one of the two configured auto-renewing products, remain unrevoked, and not have been superseded by an upgrade. Unexpired current transactions work when product loading or renewal metadata is unavailable. Expired periods require verified renewal information with a future grace-period end. Billing retry without grace, expiration, unknown states, and revocation deny access. A cancelled renewal keeps access until the paid period ends. Apple documents [current entitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements), [entitling renewal states](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalstate), and the [grace-period end](https://developer.apple.com/documentation/storekit/product/subscriptioninfo/renewalinfo/graceperiodexpirationdate).

The listener runs throughout the app's lifetime, including for purchases completed outside the app. Verified transactions are finished after refreshing access; unverified transactions are never finished or trusted. Foreground refresh and an expiry timer update the hard gate. No entitlement is serialized into the journal or UserDefaults. Refunds received from StoreKit revoke access on refresh; an offline device cannot learn a refund that Apple has not delivered yet.

## Xcode integration

Add the SPM package `https://github.com/superwall/Superwall-iOS.git`, **exact version `4.18.3`**, product `SuperwallKit`, to the Along application target. The inspected tag resolves to `d2f2002e2c1e250dae3936fa61acc09268fb3bda`. It declares Swift tools 6.2 and pins its Superscript dependency to `1.0.15`. Commit the resulting `Package.resolved`; don't replace the exact pin with a floating branch.

The four source files belong to the Along target: `BillingConfiguration.swift`, `BillingPolicy.swift`, `BillingStore.swift`, and `SuperwallBillingBridge.swift`. The repository generator already discovers `Along/*.swift`, but its framework/package sections must also include the package product. This billing work intentionally does not edit the generator or shared UI files.

Own one `BillingStore` in `AlongApp`, inject it into the environment, and call `await billing.start()` in the root view task. Call `await billing.refresh()` whenever `scenePhase` becomes `.active`. Keep it alive across navigation. Do not instantiate another configured store for a preview or every paywall presentation; Superwall is a process-wide singleton.

The root access rule is `journal.hasOnboarded && billing.hasCheckedEntitlements && billing.isEntitled`. A returning subscriber whose onboarding is incomplete resumes setup. A completed journal without paid access sees the membership gate. During the initial check, show a checking state rather than briefly revealing the journal. Any DEBUG design preview bypass must be separately labelled and compiled out of Release; it must not mutate billing state.

| UI need | Service API |
| --- | --- |
| Initial load | `await billing.start()` |
| Foreground / retry entitlement check | `await billing.refresh()` |
| Retry App Store product loading | `await billing.loadProducts()` |
| Price and period | `billing.product(for: .annual)?.displayPrice` / `.priceWithPeriod` |
| Purchase | `await billing.purchase(plan: .annual)` or `.monthly` |
| Restore button | `await billing.restore()` |
| App Store subscription management | `await billing.manageSubscriptions(in: windowScene)` |
| Disable duplicate actions / show loading | `billing.isBusy`, `operation`, `catalogState`, `canPurchase` |
| Visible error / pending / restoration result | `billing.notice`, then `clearNotice()` |
| Configuration diagnosis in developer tools | `billing.configuration.issues` |
| Verified purchase environment | `billing.entitlement?.environment`, `isTestPurchase` |

Purchase outcomes are `.purchased`, `.cancelled`, `.pending`, or `.failed(message)`. Cancellation makes no access change. Pending does not unlock; the transaction listener handles later approval. Restore returns `.restored` only when active membership is found, `.nothingToRestore` when syncing succeeds without membership, `.cancelled`, or `.failed`. Product and restore failures do not overwrite an otherwise valid entitlement.

Render the localized `Product.displayPrice` returned by StoreKit. Do not show the prototype $29.99 / $5.99 values as real prices while loading or unavailable. Both configured products must load, belong to one subscription group, and have exactly a one-year / one-month period. The catalog rejects introductory offers; purchase validation also refuses free-trial promotional and win-back offers. No offer code or promotional purchase options are passed. Apple confirms the actual charge in its payment sheet.

Keep Terms, Privacy, Restore Purchases, and a way back to setup accessible on the hard paywall. A close/back action must never unlock the journal. Subscription management and data export/deletion should remain reachable for a former subscriber whose journal is now gated.

## Required public configuration

Supply these strings in the application's Info.plist, or generated `INFOPLIST_KEY_...` build settings. Inspect the built Info.plist to confirm they survived generation. Public product IDs and the **public** Superwall key can ship in an app; App Store Connect API private keys, shared secrets, webhook signing secrets, and Superwall secret API keys cannot.

| Info.plist key | Required value |
| --- | --- |
| `ALONG_BILLING_ANNUAL_PRODUCT_ID` | Exact one-year auto-renewable product ID in App Store Connect |
| `ALONG_BILLING_MONTHLY_PRODUCT_ID` | Exact one-month product ID in the same subscription group |
| `ALONG_SUPERWALL_PUBLIC_KEY` | This app's public iOS SDK API key from Superwall |
| `ALONG_BILLING_ENTITLEMENT_ID` | Superwall entitlement identifier mapped to both products |
| `ALONG_TERMS_URL` | Published HTTPS subscription/app terms URL |
| `ALONG_PRIVACY_URL` | Published HTTPS privacy policy URL |

Before enabling purchases, configure the final bundle ID, signing team, paid-app agreement, tax/banking details, approved products, localized names/descriptions, territories, and actual prices in App Store Connect. Enable In-App Purchase for the target/App ID. Use the same bundle ID/products in Superwall, map both products to the configured entitlement, and verify the public SDK key. Leave introductory, free-trial promotional, win-back, and free-trial offer-code campaigns disabled. The no-trial requirement applies to dashboard/App Store configuration as well as copy.

If a remote Superwall paywall is added later, make its placement gated, use the approved products, and include renewal/price/legal/restore disclosures. A feature callback must still check `billing.isEntitled`. The current native paywall API does not require a remote placement; it uses Superwall's documented direct-purchase path.

The bridge sets `eventTrackingBehavior = .none` before SDK configuration and limits console logs to errors. The pinned SDK documents that this stops event collection and reports advertising consent as denied. There is no health/profile attribute upload or `identify` call. Do not enable analytics automatically on launch or pass onboarding answers into Superwall. See the [pinned options source](https://github.com/superwall/Superwall-iOS/blob/4.18.3/Sources/SuperwallKit/Config/Options/SuperwallOptions.swift). SDK configuration and purchase operations can still make network requests; this is not a claim that no data ever leaves the device. Review the pinned SDK and its transitive dependency's actual collection before filling App Store privacy answers and publishing the policy.

## Server scope and the playbook

This is the native, device-local entitlement foundation. The existing `/me/entitlements` route is explicitly a local demo and the webhook routes return `billing_not_configured`; neither is production billing infrastructure. There is no live identity, web purchase entitlement, cross-platform restoration, webhook signature verification, D1 entitlement reconciliation, or account-token linkage in this change.

Before adding paid server/AI/sync features or web subscriptions, implement the playbook's authenticated server entitlement source: verify signed purchase/webhook evidence server-side, map allowed products server-side, deduplicate events transactionally, handle subscription lifecycle updates in D1, and expose authenticated `/me/entitlements`. The server must not accept `isEntitled` from the client. Link an authenticated account consistently with the StoreKit app account token before the first linked purchase. Configure Apple/Superwall notification endpoints only after verification and replay handling work. Do not turn the existing demo route into a success response to make the gate pass.

## Verification and remaining acceptance checks

Run `bash scripts/check-billing.sh`. It verifies 49 configuration and entitlement rules, including unverified/foreign products, revocation, upgrades, expiry boundaries, billing retry, verified/unverified grace periods, overlapping plans, and distinct Xcode/Sandbox policy. These are deterministic policy checks, not claims of a real purchase or restore.

Verified on 1 November 2026: the service type-checks against iOS 17+ with Apple's StoreKit API, including the fail-closed build without the SDK. A separate ignored validation project built the full Along app successfully in **Release for iOS Simulator (arm64 and x86_64)** with Superwall `4.18.3` and Superscript `1.0.15`; the real SDK adapter branch was compiled and linked. Code signing was disabled. This proves compilation, not successful Sandbox purchases. The shared app project/UI still needs the integration described above.

The existing repository regression script passed all 30 API/web tests in the billing worktree, then stopped at the pre-existing `CoreTests.swift` assertion “Back navigation and answer edits autosave and resume exactly” (line 111 on the billing branch base). Billing changes do not touch the onboarding/journal model or that test. The root integration work must resolve/recheck this separately; a green full repository suite is not claimed here.

Use [StoreKit Testing in Xcode](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode) for local development. A local `.storekit` file uses test products/transactions and does not contact Apple's purchase servers. Set its product IDs to match a dedicated development configuration, use one-month and one-year subscriptions in one group, and leave offers empty. Select that file only in a development scheme. The service accepts `.xcode` transactions only in DEBUG and exposes their environment; Release explicitly rejects them. Superwall's own simulated test mode remains disabled.

Then test with real App Store Connect products in [Apple Sandbox / TestFlight](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox), with no local StoreKit file selected. Sandbox uses Apple's infrastructure without charging. Verified `.sandbox` transactions are accepted in Release for TestFlight. This is separate evidence from passing local StoreKit tests.

Before release, record successful evidence for each of these flows on the actual integrated app:

- Fresh install: 26-screen onboarding ends at a paywall, never the journal; missing/offline product data shows a retry state with no invented price.
- Purchase monthly and annual: Apple's localized charge/period matches the paywall; no trial is offered; only verified success unlocks the journal.
- Cancel Apple's purchase/sign-in sheet: no access and no false success; an existing subscriber retains their valid access.
- Pending/interrupted purchase: no access until the verified transaction arrives, including after relaunch.
- Restore active membership, restore with no purchases, failed restore, and a second device using the same Apple Account.
- Automatic renewal, disabled auto-renew until expiry, grace period, billing retry without grace, refund/revocation, plan change, app restart, and foregrounding after an external change.
- Active subscriber offline; expired subscriber offline; transaction updates while the app remains open.
- Missing/wrong Superwall key, wrong SKU, product unavailable in the storefront, different subscription groups, and accidentally configured free trial: no fake success.
- Subscription management opens Apple's interface and refreshes access after returning. Data export/deletion remain possible behind an expired subscription gate.

No live or Sandbox purchase acceptance run has been performed yet. Account configuration and this end-to-end evidence remain release blockers.
