# Along — 26-screen onboarding review

The native SwiftUI flow is implemented with no trial. The offer proposes US$29.99/year or US$5.99/month, charged immediately after a successful purchase in the intended production flow. This build cannot take payment: App Store products and Superwall are not connected.

These simulator captures use example answers, not a customer's journey. Screens with more content scroll; each numbered image shows its opening position. The real flow saves the first entry before revealing it on screen 23.

The latest pass applies the plum, cream and apricot palette, rounded choice cards and original 2D Pip throughout onboarding and the app. [Open the complete screen gallery](screenshots/whole-style/index.html) or use the individual captures below.

## Review interactively

Open `apps/ios/Along.xcodeproj`, select Along and run a Debug build. Tap **Dev Lab → Browse all 26 screens** to jump straight into review. The catalogue uses a separate example journal. Dev Lab also provides test scenarios, feature shortcuts, appearance/text-size controls and saved sandbox sessions. The original **You → Review all 26 onboarding screens** route is still available after entering the app preview.

To revisit setup directly without changing the normal journal, use the Debug launch argument `--review-onboarding`. UI tests also use an isolated directory and do not clear the normal journal or credentials.

## Dev Lab

Start with **14-day sample journey** to explore the app immediately, or choose **Fresh onboarding** to test setup from the beginning. **Tools** returns to the lab. The sliders button inside a sandbox provides appearance/text-size controls, JSON inspection, a save-error alert preview and reload options.

**Reload saved state from disk** checks persistence without replacing your edits. **Reload this scenario** asks before discarding sandbox edits. **Resume last sandbox** reopens the most recent test session even after restarting the app. New scenarios create separate sessions; sample records are fictional.

- [Dev Lab menu](screenshots/dev-lab/dev-lab-menu.png)
- [Saved check-in after restart](screenshots/dev-lab/dev-resumed-sandbox.png)
- [Empty journal](screenshots/dev-lab/dev-scenario-empty.png)
- [30 recorded days](screenshots/dev-lab/dev-scenario-month.png)

The connection-status section identifies unconfigured services. Checkout and restore cannot charge or unlock access. Save-error preview exercises the alert UI; it does not simulate an actual disk failure. Dev Lab is excluded from Release builds.

## Screens

| Screen | Design |
| --- | --- |
| 01 | [Your journey. A little company.](screenshots/whole-style/01.png) |
| 02 | [First, what should we call you?](screenshots/whole-style/02.png) |
| 03 | [Where are you in your journey?](screenshots/whole-style/03.png) |
| 04 | [Every story has a beginning.](screenshots/whole-style/04.png) |
| 05 | [What brings you here?](screenshots/whole-style/05.png) |
| 06 | [What gets in the way?](screenshots/whole-style/06.png) |
| 07 | [The little things tell a bigger story.](screenshots/whole-style/07.png) |
| 08 | [What would you like to notice?](screenshots/whole-style/08.png) |
| 09 | [Keep your why close by.](screenshots/whole-style/09.png) |
| 10 | [Your journal. Your kind of progress.](screenshots/whole-style/10.png) |
| 11 | [A starting point, if you’d like one.](screenshots/whole-style/11.png) |
| 12 | [There’s room for all of your progress.](screenshots/whole-style/12.png) |
| 13 | [Make room for a little routine.](screenshots/whole-style/13.png) |
| 14 | [Make it your own.](screenshots/whole-style/14.png) |
| 15 | [Find a rhythm that fits real life.](screenshots/whole-style/15.png) |
| 16 | [A moment that works for you.](screenshots/whole-style/16.png) |
| 17 | [A little time to look back.](screenshots/whole-style/17.png) |
| 18 | [Your kind of encouragement.](screenshots/whole-style/18.png) |
| 19 | [A little more personality.](screenshots/whole-style/19.png) |
| 20 | [A name for your little companion.](screenshots/whole-style/20.png) |
| 21 | [Let’s begin with today.](screenshots/whole-style/21.png) |
| 22 | [One small moment. Worth remembering.](screenshots/whole-style/22.png) |
| 23 | [Your first page. Already yours.](screenshots/whole-style/23.png) |
| 24 | [A space that feels like you.](screenshots/whole-style/24.png) |
| 25 | [One membership. Your whole journey.](screenshots/whole-style/25.png) |
| 26 | [Your next chapter.](screenshots/whole-style/26.png) |

## Accessibility captures

- [Dark appearance with the largest text size](screenshots/whole-style/26-dark-xxxl-top.png)
- [Monthly-plan review](screenshots/whole-style/26-dark-xxxl-monthly-price.png)

## Pip

Pip now uses five original transparent 2D illustrations, with a matching app icon. The original prompts and asset provenance are in [Pip art direction](pip-art-direction.md).

- [Welcome](../apps/ios/Along/Assets.xcassets/Pip2DWelcome.imageset/pip.png)
- [Journal](../apps/ios/Along/Assets.xcassets/Pip2DJournal.imageset/pip.png)
- [Celebration](../apps/ios/Along/Assets.xcassets/Pip2DCelebrate.imageset/pip.png)
- [Scarf](../apps/ios/Along/Assets.xcassets/Pip2DScarf.imageset/pip.png)
- [Flower](../apps/ios/Along/Assets.xcassets/Pip2DFlower.imageset/pip.png)

Tap or hold Pip to say hello. On the Pip tab, share a short fictional story, choose a reply and keep a discovery. The three stories are written in advance; there is no live AI chat. Discoveries survive a restart and appear in the local export. Petting and story choices do not affect health records or unlocks. Existing keepsakes can be previewed, with available items saved as Pip’s current look.

The interaction references inspected on Mobbin are Finch’s [petting](https://mobbin.com/flows/3644cfb2-cfe3-42d4-b910-02eb4f8ce3b5), [conversation](https://mobbin.com/flows/6af44145-2846-4ab8-857a-3225dc3f8760) and [outfit preview](https://mobbin.com/flows/8d11ddab-533c-4a91-aa43-1c5541c6fd33) flows. Along uses its own artwork, room and writing. The hard paywall is the user’s chosen model, not a claim about Finch’s offer.

See [implementation and verification status](progress.md) for completed checks and remaining live-service work.
