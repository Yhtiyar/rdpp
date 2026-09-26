# Emotional design update — delivered 2026-09-26

All five tasks in `upd_plan.md` are implemented. Open [the visual review](review.html) for before/after comparisons, the [complete walkthrough](walkthrough.webm), and the [reward motion recording](reward-motion.webm).

## What changed

- Neutral selected answers; saved correct/wrong/exhausted feedback with one live announcement, grounded explanations, logical keyboard focus, and an always-reachable next action.
- Six bundled MiMi poses plus blink frames, brief expression/paw sequences, quiet home blinking, and static reduced-motion states. All 32 explanations were checked against the actual reading sections.
- Committed rewards with a decorative count-up, truthful saved balance, milestone selection, and book-cover keepsakes. Wallet guidance accounts for balance, allowance, protection, pending purchases, and finite earning capacity.
- Persisted last-opened story, interrupted-reading recovery, supportive first-use My wins, honest completion/rereading copy, read-section markers, and verified-book progress. Tests still launch only on the child's action.
- Five distinct optional bundled sound cues, shared motion durations, quiet page/tab transitions, reduced-motion support, and hidden-app effect/audio handling.

## Verification

- `flutter analyze`: no issues.
- `flutter test`: **57 passed**.
- `flutter build web --no-web-resources-cdn`: passed.
- `tools/web_smoke.cjs`: **30 checks passed**, 13 English pages completed, with **no browser errors or external runtime requests**. Viewports: 320×640, 430×932, 1365×900.
- `tools/feedback_web_checks.cjs`: **6 targeted checks passed**: 21/22-page finite-catalog states, browser-blocked audio, exhausted allowance, recorded/profiled reward, and reduced-motion home sampled beyond the idle-blink interval.
- Widget checks additionally cover Russian feedback at 200% text scaling, keyboard activation, failed/delayed saves, rapid taps, leaving/rebuilding rewards, timer expiry, legacy preferences, and short-to-long reader transitions.
- One independent code review; every reported issue was fixed and covered by a regression test. See [review resolutions](code-review.md).

The recording was inspected as a sequence using [extracted frames](reward-filmstrip.png), not just a final screenshot. It shows the paw/blink reaction, the decorative 90→120 balance count, and confetti settling while both actions stay available.

## Measured limits

The profiled reward sequence on this software-rendered headless Chromium host, with video recording and deliberately blocked audio, had **16.7ms median / 66.7ms p95** browser frame intervals; **8 of 79** intervals exceeded 33.4ms. CDP recorded 31 DrawFrame events. This did **not** establish consistent 60fps. These are browser cadence measurements, not Flutter raster timings or physical-device benchmarks. Raw summary: [reward-profile.json](reward-profile.json).

No MobAI or native-device tests were used. Physical-device performance, perceived sound quality/loudness, haptics, and the proposed parent-supervised child usability review remain unmeasured.

## Implementation decisions

1. Used the existing feature checkout because the plan depended on substantial uncommitted batch work. The original dirty baseline was preserved in local `.implementation/emotional/`. Cost: task commits incorporate prerequisite batch changes and are not standalone against the older MVP.
2. Staged only task files and relevant batch prerequisites. Shared quiz/sound integration landed with the reward task; independent assets landed first. Icon, signing, CI, and other unrelated changes remain untouched.
3. Regraded the expired-timer heading finding as important and fixed it: a child should not see “ready” after the confirmed time window ends.
4. Kept native protection, haptics, perceived audio, and unrelated baseline work outside this update, as specified. Cost: this delivery cannot establish native experience quality.
5. Completed the browser evidence that the reviewer deferred while it was being collected; no code-review findings remain deferred. Preserved the existing before screenshots; the new walkthrough records the implemented behavior.

Assets: [production notes and exact image prompt](asset-notes.md). The sound-generation script is reproducible and offline; there are no new runtime dependencies.
