# Littlewins MVP verification

Date: 2026-09-25. Platform: Flutter web in headless Chromium, with mobile and desktop viewports. MobAI was not used.

## Verified

- Flutter unit/widget suite: **18 tests passed**. Coverage: reading content integrity, PIN/recovery/cooldown, unique page credit, cross-book 100-coin accounting, persisted positions, failed reward writes, daily caps, midnight/expiry, concurrent purchases, activation errors, receipt reconciliation, and parent-session invalidation.
- Chromium UI: complete onboarding, library, reader, wrong answer/hint, correct answer/reward, ten actual page credits, 100-coin purchase of a 15-minute preview, timer after reload, wrong parent PIN, parent settings, Russian interface, English questions under Russian UI, locale persistence, 320px phone and desktop layouts.
- Browser run aborted external requests: no external runtime asset request and no browser error occurred. Fonts, images, books, questions, sounds and CanvasKit are served locally.
- Android XML and iOS plists/entitlements parse. Xcode project parses and contains the monitor extension source/build/dependency/embed wiring.

See `web-smoke.json` for the browser checks and numbered PNGs for screenshots.

## Visual review

Compared applicable reference scenes against welcome, age, PIN, quiz/hint, success, wallet, playtime, and parent screenshots. Kept the actual supplied MiMi, lock, star, book, age and Screen Time illustrations; near-white backgrounds; deep-purple headings; Nunito rounded type; violet gradient buttons; and lavender/mint/peach panels. Corrected the welcome image proportions, removed unsupported text glyphs, preserved full kitten framing, and checked Russian wrapping at 320px.

Adaptations are intentional: reading replaces games; wallet uses MVP conversion values; local-only settings replace subscription/email/Telegram screens; two real books replace concept story content. Reader and library are new screens using the same visual language. Screenshots show the app viewport without the reference's decorative iPhone frame/status bar.

A numeric 90% image-similarity claim is not established: there is no specified comparison metric and the content/flows differ. The saved visual evidence supports a direct review; native rendering remains to be checked on device.

## Independent review and fixes

The independent reviewer found six material interruption/concurrency issues. Fixes:

- Reconcile native receipts after ambiguous activation errors; retain pending debit while status is unavailable.
- Android failed preference commits clear active deadlines before returning an error.
- Track resumed Android activities through UsageEvents, not transient keyboard/notification windows.
- Dismiss native essential-app pickers on background; invalidate every Flutter parent route, including recovery.
- Serialize purchases against pending reading credit and roll back only the failed page credit.
- Persist the iOS transaction ID and expiry together in an atomic app-group receipt file.

Flutter regression tests cover ambiguous native replies, unavailable status, concurrent reading/purchase, recovery-session locking, and preservation of previously earned credit when storage is unavailable. Native fixes are statically reviewed and still require the device matrix.

## Outstanding validation

- `flutter build apk --debug` cannot run: no Android SDK is installed.
- iOS cannot compile/sign here: Linux host has no Xcode or Apple provisioning credentials.
- Actual OS blocking, essential-app exemptions, expiry, revocation, reboot and background behavior await device access. See `docs/NATIVE_SETUP.md`.
- The reviewer did not evaluate binary assets/visual similarity, signing eligibility, or real OS enforcement. Visual review is covered above; the native items remain explicit device gates.
