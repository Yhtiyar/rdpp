# Littlewins implementation ledger
Plan: docs/superpowers/plans/2026-09-25-littlewins.md

- Baseline: Flutter starter test passed.
- Work on feature/littlewins-mvp in the supplied workspace to preserve supplied untracked assets. No MobAI calls.
- Ruling: proceed continuously under the explicit request to plan and accomplish the MVP. Flutter web replaces device UI checks until access is supplied.
- Task 1: PIN hash, recovery and persisted cooldown tests pass; welcome → age browser flow passes, screenshots saved. Corrected welcome illustration ratio after comparing the reference.
- Task 2: both stories extracted with illustrations and source PDFs. Content tests pass: 13 English and 9 Russian text pages, with one bundled question each. Reader implemented; browser full flow under validation.
- Task 3: duplicate and cross-book reward accounting tests pass. Rewards red command overlapped file creation and saw green; do not count this as a verified red/green cycle.
- Ruling: source PDF illustration-only pages are paired with text pages and do not earn separate coins. Source page numbers retained.
- Ruling: PIN local hash is salted and iterated SHA-256; device storage itself is not a tamper-resistant child-device boundary. Native authorization provides the OS boundary.
- Tasks 2–4: full browser flow passed; ten actual UI quiz completions earn 100 coins; 15-minute preview spends 100; reload preserves countdown. Wrong-answer hint and next-page resume verified.
- Task 5: parent PIN, language, sounds, daily limits, native selection bridges and restriction implementations added. Android build attempted and blocked by absent SDK; iOS Xcode unavailable on Linux. XML/plist/Xcode-project syntax checks pass. Native enforcement remains a device-validation gate.
- Independent review: six material findings fixed. Ambiguous-reply and unavailable-status tests observed failing then passing. Recovery lifecycle test observed failing; correct return-to-foreground assertion now passes. Concurrent reading/purchase guarded and reward rollback narrowed. Native persistence/picker/foreground changes require the documented device matrix.
- Final rulings on reviewer exclusions: screenshot/style review performed in Chromium; small viewports tested at 320px and desktop. Binary book assets validated against supplied sources; source terms retained. Signing eligibility and actual OS enforcement cannot be established here and remain explicitly deferred to device/toolchain access.
- No merge, push, publication, or MobAI/device interaction performed. Work remains reviewable in the shared workspace on feature/littlewins-mvp.

- Additional final regression: duplicate quiz completion during unavailable storage now returns the existing result without a new write or removal of previously earned credit (observed RED → GREEN). Final Flutter suite: 18 tests pass; analyzer clean.
- Native status now requires both explicit enabled state and system permission; Android stops relying on stale foreground state if usage access is revoked. Native static fixes remain uncompiled in this environment.
- Final verification completed: `flutter analyze` clean; `flutter test` 18/18; `flutter build web --no-web-resources-cdn` successful; final `node tools/web_smoke.cjs` passed all 15 listed checks, no browser errors or external runtime requests. Preview remains served on port 7357.
