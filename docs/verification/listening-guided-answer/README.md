# Guided answer accepts the first tap

After two wrong answers, the correct picture turned green while a guidance
clip asked the child to tap it. Both choices nevertheless stayed disabled
until the entire clip ended. The guidance itself included positive feedback,
so an ignored early tap sounded accepted; only a later tap recorded the answer
and advanced.

The highlighted correct choice now accepts a tap while guidance is loading,
speaking or paused. Choosing it cancels guidance, records assisted success,
plays feedback once, and advances after that feedback ends. Other choices keep
the existing speech gate. Feedback still blocks repeated taps, and stale
completion events from interrupted guidance cannot advance another question.

## Evidence

- `before.json` and `kolobok-before.png`: reproduced on the previous release
  web build using a physical touch at 40% of the guided clip. The answer stayed
  unrecorded and the same question remained after speech finished.
- `checks.json`: the same test passes on Колобок and The Frog Prince at
  320×568, with actual bundled audio. One early tap is accepted, interrupted
  guidance stops, exactly one feedback clip ends, and the next question opens.
  A repeated tap during feedback does not replay it or skip a question.
- `*-accepted.png`: immediate correct-answer state, visually inspected.
- Unit and widget regressions failed with `Expected: feedback; Actual: guided`
  before the fix, and pass after it. They also cover a delayed old completion
  callback and duplicate taps.
- All 88 Flutter tests pass; `flutter analyze --no-pub` reports no issues;
  the release web build succeeds. No MobAI or native-device testing was used.

```sh
flutter test --no-pub
flutter analyze --no-pub
flutter build web --no-web-resources-cdn --no-pub
# Serve build/web on port 7359 in a separate terminal.
APP_URL=http://127.0.0.1:7359 node tools/listening_guided_answer_web_check.cjs
```

The browser regression seeds a heard first checkpoint to focus on answering,
then uses real hint, guidance and feedback clips. Hints and feedback run at 4×;
guidance runs at 1× so the early-tap timing is observable. `BOOK_IDS` can narrow
the default `kolobok,frog` selection.
