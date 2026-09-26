# Home kitten page turn

Home reuses the exact kitten-with-book artwork from the welcome screen. A curled paper leaf turns across the book every five seconds; each turn lasts 850 milliseconds. The kitten and book cover stay still between turns. The animation is silent and stops when hidden or when reduced motion is enabled.

Verification on 2026-09-26:

- `flutter analyze`: no issues.
- `flutter test`: 61 tests passed, including exact five-second cadence, ordinary rebuilds, reduced motion, disabled tickers, lifecycle pause, and disposal.
- `flutter build web --no-web-resources-cdn`: passed.
- `node tools/home_animation_web_check.cjs`: eight browser checks passed. Sampled screenshots observe two turns approximately five seconds apart (500 ms capture tolerance); widget tests verify the exact timer interval. Saved reading state stays unchanged and no sound is requested.
- Flutter web visually checked at 320, 430, and 1365 pixels wide. No browser exceptions or layout overflows reported.

[Browser recording](home-page-turn.webm) · [Motion frames](motion-frames.png) · [Browser results](checks.json)

The recording includes normal motion followed by the reduced-motion and viewport checks. Screenshots show the idle scene, a lifted page, and the page settling back onto the book.
