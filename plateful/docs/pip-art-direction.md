# Pip character assets

## 2D Pip refresh — 1 November 2026

The user requested a 2D Pip and Finch-informed pet interactions. Pip keeps the original bear/sprout identity, apricot body, cream belly and muzzle, plum features and leaf tuft. The current artwork is a flat cartoon illustration with plum outlines; it is a set of PNG assets, not a skeletal animation model. Five transparent images support greeting, journal, happy reaction, scarf and flower states. An opaque square icon uses the same character.

All six images were created with the built-in `image_gen.imagegen` tool. The first used the previous `PipWelcome` PNG as its edit target. Every subsequent image used the new 2D base as its reference. No CLI API or third-party image vendor was used. The five character PNGs were copied unchanged, preserving alpha; the opaque icon was resized to 1024×1024 with macOS `sips` for the asset catalogue. All outputs were visually inspected. The originals remain in the tool output directory.

| Current native asset | Source in the tool output directory |
| --- | --- |
| `Pip2DWelcome.imageset/pip.png` | `exec-0bb57594-d148-4ddf-889e-77e97453f501.png` |
| `Pip2DJournal.imageset/pip.png` | `exec-6f6c6d0a-881f-4f68-b105-2f259c3ff117.png` |
| `Pip2DCelebrate.imageset/pip.png` | `exec-20c541f8-767e-46dc-8999-1ad9140f109c.png` |
| `Pip2DScarf.imageset/pip.png` | `exec-c9618277-05ff-437e-9edd-e40b6555f743.png` |
| `Pip2DFlower.imageset/pip.png` | `exec-2ad82bbd-3c38-4ced-a7e4-a3fe19c32b40.png` |
| `AppIcon.appiconset/AppIcon.png` | `exec-118ab81c-3a88-4f52-a5c8-2d721b672d4f.png` |

Asset paths are relative to `apps/ios/Along/Assets.xcassets`. Tool outputs are in `/Users/ibraaheemrashid/.codex/generated_images/01a19601-6588-74c0-9067-504d6feece4f`.

### 2D prompt set

Base (transparent):

> Use case: style-transfer. Edit target: attached original Pip mascot for the Along iOS app. Redesign this same apricot bear-sprout character as a charming genuinely FLAT 2D vector-style mascot, suitable for a gentle adult journaling app. Keep the round bear ears, cream belly and muzzle, small plum eyes and nose, two small leaf sprouts on head, compact full-body shape. Replace all realistic fur, highlights, shadows, gradients and 3D rendering with simple solid colour shapes and a smooth medium-weight dark plum outline. Warm apricot body, cream belly/muzzle, plum outline/features, muted apricot blush, a small muted sage sprout as identity detail. Tiny simple oval eyes, friendly curved smile, relaxed stance, one paw raised in greeting. Flat editorial cartoon, confident simple silhouette, not a bird and no Finch branding. One character only, entire body and feet visible, centred with generous equal transparent margin on all sides. Genuine transparent background, no floor shadow, no scenery, no text, no accessories or props beyond the head sprout. This is the production base character, not a sheet of variations.

Each variant used this common prefix and suffix around its change below, with transparency enabled:

> Use case: precise-object-edit. Edit this exact original 2D Pip character into a matching production iOS asset. [CHANGE] Preserve the same flat cartoon design, smooth plum outlines, apricot body, cream muzzle and belly, leaf sprout, face identity, outline thickness and warm palette. Simple flat solid colours, no realistic shading, no texture or 3D. One character, full body entirely visible, centred at the SAME scale and same transparent margins as this reference. Genuine transparent alpha, no background, ground, cast shadow, text or watermark.

- Journal change: “Change only the pose: Pip sits holding a small closed PLUM journal against the cream belly with both paws; relaxed friendly smile. Head sprout stays visible.”
- Celebration change: “Change only the expression and pose: both little paws raised slightly in a friendly hello, eyes closed as happy curved arcs, small smile. No props, no confetti.”
- Scarf change: “Change only this: add a short simple solid PLUM scarf around the neck with one short tail. Keep original greeting pose and all body proportions.”
- Flower change: “Change only this: add a small simple golden five-petal flower beside the head sprout. Keep original greeting pose and all body proportions.”

Icon (opaque):

> Edit the attached original 2D Pip character into an iOS app icon for Along. Preserve the exact flat cartoon style, apricot face, small plum features, round ears and leaf sprout. Square 1024 by 1024 full-bleed warm cream background, no rounded outside corners. Large centred head and upper body with sprout fully visible and balanced generous margin, recognisable at small size. Flat colours and plum outlines. No text, letters, watermark, framing, 3D or photographic effects. Fully opaque image.


## Earlier 3D render set — historical reference

The following records the previous assets, which are retained as source history. `PipArtwork` uses the 2D set above.

### Earlier art direction

Pip is an original warm apricot, bear-like woodland companion with a cream muzzle and belly, deep-plum eyes, small rounded ears, rosy cheeks and a sage two-leaf tuft. Soft sculpted volume and velvety microtexture replace the initial code-drawn mascot's simple forms. The full-body silhouette, warm expression and visible feet are intended to remain readable at small iPhone onboarding sizes.

This delivery is a set of rendered PNG assets, not a rigged 3D model or mesh. Welcome, journal and quiet celebration poses support introductions, reflection and routine milestones. Plum scarf and golden flower variants visibly support the accessory selection. Pip does not represent medication effects, weight loss or a clinical outcome.

## Generation provenance

- Generation method: built-in `image_gen.imagegen`; no CLI, external image vendor, paid API credentials or model override was used. The underlying model name was not exposed by the built-in tool.
- All six calls set `transparent_background: true`.
- The first call generated an original character without reference images. A second call refined framing. The four variants each used that same refined welcome PNG as their sole local image reference, preserving identity instead of independently generating a new character.
- All six exact prompts and their input/output paths are recorded below.
- Selected PNG files were copied unchanged from the built-in tool's output directory. No alpha thresholding, background removal, recolouring, resizing, or raster postprocessing was applied.
- The original outputs remain at `/Users/ibraaheemrashid/.codex/generated_images/01a1964e-29b2-7e53-9178-8a5837539d69`.

## Delivered files

Every set contains `pip.png` plus a valid `Contents.json` declaring a universal image. The canonical relative prefix is `apps/ios/Along/Assets.xcassets/`.

| Asset name | Image path | Source output | Bytes |
|---|---|---|---:|
| PipWelcome | `PipWelcome.imageset/pip.png` | `exec-5e19b92f-159e-421f-8ea2-0f269b71dbc1.png` | 1083278 |
| PipJournal | `PipJournal.imageset/pip.png` | `exec-f6353877-0f2d-44d8-b519-e6133a775a6d.png` | 1109497 |
| PipCelebrate | `PipCelebrate.imageset/pip.png` | `exec-6049e104-5214-4809-90bc-2210dcab1d1d.png` | 1152445 |
| PipScarf | `PipScarf.imageset/pip.png` | `exec-00ec2518-4222-4a69-8483-f4c0ce25732e.png` | 1095487 |
| PipFlower | `PipFlower.imageset/pip.png` | `exec-eeb74c2a-8d80-47ed-8b03-b684ad217afb.png` | 1025503 |

All five images are **1254 × 1254, RGBA PNG**, with real alpha values spanning 0–255.

### SHA-256 hashes

- `PipWelcome`: `e57309c396c8c91a968938fd204576d94049d4aa36f3c27f674bc50e4de4d8b8`
- `PipJournal`: `1828a237d31ecdc7e075105996dc48f2747439f8e7cf385b7c008eec622f361e`
- `PipCelebrate`: `c73663346a5ef3ea8de9031a6ac74e95de115870bf5981305b29ff4e20fb0ccc`
- `PipScarf`: `e922246d70bf4b5ecb5f77ca4950ceb851ec7fd6942b38a2216d77d2abff03f4`
- `PipFlower`: `af0adfb8c44641bdb3b769dc80b98ca7a47ce9988288440219b5156b5b047a8e`

## Verification

Each generated image was opened and visually inspected with `view_image`. The five delivered files were decoded with Pillow; their dimensions, RGBA mode, alpha extrema, visible-subject bounds, asset-catalog filename references and SHA-256 hashes were checked. The character identity, complete body and intended pose/accessory are visibly consistent across the set.

The generated files have faint low-alpha fringe/speckle pixels. In the welcome render the saturated red/yellow fringe seen in the tool's black preview has alpha 1–3 out of 255; it is not an opaque outline. Scarf has a single corner alpha of 1; the other reported corner values are 0. Original alpha was deliberately preserved. Bounds below use alpha ≥10 to distinguish the visible character from this near-transparent noise. The requested 12% margin was approximate in the actual generation; all meaningful subject pixels remain inside the canvas, with around 5–8% top/bottom margin. Confirm appearance in the native app's cream background at final UI size during integration; native rendering was not changed or verified by this asset-only task.

| Asset | Visible bounds (left, top, right, bottom; alpha ≥10) | Corner alpha (TL, TR, BL, BR) |
|---|---|---|
| PipWelcome | 229, 67, 985, 1156 | 0, 0, 0, 0 |
| PipJournal | 296, 68, 994, 1175 | 0, 0, 0, 0 |
| PipCelebrate | 186, 62, 1090, 1161 | 0, 0, 0, 0 |
| PipScarf | 228, 65, 986, 1158 | 1, 0, 0, 0 |
| PipFlower | 229, 66, 986, 1158 | 0, 0, 0, 0 |

## Integration notes

Use asset names `PipWelcome`, `PipJournal`, `PipCelebrate`, `PipScarf` and `PipFlower` in SwiftUI with proportional fitting. Scarf/flower variants retain the leaf tuft. These assets do not alter UI, source files, project settings or the existing vector implementation; the parent implementation owns their integration. The accessory variants are welcome poses; journal and celebration currently use the base leaf design.

## Exact generation prompts

### Initial welcome concept (not shipped)

No input image.

Output: `/Users/ibraaheemrashid/.codex/generated_images/01a1964e-29b2-7e53-9178-8a5837539d69/exec-be8df5a5-1e03-47f1-a861-705a18468e65.png`

```text
Use case: stylized-concept
Asset type: finished transparent character asset for Along, an adult wellbeing iPhone app; a polished rendered mascot, not a logo or flat vector.
Primary request: Create Pip, an original soft 3D sculpted woodland companion, warmly welcoming the viewer with one small paw raised in a gentle wave. One character only.
Subject: a warm apricot bear-like little woodland creature with an appealing rounded pear-shaped body, small rounded ears, cream muzzle and belly, deep plum eyes, tiny plum nose, subtle rosy cheeks, and a simple sage-green leaf tuft. An understated, kind smile; calm and friendly, appealing to adults. Two small feet visible, coherent character anatomy and silhouette. The character is original, with no resemblance to an existing app mascot.
Style/medium: premium high-quality 3D character render, carefully art-directed matte clay with a velvety soft microtexture; dimensional sculpted forms and nuanced soft studio lighting, subtle subsurface warmth, restrained highlights. Refined character design, not basic geometric circles, not flat clip art, not a plastic toy.
Composition/framing: full body, centered, facing almost front with a slight three-quarter turn; both feet, all ears, leaf, and raised paw completely in frame. Square canvas, approximately 12 percent generous transparent margin around the entire silhouette. Soft welcoming pose suitable at 240 points tall in an iPhone onboarding screen.
Color palette: warm apricot body #D99580, warm cream muzzle and belly #FAF7F1, deep plum facial features #4D3B67, muted sage leaf #A6BA95. Harmonious natural shading around those colours.
Scene/backdrop: genuinely transparent background with clean alpha, isolated cutout. No floor, no backdrop, no cast shadow outside the character, no scenery.
Constraints: one complete original character only, no text, no lettering, no logo, no watermark, no UI, no frame, no additional props. Preserve the actual transparent alpha.
```

### Welcome refinement (shipped identity anchor)

Input: /Users/ibraaheemrashid/.codex/generated_images/01a1964e-29b2-7e53-9178-8a5837539d69/exec-be8df5a5-1e03-47f1-a861-705a18468e65.png

Output: `/Users/ibraaheemrashid/.codex/generated_images/01a1964e-29b2-7e53-9178-8a5837539d69/exec-5e19b92f-159e-421f-8ea2-0f269b71dbc1.png`

```text
Use case: identity-preserve
Asset type: production transparent mascot PNG for an iPhone app.
Input images: Image 1 is Pip, the character anchor and edit target.
Primary request: Keep exactly this original Pip character and gentle waving pose, but make a clean, correctly padded app asset. Change only the framing and alpha-edge cleanup.
Identity invariants: Preserve the exact apricot bear-like character, its face, body and limb proportions, cream muzzle and belly, deep plum eyes and nose, muted sage two-leaf tuft, rosy cheeks, warm friendly smile, paw pads, velvety softly sculpted 3D materials, and soft studio lighting. Preserve the complete body and original pose.
Composition/framing: Square canvas. Scale the entire visible character including leaf and feet to occupy only 76 percent of canvas height, centered with a full 12 percent transparent margin above the leaf and below the feet. All of the body must remain visible. Add generous completely transparent space on all four sides.
Scene/backdrop: Genuine transparent alpha. No floor, no scenery, no background, no cast ground shadow.
Constraints: The cutout must have a clean antialiased alpha boundary. Remove the tiny bright red/yellow/white edge flecks and stray alpha speckles visible around the reference silhouette; no coloured halo or fringe. Nothing outside the character silhouette except fully transparent pixels. Do not add props or redesign the character. No text, no logo, no watermark.
```

### Journal variant

Input: /Users/ibraaheemrashid/.codex/generated_images/01a1964e-29b2-7e53-9178-8a5837539d69/exec-5e19b92f-159e-421f-8ea2-0f269b71dbc1.png

Output: `/Users/ibraaheemrashid/.codex/generated_images/01a1964e-29b2-7e53-9178-8a5837539d69/exec-f6353877-0f2d-44d8-b519-e6133a775a6d.png`

```text
Use case: identity-preserve
Asset type: transparent 3D mascot pose variant for the Along iPhone app.
Input images: Image 1 is Pip, the identity anchor and edit target.
Primary request: Create the journaling pose of this exact character. Change only the arm pose, gaze and small book: Pip gently holds a small open deep-plum journal in front of the lower cream belly, with one paw supporting the book and the other resting thoughtfully on a blank page. A calm content smile, head tilted just slightly toward the journal, face still fully readable.
Identity invariants: Do not redesign Pip. Preserve exactly the warm apricot bear-like woodland creature, rounded pear-shaped body, head-to-body proportions, small rounded ears, cream muzzle and belly, deep-plum eyes and nose, subtle rosy cheeks, sage two-leaf tuft, little feet, and nuanced velvety soft 3D microtexture of Image 1. Match the reference's lighting, palette, rendering quality and camera angle.
Composition/framing: Whole body including feet and leaf entirely visible, centered on a square canvas, character occupies approximately 76 percent of image height with generous empty transparent margins. The small journal must not cover the face or most of the belly.
Materials: same matte softly sculpted character finish; simple plum book cover #4D3B67 and warm cream blank pages, no text or symbols.
Scene/backdrop: genuine transparent background, clean alpha, no floor, no cast ground shadow, no scenery.
Constraints: one character, one small book only. No extra props, no clothes, no text, no lettering, no logo, no watermark, no frame, no UI, no confetti. Preserve identity and real transparency; clean cutout edges.
```

### Quiet celebration variant

Input: /Users/ibraaheemrashid/.codex/generated_images/01a1964e-29b2-7e53-9178-8a5837539d69/exec-5e19b92f-159e-421f-8ea2-0f269b71dbc1.png

Output: `/Users/ibraaheemrashid/.codex/generated_images/01a1964e-29b2-7e53-9178-8a5837539d69/exec-6049e104-5214-4809-90bc-2210dcab1d1d.png`

```text
Use case: identity-preserve
Asset type: transparent 3D mascot pose variant for the Along iPhone app.
Input images: Image 1 is Pip, the identity anchor and edit target.
Primary request: Create the quiet celebration pose of this exact character. Change only the pose and expression: Pip has a slightly more delighted yet gentle closed-mouth smile and softly opens both small arms outward and a little upward, a calm welcoming little "you did it" gesture. Both feet stay comfortably planted. This is warm encouragement for an adult wellbeing app.
Identity invariants: Do not redesign Pip. Preserve exactly the warm apricot bear-like woodland creature, rounded pear-shaped body, head-to-body proportions, small rounded ears, cream muzzle and belly, deep-plum eyes and nose, subtle rosy cheeks, sage two-leaf tuft, little feet, plum paw pads, and nuanced velvety soft 3D microtexture of Image 1. Keep the deep-plum eyes open and friendly. Match reference lighting, palette, rendering quality and camera angle.
Composition/framing: Whole body including feet, both paws and leaf entirely visible, centered on a square canvas, character occupies approximately 76 percent of image height with generous empty transparent margins. The two arms create a clean readable silhouette.
Scene/backdrop: genuine transparent background, clean alpha, no floor, no cast ground shadow, no scenery.
Constraints: one complete character only. No confetti, sparkles, stars, trophies, banners, extra props, clothes, text, lettering, logos, watermark, frame or UI. Do not exaggerate into a frantic jump or shouting expression. Preserve identity and real transparency; clean cutout edges.
```

### Scarf accessory variant

Input: /Users/ibraaheemrashid/.codex/generated_images/01a1964e-29b2-7e53-9178-8a5837539d69/exec-5e19b92f-159e-421f-8ea2-0f269b71dbc1.png

Output: `/Users/ibraaheemrashid/.codex/generated_images/01a1964e-29b2-7e53-9178-8a5837539d69/exec-00ec2518-4222-4a69-8483-f4c0ce25732e.png`

```text
Use case: identity-preserve
Asset type: transparent 3D mascot accessory variant for Along iPhone onboarding.
Input images: Image 1 is Pip's welcome pose, the identity anchor and edit target.
Identity invariants: Preserve exactly the apricot bear-like woodland creature, rounded pear-shaped full body, head-to-body proportions, small rounded ears, cream muzzle and belly, deep-plum eyes and nose, subtle rosy cheeks, sage two-leaf tuft, feet, raised waving paw and plum paw pads. Preserve the original gentle smile, eye direction, pose, lighting, camera angle, full-body framing, generous transparent margins, soft velvety microtexture and 3D sculpted rendering. Do not redesign Pip.
Scene/backdrop: genuine transparent background with clean alpha; no floor, ground shadow or scenery.
Constraints: Change only the requested accessory. One full character, no other props, no text, no logo, no watermark, no UI. Do not crop the ears, feet, leaf or waving paw. Preserve actual transparency.
Primary request: Add a small tasteful deep-plum knitted scarf around Pip's neck. It should be a short soft scarf with one little folded tail resting just below the cream muzzle, clearly visible at small iPhone UI sizes, without covering the muzzle or most of the cream belly. Subtle knitted texture, colour #4D3B67. Retain the sage leaf tuft and every other character feature unchanged.
```

### Flower accessory variant

Input: /Users/ibraaheemrashid/.codex/generated_images/01a1964e-29b2-7e53-9178-8a5837539d69/exec-5e19b92f-159e-421f-8ea2-0f269b71dbc1.png

Output: `/Users/ibraaheemrashid/.codex/generated_images/01a1964e-29b2-7e53-9178-8a5837539d69/exec-eeb74c2a-8d80-47ed-8b03-b684ad217afb.png`

```text
Use case: identity-preserve
Asset type: transparent 3D mascot accessory variant for Along iPhone onboarding.
Input images: Image 1 is Pip's welcome pose, the identity anchor and edit target.
Identity invariants: Preserve exactly the apricot bear-like woodland creature, rounded pear-shaped full body, head-to-body proportions, small rounded ears, cream muzzle and belly, deep-plum eyes and nose, subtle rosy cheeks, sage two-leaf tuft, feet, raised waving paw and plum paw pads. Preserve the original gentle smile, eye direction, pose, lighting, camera angle, full-body framing, generous transparent margins, soft velvety microtexture and 3D sculpted rendering. Do not redesign Pip.
Scene/backdrop: genuine transparent background with clean alpha; no floor, ground shadow or scenery.
Constraints: Change only the requested accessory. One full character, no other props, no text, no logo, no watermark, no UI. Do not crop the ears, feet, leaf or waving paw. Preserve actual transparency.
Primary request: Add one small warm golden-yellow flower accessory nestled beside Pip's sage leaf tuft near the top of the head. The flower has five simple rounded softly sculpted petals and a slightly deeper golden centre, colour #F2BE68, clearly visible at small iPhone UI sizes. Keep it understated and part of the same premium 3D material style. Retain the sage two-leaf tuft and every other character feature unchanged.
```
