# Accounts, Firebase, Superwall — what to plug in

Along talks to **Firebase Auth + Firestore** from the iPhone (no Cloudflare Worker). Superwall stays for paywalls/A-B. Until the files below exist, Debug still runs with local StoreKit (`pk_local_storekit`).

**Onboarding account flow:** questionnaire → plan → **account** (email/password or Apple/Google) → paywall. Firebase create/sign-in runs automatically after a successful purchase (OAuth may already be signed in). Welcome “Sign in” is for returning members only.

**Main tabs:** Today · Progress · Settings (Health tab removed). Peptides open as a sheet from Today or Settings.

**Account storage.** Each signed-in UID has its own device journal and Firestore document at `users/{uid}/app/state`. Backups include `journalBase64`, `setupBase64` and a revision used by conditional writes. Existing backups without a revision use a digest of their saved payload. The original on-device journal remains separate. To bring older local entries into a chosen account, export the on-device journal and use the existing confirmed backup restore in that account.

**Two-account device check.** Give two test accounts distinctly named records. On one phone, open A, make an edit offline, sign out, and sign in to B. Verify B shows its own records and backup. Reconnect and return to A to check that the offline edit reaches A. Repeat with an empty account and confirm it starts with an empty journal.

## 1. Firebase

Project **`peptide-tracker-6d1b1`** is wired (iOS app `dev.along.prototype`, appId `1:701995397873:ios:7d0fb375a68c8ab4026f50`).

**Done via CLI/MCP:** Email/Password + Google Auth, Firestore (`nam5`) + user-scoped rules, local `GoogleService-Info.plist` (gitignored), URL scheme from `REVERSED_CLIENT_ID`.

**Still manual:**
1. [Auth providers](https://console.firebase.google.com/project/peptide-tracker-6d1b1/authentication/providers) → enable **Apple**.
2. Apple Developer → Identifiers → App ID `dev.along.prototype` → enable **Sign In with Apple** (entitlement already in `Along.entitlements`).
3. Keep plist at `plateful/apps/ios/Along/GoogleService-Info.plist` (never commit). Regenerate Xcode project after plist changes: `python3 apps/ios/generate_project.py`.

Suggested rules sketch:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/app/{doc} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## 2. Superwall + App Store Connect

1. [App Store Connect](https://appstoreconnect.apple.com) → your app → Subscriptions → one group, **monthly** + **yearly**, **no free trial**.
2. Note the product IDs.
3. [Superwall](https://superwall.com) → iOS app → copy **Public API Key**.
4. Map both products to entitlement `along.membership` (or change `ALONG_BILLING_ENTITLEMENT_ID`).
5. Create/placement **`onboarding_end`** paywall (optional if you keep the native SwiftUI paywall as fallback).
6. Put real values in Release build settings (see `Secrets.example.xcconfig`):

- `ALONG_BILLING_ANNUAL_PRODUCT_ID`
- `ALONG_BILLING_MONTHLY_PRODUCT_ID`
- `ALONG_SUPERWALL_PUBLIC_KEY`
- `ALONG_BILLING_ENTITLEMENT_ID`
- `ALONG_TERMS_URL` / `ALONG_PRIVACY_URL` (public HTTPS, not example.com)

## 3. After files are in place

1. `python3 apps/ios/generate_project.py`
2. Open Xcode → resolve packages (Firebase + GoogleSignIn + Superwall).
3. Run on a device/simulator → Sign in sheet should authenticate → Settings shows account + sync.
4. Sandbox purchase with a Sandbox Apple ID.

## Smoke checklist

- [ ] Apple / Google / email sign-in
- [ ] Sign out
- [ ] Second device or reinstall restores cloud journal when signed in
- [ ] Sandbox subscribe unlocks tabs
- [ ] Restore purchases
- [ ] Crashlytics test (optional) after plist is present
