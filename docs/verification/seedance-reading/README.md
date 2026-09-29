# Seedance reading animation

Home uses one bundled, silent, five-second video of the welcome kitten turning one book page. The procedural limb and page rig has been removed. The video pauses when Home is covered, tickers are disabled, the app is hidden, or reduced motion is enabled. Reduced motion and playback failures show the original still artwork. No generation service or API key is used by the app.

## Generation and cost

- Model: `bytedance/seedance-2.5`, through OpenRouter.
- Exactly one generation submission; no generation retries or rerolls.
- Reported generation cost: **$1.1725702** ([receipt](receipt.json)).
- [Detailed prompt](prompt.txt), [request settings without credentials](request.json), [reference](reference.png), [original artwork crop](original.png).
- The same reference was supplied as the first and last frame. Seventy pixels were added to each side to meet the model's 1112 × 834 format without stretching the original illustration.
- [Original output MP4](seedance-reading.mp4) and [playable preview with speed controls](preview.html).

## App asset

[Bundled loop](../../../assets/art/mimi/reading/reading.mp4): 972 × 834 H.264, 121 frames over exactly 5.000 seconds, 946,603 bytes, no audio track. Only the added side margins were cropped. All generated frames are retained; retiming from 24 to 24.2 fps makes the source's 5.0417-second duration exactly five seconds. Encoding uses CRF 18 and MP4 fast start. [Encoding command and log](asset-encoding.txt).

The player remains mounted beneath the still artwork when motion is disabled. This avoids the browser interrupting playback when a detached video element is reinserted.

## Visual verification

All **121 decoded frames** were reviewed in chronological contact sheets: [0–1 s](contact-1.jpg), [1–2 s](contact-2.jpg), [2–3 s](contact-3.jpg), [3–4 s](contact-4.jpg), [4–5 s](contact-5.jpg), [final frame](contact-6.jpg). Enlarged checks cover [paws and page contact](paw-page-closeups.jpg) and [ears and face](ears-face-closeups.jpg).

The review checks the head following the page, stable ears, eyelids, connected forearms and paws, the supporting grip, one forward page turn attached at the spine, book details, grounded feet, tail, and return to the original pose. First and last frames are visually close, but not pixel-identical: mean RGB difference 2.09/255, compared with 1.92/255 median difference between adjacent frames. These measurements support the review; they are not a substitute for inspecting the artwork. [Frame review](frame-review.json).

## Reproduce app checks

Final results (2026-09-28): `flutter analyze --no-pub` found no issues; the full Flutter suite passed **84 tests**; the release web build passed. The [Flutter web check](flutter-web-checks.json) passed with **276 video frames, zero dropped frames, two loop boundaries, and no browser errors** during its uninterrupted sample. Reduced motion stayed visually unchanged for 5.2 seconds; restoring motion and leaving/returning to Home both resumed playback correctly.

Rendered evidence: [320 px](home-320.png), [430 px](home-430.png), [1365 px](home-1365.png), [reduced motion](home-reduced-motion.png). These checks exercise Chromium and do not claim native-device performance.

```sh
flutter analyze --no-pub
flutter test --no-pub --concurrency=1
flutter build web --release --no-pub
# Serve build/web locally, then:
APP_URL=http://127.0.0.1:7359 node tools/seedance_reading_web_check.cjs
```

The web check measures uninterrupted video playback across two loop boundaries, checks 320/430/1365 px layouts, verifies the still image over a complete reduced-motion cycle and playback after motion is restored, navigates away and back, and checks browser errors, silence, and unchanged saved reading state. Native Android/iOS playback has not been exercised in this environment.
