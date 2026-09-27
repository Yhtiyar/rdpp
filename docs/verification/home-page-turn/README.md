# Coordinated reading loop

Home uses one five-second animation: MiMi reads, looks down, lifts its paw to the book's corner, carries the page into a turn, releases it, and settles back into reading. Head movement, gaze, blinking, breathing, supporting paw, tail, and the page share the same timeline.

The scene uses `assets/art/mimi_reading.webp` and the existing `assets/art/mimi/ready_blink.webp` expression. The page corner follows the fingertip while held. Fur edges are feathered, and the foreleg bends using texture from the original artwork. The scene is silent and pauses for reduced motion, hidden routes, disabled tickers, and app backgrounding.

Verified on 2026-09-27:

- `flutter analyze`: no issues.
- `flutter test`: 66 tests passed. These cover the five-second cycle, paw/page contact, continuous poses, route and lifecycle pausing, reduced motion, and cleanup.
- `flutter build web --no-web-resources-cdn`: passed.
- `node tools/home_animation_web_check.cjs`: checks head and paw motion separately from the surrounding UI, persisted state, reduced motion over a full cycle, responsive layouts, silence, and browser errors.
- Flutter web poses reviewed at close range, then the full sequence reviewed on Home at 430 pixels wide. Layouts captured at 320 and 1365 pixels wide as well.

[Play the loop](preview.html) · [WebM recording](home-page-turn.webm) · [Motion frames](motion-frames.png) · [Browser results](checks.json)

The recording contains uninterrupted playback of Home. Pixel checks run separately to avoid screenshot capture stalls affecting the recorded motion.

To scrub individual poses locally:

```sh
flutter run -d web-server --no-web-resources-cdn -t tools/mimi_reading_preview.dart
```
