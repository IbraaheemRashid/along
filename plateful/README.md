# Along

A native SwiftUI peptide protocol tracker. Along helps people who have just bought, or are about to start, peptides keep their protocol, every dose, reminders and progress in one place. It is a supporting tool, not a source of dosing or medical advice. Along is a working name.

## Try the iOS app

Open `apps/ios/Along.xcodeproj` in Xcode, choose the **Along** scheme and an iPhone Simulator, then Run. No Apple developer account, server, API key or payment is required for simulator use. iOS 17 or later.

Setup is a peptide-specific onboarding that ends in a direct subscription offer with **no trial**. In a Debug build, **Open design preview** on the paywall opens the app without a subscription. Any setup screen can be opened directly:

```sh
xcrun simctl launch booted dev.along.prototype --setup-step paywall
```

See [the iPhone walkthrough](docs/iphone-walkthrough.md) for screenshots and a downloadable simulator build.

## Dev Lab

In a Debug build, the wrench on the welcome screen (or the Dev Lab bar inside the app) opens isolated sandboxes, every setup screen with example answers, and shortcuts to individual features. Sandboxes never touch the normal data or credentials. Release builds omit these tools.

## What is connected

The default build keeps journal data on the device. You can export, restore or delete it. A configured account build can store a backup for the signed-in user. The automated walkthrough runs checkout against local StoreKit and account operations against local Firebase emulators. Live sign-in, subscription products, billing configuration and signed-device delivery still need release verification.

## Local commands

From this folder:

```sh
bash scripts/check.sh
bash scripts/dev-api.sh
bash scripts/dev-web.sh
```

The scripts use an installed Node 22.18+ binary or the bundled Codex Node runtime. Web dependencies need to have been installed in `apps/web`; the lockfile records the versions. Native tests require Xcode. UI tests are run through Xcode’s Test action and use an isolated review directory; they do not reset the normal journal or credentials. The Debug launch argument `--setup-step <screen>` opens setup in that isolated directory.

To regenerate the small Xcode project after adding Swift files:

```sh
python3 apps/ios/generate_project.py
```

The generated project and original icon are committed, so regeneration is not needed for normal use.

## Product and validation

Start with [the build plan](docs/peptide-tracker-plan.md) and [actual implementation status](docs/progress.md). Older documents in `docs/` describe the retired GLP-1 journal and are kept for history.

The product has no measured conversion or retention yet.
