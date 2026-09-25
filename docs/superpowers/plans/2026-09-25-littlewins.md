# Littlewins Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement task by task. The user requested planning and completion in this session.

**Goal:** Ship a local reading/rewards MVP matching the supplied scenes, ready for final device validation.
**Architecture:** Flutter views + ChangeNotifier controller + versioned local repository. Bundled book assets and questions; native screen-time bridges behind a platform service.
**Tech Stack:** Flutter/Dart, SharedPreferences, crypto, audioplayers, Kotlin accessibility/usage APIs, Swift FamilyControls/ManagedSettings/DeviceActivity, Playwright for Flutter web.
**Spec:** `docs/superpowers/specs/2026-09-25-littlewins-design.md`

## Global Constraints
- No MobAI; UI testing uses Flutter web.
- Both supplied books for every age; English questions stay English.
- 10 verified pages = 100 coins; 100 coins = 15 minutes.
- No backend, games, accounts or subscription flows.
- Match supplied artwork, gradients, typography and composition.

## Review Focus
- Duplicate page/quiz submissions must not award twice (Task 3).
- Reload and app background must preserve progress and expiry (Tasks 2/4).
- Failed or concurrent native purchase requests must not lose coins (Task 4).
- Parent access must resist wrong PIN attempts and preserve cooldown on reload (Task 1).
- Small viewports and Russian labels must not overflow (Task 6).

### Task 1: Foundation and onboarding
Files: `lib/app.dart`, `lib/core/`, `lib/features/onboarding/`, `assets/art/`, `assets/fonts/`, `web/`, `test/parent_auth_test.dart`.
Interfaces: `AppController`, `LocalStore`, `AppStrings`, common `WinButton`, `SceneScaffold`, `Art`.
- [x] Extract scene artwork, bundle fonts and sounds, enable web.
- [x] Test PIN validation, confirmation/recovery and cooldown before implementation.
- [x] Implement welcome → age → PIN → screen time setup; bilingual strings and persisted profile.
- [x] Run auth/widget tests and inspect onboarding in Chromium.

### Task 2: Library and reader
Files: `tools/prepare_books.py`, `assets/books/`, `lib/features/reading/`, `test/books_test.dart`.
Interfaces: `Book`, `BookPage`, `BookCatalog.load()`, `AppController.savePosition(bookId, page)`.
- [x] Extract complete text/illustrations and attribution from supplied PDFs.
- [x] Add content integrity tests for both books and valid page/question mappings.
- [x] Implement language tabs, book progress, resume, previous/next, contents, text size and image zoom.
- [x] Verify reader and saved position in Flutter web.

### Task 3: Comprehension and coins
Files: `assets/books/catalog.json`, `lib/core/app_controller.dart`, `lib/features/reading/quiz_screen.dart`, `test/rewards_test.dart`.
Interfaces: `answerPage(bookId, page, answer)` returns awarded coins; `balance`, `completedPages`.
- [x] Author source-grounded questions, choices and hints for every reading page.
- [x] Test wrong answers, duplicate credits and cross-book 10-page/100-coin accounting.
- [x] Implement quiz, hints, success animation/sound, home and achievements.
- [x] Verify wrong/right answers and rewards in Flutter web.

### Task 4: Wallet and time
Files: `lib/features/rewards/`, `lib/core/screen_time_service.dart`, `test/screen_time_test.dart`.
Interfaces: `ScreenTimeService.status/authorize/configureEssentials/unlock`, `AppController.redeem(minutes)`.
- [x] Test balance/cap checks, expiry/rollover, failed and concurrent purchases.
- [x] Implement 15/30/45-minute purchase options, confirmation, persisted expiry and honest web preview.
- [x] Validate purchase/reload/expiry UI on web.

### Task 5: Parent controls and native restrictions
Files: `lib/features/parent/`, `android/app/src/main/`, `ios/Runner/`, `ios/ScreenTimeMonitor/`, Xcode project.
Interfaces: MethodChannel `littlewins/screen_time`, platform status map and native persisted expiry.
- [x] Implement PIN-gated overview, daily cap, language, sound, PIN change and essentials.
- [x] Implement Android permission/app selection, accessibility shield and expiration.
- [x] Implement iOS authorization, essentials picker, shields and monitor extension with entitlements.
- [x] Build native targets where toolchain permits; document exact setup/device gates.

### Task 6: End-to-end validation and visual refinement
Files: `tools/web_smoke.cjs`, `docs/verification/`, `README.md`.
- [x] Run full Flutter tests, analyzer and release web build.
- [x] Browser-test onboarding, parent gate, reader, quiz, purchase, locale and persistence at mobile/desktop sizes.
- [x] Capture screenshots and compare against references; correct visible differences.
- [x] Obtain final independent code review, fix material findings and rerun relevant checks.
- [x] Record results and deferred native-device checks; provide run instructions.

## Remaining platform gate

Native code is implemented, but native compilation and on-device enforcement are unverified: Android SDK and Xcode are unavailable here, and device testing is deferred at the user’s request. See `docs/NATIVE_SETUP.md`. The visual comparison is documented with screenshots; no numeric image-similarity metric is claimed.
