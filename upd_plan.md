# littlewins Emotional Design Update Plan

> **For agentic workers:** Implement task by task with `superpowers:executing-plans`, or `superpowers:subagent-driven-development` if the user chooses delegation. Track the checkboxes below. Implemented on 2026-09-26. Verification and measured limitations are recorded in [the delivery report](docs/verification/emotional-update/README.md).

**Goal:** Make littlewins feel like a responsive reading companion that notices effort, celebrates understanding, and helps children recover from mistakes.

**Architecture:** Keep the existing Flutter app, local persistence, reading rules, and visual identity. Add reusable motion and MiMi components, then connect their reactions to successfully saved reading/quiz/reward outcomes. Animation presents state; it must never grant coins, consume attempts, start a timer, or navigate by itself.

**Tech stack:** Flutter/Dart, built-in animation widgets/controllers, existing `audioplayers`, bundled artwork/audio, local preferences. No new runtime dependency is required for the first delivery.

**Spec:** [emotional-design.md](emotional-design.md), [MVP.md](MVP.md), and the latest user decisions: three-page batches, four prepared questions, four options, two attempts total, reset only the current batch after three errors, and child-initiated tests.

## Recommendation

The visual foundation is already strong: MiMi, Nunito, the purple palette, book illustrations, and soft surfaces belong together. The main gap is **responsiveness to what the child just did**. The same smile, encouragement, and motion recur across very different situations.

Prioritize **clear answer feedback → expressive MiMi → meaningful reward delivery → remembered progress**. More floating objects or confetti on every action would make the app busier without solving that gap.

The distinctive moment should be: **“I understood the story; MiMi noticed; I can see exactly what I earned.”** A short, coordinated batch-completion sequence can become the moment children want to show a parent. That is a design hypothesis to validate, not a claim that animation alone creates word of mouth.

## Browser review and evidence

Reviewed the current Flutter web build on 2026-09-26 in Chromium at 430×932, with additional 320×640 and 1365×900 checks. Used a fresh local profile and actually navigated onboarding, home, library, reading, selected/correct/wrong/exhausted answers, third-error reset, rereading, batch rewards, My wins, the wallet, purchase preview, parent settings, and Russian UI with English questions. Completed all 13 English pages.

The [20 browser checks passed](docs/verification/emotional-review/browser-review.json); no browser errors or external runtime requests occurred. The [capture timeline](docs/verification/emotional-review/audit-timeline.json) records the reviewed states and sound-asset requests. Correctness of the flow does not establish the quality of its emotional design.

A separate [reduced-motion check](docs/verification/emotional-review/motion-audit.json) confirmed that the welcome artwork changes position normally and remains visually unchanged between sampled frames with `prefers-reduced-motion: reduce`. This verifies the welcome idle effect only, not every animation in the app.

Audio triggers were observed and their code inspected; perceived loudness, pleasantness, and physical-device haptics were not evaluated. No MobAI, native-device testing, or child usability study was performed. Recommendations below are design judgments supported by these observations, not measured child responses.

### What already works and should stay

- MiMi and the existing book artwork give the product a recognizable identity.
- `WinButton` already has a 100 ms press response; answer options transition over 150 ms; onboarding uses a 220 ms transition.
- `FloatArt` has a subtle three-second bob, and batch rewards already have 1.8 seconds of confetti. The issue is not an absence of animation.
- Wrong answers retain a supportive hint; reset copy says earlier coins are safe.
- Tests now start only with **Start test / Continue test**. Keep this control throughout the redesign.
- Coin awards, retries, resets, and purchases already have persistence and concurrency protections. Build on them.

### Findings, impact, and proposed changes

| Priority | Observed gap | Why it matters | Improvement |
|---|---|---|---|
| P0 | An unchecked selected answer already displays a checkmark. [Evidence](docs/verification/emotional-review/24-selected-before-check.png) | Selection can be mistaken for correctness, including when the selected answer is wrong. | Use a neutral selected marker. Reserve a checkmark, success color, and MiMi reaction for a saved correct result. |
| P0 | After earning 120 coins, the result shows “2 of 10 pages” toward the next 100. [Evidence](docs/verification/emotional-review/28-reward-120.png) | A meaningful reward becomes affordable, but the most prominent progress display appears to have fallen backward. | Separate lifetime reading progress from spendable balance. Show “You have enough coins for 15 minutes,” subject to allowance and protection status. |
| P1 | A correct answer keeps the same MiMi face and “Think back to the story” bubble. The extra feedback is a small “Correct! Keep going.” [Evidence](docs/verification/emotional-review/25-correct-answer.png) | The child's success barely changes the scene; the prompt is no longer appropriate. | Give each result a clear visual state, brief character reaction, and specific acknowledgement. |
| P1 | MiMi is usually a static full image that moves as one rectangle. | The character decorates the screen but rarely responds to the child. | Add distinct ready, thinking, encouraging, proud, celebrating, and calm states, with a consistent motion vocabulary. |
| P1 | Exhaustion and reset are explained mainly through rule-heavy text. [Exhaustion](docs/verification/emotional-review/30-exhausted-question.png), [reset](docs/verification/emotional-review/21-batch-reset.png) | The recovery path feels more administrative than supportive. | Let MiMi guide the next action; shorten the main copy while preserving the exact rules and honest consequences. |
| P1 | First-use My wins emphasizes 0 coins, 0 pages, a 0-day streak, and locked milestones. [Evidence](docs/verification/emotional-review/29-first-progress.png) | The child sees what they lack before experiencing a first success. | Give the empty state one achievable invitation: finish the first section with MiMi. Reveal richer statistics after progress exists. |
| P1 | Returning after a successful batch changes numbers, but home keeps its generic greeting and illustration. [Evidence](docs/verification/emotional-review/31-home-after-batch.png) | The app does not visibly remember the effort just made. | Show the actual current story/section and a context-specific welcome; acknowledge today's progress without replaying a celebration. |
| P1 | The wallet offers 45 minutes for 300 coins. [Evidence](docs/verification/emotional-review/33-wallet-options.png) The current two books can award only 220 coins total. | The app presents an unreachable goal under current earning rules. | Hide durations that cannot be reached with current balance plus remaining earnable catalog coins. Keep the underlying conversion unchanged. |
| P2 | Tab content and reading pages largely replace immediately; rewards use the same scene for each batch. | The experience feels assembled from screens rather than like a continuous journey. | Add short directional transitions and reserve stronger reactions for a first batch, milestone, or completed book. |
| P2 | One success sound serves correct answers, batch completion, and purchases; `tap.wav` is bundled but unused. | Different achievements have little audible distinction. | Create a small hierarchy of optional cues. Routine reading and navigation should remain quiet. |

## Design direction

**Visual thesis:** A warm, tactile storybook with a purple kitten who pays attention. Preserve the supplied artwork, gradients, rounded typography, and spacious reading layout; avoid a new visual identity or a grid of extra decorative panels.

**Content hierarchy:** Reading text first in the reader; the question and answer state first in a test; the earned result first on completion. MiMi supports that hierarchy rather than competing with it.

**Interaction thesis:** Immediate, clear response to a choice; a small expressive reaction to an outcome; a larger coordinated celebration for a completed section. Quiet periods between these moments make them noticeable.

### Proposed feedback vocabulary

These are implementation targets, not measurements of the existing app.

| Moment | Character / motion | Copy direction | Sound |
|---|---|---|---|
| First welcome | One brief greeting; occasional blink while visible | “Let’s read our first story.” | None automatically |
| Answer selected | Neutral marker, 140 ms border/fill transition | No correctness claim yet | Silent by default |
| Correct, first attempt | Proud nod/paw lift, about 550 ms; clear success treatment | “You spotted that detail!” + a short explanation grounded in the book | Soft 180–250 ms confirmation |
| Correct after retry | Same success, with acknowledgement of persistence | “You tried again and found it.” | Same confirmation; no lesser reward |
| First wrong answer | Encouraging tilt, about 350 ms; hint panel appears | “Let’s look for a clue. One try left.” | Gentle optional cue; no harsh buzzer |
| Attempts exhausted | Calm/encouraging pose; stable text and action | “Let’s practice the next one. We’ll reread this section before earning coins.” | No repeated error cue while the child reads |
| Third-error reset | MiMi turns toward the book; no destructive shake | “Let’s read this part together again.” Secondary text explains the reset and preserved coins. | Quiet recovery cue |
| Page completed | One of three reading markers fills over 180 ms | “2 of 3 pages read” | None |
| Batch passed | Brief MiMi celebration, earned coins travel to the displayed balance, amount counts up once | “You understood this part of the story.” | One 600–900 ms reward phrase |
| Book finished | Proud bookmark/keepsake scene using that book's cover and MiMi | “You finished The Frog Prince!” | One completion cue instead of stacking several sounds |
| Time purchased | Coin spend resolves into the confirmed timer | “Your time is ready.” Preserve preview wording on web. | One distinct ready cue |

Feedback text and hints must remain readable until the child chooses the next action. Animation never advances a question automatically. A successful first attempt may leave a diagnostic “attempts left” count in state, but replace that counter in the visible result summary with the outcome; it is no longer the information the child needs.

### Signature batch-completion sequence

1. **After the award saves:** show the truthful final reward and balance immediately, including accessible semantics.
2. **0–180 ms:** bring in the outcome heading and MiMi's proud pose.
3. **180–650 ms:** play a short celebration; animate the displayed coin amount from its previous value to its committed value. A few coin/star accents connect the earned amount to the balance within this screen.
4. **650–1100 ms:** settle the balance and show the next useful message: coins still needed, enough coins for time, allowance reached, or book complete.
5. Keep **Keep reading** and **Back to my books** available throughout. Leaving early cancels the visuals without cancelling or repeating the award.

Use confetti for a first batch, a newly crossed milestone, or a completed book. Ordinary batch completion can use the shorter MiMi-and-coins treatment. If several milestones happen together, show one primary celebration with a compact list of what was achieved; do not chain blocking screens.

## Global constraints

- Keep three-page batches and a quiz for the final shorter batch; keep four prepared questions per current batch and at least four options per question.
- Keep two attempts total, persisted errors, current-batch reset after three errors, rereading requirements, and previously earned rewards.
- Start/resume tests only through the child's button press. Never open them because a page fits, reaches its bottom, or is restored.
- Keep 10 coins per newly verified page and 100 coins per 15 minutes. No bonus coins for animations, tapping MiMi, streaks, or repeated reading.
- Keep both books available to every age. Interface copy supports English and Russian; book questions, hints, and any new explanations stay in the book's language.
- Keep reading offline. Bundle all art/audio; no remote animation, personalization service, or analytics backend.
- Use contextual encouragement about effort and understanding. Avoid guilt, threats about streaks, comparisons with other children, and an upset MiMi who pressures the child to continue.
- Honor reduced motion and the existing sound toggle. Meaning must remain visible with sound off and motion disabled.
- Keep text steady while it is being read. No idle mascot animation in the reading text, recurring attention pulses, or motion behind questions.
- Verify UI in Flutter web. Haptics and native rendering remain a later device check when access is authorized.

## Review focus

| Condition | Expected behavior | Owned by |
|---|---|---|
| Wrong selection, delayed/failed save, or fast repeated taps | No premature success, sound, extra attempt, or duplicate credit | Task 1, Task 3 |
| Reload, route change, locale change, or parent settings rebuild | Preserve progress; do not replay rewards or launch a quiz | Task 2, Task 3, Task 4 |
| Balance crosses 100, coins are spent, allowance is exhausted, or catalog is complete | Show an attainable next step without implying unavailable screen time | Task 3, Task 4 |
| 320px viewport, Russian copy, enlarged text, or keyboard navigation | Keep answers, feedback, and the next action reachable and unambiguous | Task 1, Task 5 |
| Reduced motion, muted/blocked audio, or app hidden mid-animation | State remains correct; optional effects stop or simplify without blocking work | Task 2, Task 5 |

## Implementation sequence

### Task 1 — Make quiz feedback unambiguous (P0)

**Files:** Modify `lib/features/reading/quiz_screen.dart` and `lib/ui/components.dart`; create `lib/ui/motion_spec.dart` and `lib/features/reading/quiz_feedback_panel.dart`; add `test/quiz_feedback_test.dart`.

**Interfaces:** `MotionSpec.of(BuildContext context)` returns named durations `press`, `selection`, `transition`, `reaction`, and `reward`, plus `reduceMotion`. Normal values: 90, 140, 220, 550, and 1100 ms; reduced-motion values are zero. `QuizFeedbackPanel` accepts `BatchAnswerOutcome outcome`, `String message`, `String actionLabel`, and `VoidCallback onContinue`. It does not submit answers or alter progress.

- [x] Add failing widget tests: selecting any answer shows a neutral selected marker, not a correctness check; a saved correct answer shows explicit success; failed storage never shows success; rapid taps submit once.
- [x] Run `flutter test test/quiz_feedback_test.dart` and confirm those failures describe the missing behavior.
- [x] Separate option states: neutral, selected, saving, correct, incorrect, and exhausted. Use both icon/text and color. Apply the result only after `answerBatch` succeeds.
- [x] Put result, hint, and next action together. At small heights, keep the action reachable without hiding choices; use a compact feedback area outside the question's scroll region when feedback is active. Account for enlarged text instead of assigning a fixed panel height.
- [x] Stop displaying pre-answer encouragement after success. On the next question, reset selection/feedback and move to the new question's start on the child's action, not on a timer.
- [x] Use one live semantic announcement per result, preserve keyboard focus logically, and keep descriptive option labels.
- [x] Re-run the tests and inspect correct/wrong/exhausted states in Flutter web at 320px and 430px. The child should identify whether they selected an answer or got it right without relying on color.

**Done when:** It is impossible to mistake selection for correctness, and the result remains clear with sound and motion off.

### Task 2 — Give MiMi meaningful character states (P1)

**Files:** Create `lib/ui/mimi_character.dart` and `assets/art/mimi/`; modify `pubspec.yaml`, `lib/features/reading/quiz_screen.dart`, `lib/features/home_screen.dart`, and `lib/ui/components.dart`; add `test/mimi_character_test.dart`. For answer explanations, modify `tools/book_quizzes.json`, `lib/features/reading/book.dart`, and `test/books_test.dart`, then regenerate `assets/books/catalog.json` using `tools/prepare_books.py`.

**Interfaces:** `MiMiMood { ready, thinking, encouraging, proud, celebrating, calm }`; `MiMiCharacter({required MiMiMood mood, required double size, Object? reactionId})`. A new `reactionId` starts one reaction; ordinary rebuilds with the same ID do not restart it. `Question.explanation` is a short, source-grounded string in the book's language.

- [x] Prepare the asset sheet before wiring motion: the six poses above, matching the existing MiMi's fur, proportions, eyes, lighting, and palette. Supply transparent, consistently aligned artwork with room for ears and paws. Check both 64px feedback use and the larger reward scene.
- [x] For actual blinks/paw/ear motion, author aligned layers or short frame sequences, including closed-eye frames. The current flattened WebP crops cannot independently animate a face or paw. Do not substitute stronger whole-image bobbing and call it character animation.
- [x] Build the first version with bundled poses/frames and Flutter transforms/crossfades. Keep the existing static pose as a loading/reduced-motion fallback. Add the new asset directory explicitly to `pubspec.yaml`.
- [x] Add tests before integration: changing outcome gives the matching pose; the same reaction ID does not restart; unmounting disposes animation; reduced motion immediately renders the correct stable state.
- [x] Connect quiz moods to successfully saved outcomes. Use a route-local reaction counter incremented after each accepted result, not a value generated in `build`. No global event bus or persisted animation queue is needed.
- [x] Write and review all 32 explanations against the actual three-page sources. Correct-answer copy can acknowledge a detail or a successful retry; do not praise an answer that has not been checked. Add catalog validation for nonempty explanations.
- [x] Replace the reset/exhaustion copy with the proposed supportive wording. Keep the factual reset explanation, the saved-coins reassurance, and the existing retry rules visible.
- [x] Allow a restrained blink on a visible idle home screen, roughly once every 6–9 seconds. Pause idle work when hidden, off-route, or reduced motion is enabled. Do not run idle effects in the reader or behind answer text.
- [x] Run `flutter test test/mimi_character_test.dart test/quiz_feedback_test.dart test/books_test.dart`; review the six states side by side and in the browser at their real display sizes.

**Done when:** Correctness, encouragement, recovery, and celebration visibly feel different while MiMi remains the same character.

### Task 3 — Make earning and spending feel connected (P0/P1)

**Files:** Create `lib/core/reward_progress.dart` and `lib/features/rewards/reward_celebration.dart`; modify `lib/features/reading/quiz_screen.dart`, `lib/features/rewards/wallet_screen.dart`, `lib/features/rewards/progress_content.dart`, and `lib/ui/celebration.dart`; add `test/reward_progress_test.dart` and `test/reward_celebration_test.dart`.

**Interfaces:** `RewardProgress.fromBalance(int balance)` exposes `int coinsNeeded`, `double fraction`, and `bool affordable` for the next 15-minute window. `RewardCelebration` consumes committed `int coinsEarned`, `int balanceBefore`, `int balanceAfter`, `bool bookCompleted`, and `List<int> newlyReachedMilestones`; it owns only presentation. The existing 1/10/22-page milestone thresholds remain unchanged.

- [x] Add balance tests with literal expectations: 30 → 70 needed / 0.3 fraction / not affordable; 90 → 10 / 0.9 / false; 100 and 120 → 0 / 1.0 / true; after spending 100 from 120 → 80 / 0.2 / false. Never use lifetime pages modulo 10 for spendable progress.
- [x] Add widget tests for a failed award save, double taps, leaving mid-celebration, and rebuilding after a locale change. The displayed and persisted award must agree; no path awards coins twice.
- [x] Replace the ambiguous reward bar with balance-based progress and an explicit affordability message. Label any lifetime reading bar separately. Use existing wallet/protection checks to distinguish enough coins from permission to start time now.
- [x] Implement the 1100 ms completion sequence described above using committed before/after values. Apply values immediately for semantics/reduced motion; the count-up is decorative. Buttons remain actionable.
- [x] Compute newly crossed milestones by comparing total verified pages before and after the award. Announce crossings once in that completion route; reopening My wins shows earned badges without replaying the celebration. A legacy milestone already earned is not a new crossing.
- [x] Give finishing a book a distinct MiMi-and-cover keepsake within the result screen. Show the finished title and earned progress; do not invent bonus rewards or add a sharing/account feature.
- [x] Filter wallet offers using `balance + remainingUncreditedPages * 10` as the maximum reachable amount with the current catalog. With a fresh 220-coin catalog, 300 coins is unreachable. Keep costs, confirmation, daily limits, pending-purchase handling, and web preview labels intact.
- [x] For spending, show the transition only after confirmation succeeds. Do not celebrate a reserved or ambiguous transaction. Avoid replaying the ready sound on every timer tick or reopening the wallet.
- [x] Run the new tests plus `test/reading_controller_test.dart` and `test/purchase_reconciliation_test.dart`; browser-check 90→120 coins, 120→20 after purchase, allowance reached, and the final shorter batch.

**Done when:** A child can tell what they earned, their current balance, and whether time is available; presentation never contradicts the ledger or device state.

### Task 4 — Make the reading journey feel remembered (P1)

**Files:** Modify `lib/core/app_controller.dart`, `lib/features/home_screen.dart`, `lib/features/reading/library_screen.dart`, `lib/features/reading/reader_screen.dart`, and `lib/features/rewards/progress_content.dart`; add `test/home_journey_test.dart` and extend `test/reader_screen_test.dart`.

**Interfaces:** Add persisted nullable `String? lastOpenedBookId` and `Future<void> rememberBook(String bookId)` to `AppController`. Missing legacy data falls back to an unfinished book in the interface language, then another unfinished book, then a completed book for rereading. Saving the remembered book must not change read markers, attempts, or credit.

- [x] Add tests for first use, reopening an English book under Russian UI, interrupted reading before the first award, completed books, and loading old preferences without the new field.
- [x] Use the actual remembered story for the primary home action. Personalization starts with remembered work, not a new name-entry form or account.
- [x] Give home three useful states: first section invitation; unfinished story with current section; today's achievement acknowledged with a calm next step. If the child returns after a missed day, welcome them without loss language.
- [x] In the reader, show three compact section markers driven by existing `readPages`, with an accurate count for a shorter final batch. Distinguish “read” from “verified”; keep the book percentage tied to verified pages. Fill markers quietly, with no sounds or coin animation.
- [x] Use a short fade/directional page transition after Next/Previous. Keep the text stable after settling, reset scroll appropriately, and prevent an outgoing page's metrics from marking the incoming page read. Test a short page followed by a long one.
- [x] Preserve **Start test / Continue test** on every path, including restoring a ready batch, changing text size, navigating contents, and closing a test. No animation callback can call `_quiz`.
- [x] Replace the zero-heavy My wins empty state with an invitation and first achievable milestone. After progress exists, retain the useful calendar and earned badges; show new achievements clearly without a mandatory modal.
- [x] Handle the finite catalog honestly: after both books are verified, celebrate completion and offer rereading for enjoyment, explicitly without duplicate coins. Do not keep promising a fresh daily earning target when no uncredited pages remain.
- [x] Run `flutter test test/home_journey_test.dart test/reader_screen_test.dart test/reading_controller_test.dart`; verify remembered progress across browser reloads and language changes.

**Done when:** The app acknowledges what this child has done and offers a real next step without pretending to have unlimited content or changing earning rules.

### Task 5 — Finish the sound, transitions, and accessibility pass (P1/P2)

**Files:** Modify `lib/core/sound_service.dart`, `assets/sounds/`, `lib/ui/motion_spec.dart`, `lib/ui/components.dart`, `lib/features/app_shell.dart`, `lib/features/onboarding/onboarding_screen.dart`, and `tools/web_smoke.cjs`; add `test/feedback_accessibility_test.dart`. Reuse the components introduced above rather than adding per-screen animation systems.

**Interfaces:** Add `FeedbackCue { correct, retry, batchComplete, milestone, timeReady }` and `SoundService.playCue(FeedbackCue cue, {required bool enabled})`. Call it from accepted outcomes, not widget builds. Keep the existing silent-failure behavior when audio is blocked.

- [x] Author/trim distinct, bundled cues following the feedback table. Avoid simultaneous milestone, batch, and purchase sounds; choose the most meaningful event. A page turn, tab change, and idle MiMi remain silent by default.
- [x] Test muted audio, browser-blocked audio, repeated taps, and failed saves: no sound is necessary to understand or complete the flow, and no success cue precedes a saved success.
- [x] Apply the shared motion policy to buttons, answer states, character effects, confetti, onboarding, page transitions, and tab changes. Reduced motion removes translation/scale/particles while preserving immediate state changes.
- [x] Add restrained 180–220 ms tab/onboarding transitions. Preserve scroll/focus and keep one primary action visible. Do not add a second animation that competes with the existing navigation indicator.
- [x] Make the parent-to-child handoff warmer: one MiMi greeting and a clear first-story action after setup, without lengthening PIN/protection setup or obscuring preview limitations.
- [x] Verify screen-reader result announcements occur once, keyboard focus reaches the next action, and 200% text scaling plus Russian labels do not clip feedback. Pressed/loading/disabled controls must not advertise an action that cannot run.
- [x] Extend the web checks to capture selection-before-submit, correct feedback, recovery, reward delivery at several timestamps, a new milestone, mute, reduced motion, and manual test launch. Test 320×640, 430×932, and 1365×900.
- [x] Run `flutter analyze`, `flutter test`, `flutter build web --no-web-resources-cdn`, then serve the build and run `tools/web_smoke.cjs`. Inspect a recording, not only final screenshots. On a profiled web run, target smooth 60 fps for the simple effects; report measured frame behavior rather than assuming it. Physical-device performance, audio quality, and haptics remain separate checks.

**Done when:** The experience is coherent in motion and in silence, with no loss of readability, access, responsiveness, or correctness.

## Delivery and acceptance

Ship Tasks 1–3 first: they change the highest-value moments—choosing, understanding, and earning. Then complete Task 4 and the final polish in Task 5. Integrate sound/reduced-motion protections while each effect is built; do not defer those fundamentals until the end.

Use one focused commit per completed task during implementation. Stage only that task's files; this workspace also contains unrelated icon, CI, and signing work.

Before calling the update successful:

- [x] A selected wrong answer never looks validated.
- [x] A correct answer, retry, reset, batch win, and book completion each receive an appropriate response.
- [x] MiMi visibly reacts to an outcome rather than merely floating as a static picture.
- [x] The 100-coin threshold feels like an achievement; spending updates the same balance story.
- [x] No effect automatically launches a quiz, consumes attempts, changes rewards, or delays a child's next action.
- [x] Reduced motion and mute retain all information; English/Russian and small screens remain readable.
- [x] The recorded before/after walkthrough demonstrates improvement at the same moments, with no new browser errors or external asset requests.

For the “people want to talk about it” goal, do a small, parent-supervised prototype review after implementation. Observe whether children can distinguish selected/correct answers, understand the next reward, recover without adult explanation, and voluntarily point out a favorite moment. Ask parents what felt memorable or repetitive. These observations—not more animation count, time-in-app targets, or a claimed similarity percentage—should guide the next iteration.

**Out of scope for this update:** new games, social feeds, leaderboards, push reminders, accounts/backend, automatic quiz launch, altered coin economics, and new native Screen Time work.
