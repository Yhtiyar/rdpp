# littlewins

An offline Flutter reading app built from `MVP.md` and the supplied `scenes/` references. Children read three pages, answer a four-question quiz, and earn 10 coins per verified page after passing the whole batch. 100 coins buys a 15-minute access window.

## Run the web preview

```sh
flutter pub get
flutter run -d web-server --web-hostname=0.0.0.0 --web-port=7357
```

For the release build used for UI verification:

```sh
flutter build web --no-web-resources-cdn
python3 -m http.server 7357 --directory build/web
```

Open http://localhost:7357. Web purchases are explicitly labelled previews: a browser cannot restrict other apps. There are no seeded coins or default parent PINs; set up a profile and read to earn coins.

## Build an iPhone preview without Screen Time

For a release build that runs without a connected PC, use
`./build.sh --release --withoutSC`, then install and sign the resulting IPA
through MobAI. Use `./build.sh --release` to keep Screen Time in the build.
Release builds do not support hot reload; free Apple ID signing still expires
after seven days.

```sh
./build.sh --withoutSC
# Equivalent: builder ios build --profile preview --unsigned
builder dev flutter --ipa dist/<new-build>.ipa
```

Choose **Yes** at **Resign app** for this unsigned preview and use your free
Apple ID. This path does not need an App Store Connect API key or the
`DEVELOPMENT` signing secrets. Reading, quizzes, coins, parent controls and
simulated reward timers remain available; **other apps are not blocked**.

The preview profile sets `LITTLEWINS_WITHOUT_SC=1`. A CI step removes the
ScreenTimeMonitor build dependency and embedded extension, clears the restricted
entitlements, and compiles a preview service instead of the Screen Time code.
Your local Xcode project stays configured for the full app. `./build.sh` without
the flag retains the normal unsigned build with Screen Time; the paid-account
`development` profile remains available separately.

**One-time setup:** push the updated `.github/workflows/ios-build.yml` to your
GitHub default branch before using the flag. Builder dispatches that workflow
from the default branch even when it builds a working-tree snapshot. Use the
new IPA explicitly; older `-signed.ipa` files still contain the previous build.

Pushing only `feature/littlewins-mvp` does **not** update the workflow on `main`.
Merge that branch into `main` and push `main` first. The CI run must include
**Configure preview without Screen Time** and **Verify preview IPA has no
Screen Time extension**. CI checks the packaged IPA before uploading it. You
can also check a downloaded file locally before installation:

```sh
python3 tools/verify_preview_ipa.py dist/<new-build>.ipa
```

## Included

- Reference artwork, bundled Nunito font with Cyrillic support, animation, confetti, sound and reduced-motion support.
- Parent onboarding, age group, confirmed six-digit PIN, private recovery code, and persisted retry cooldown.
- English and Russian interfaces; English book content/questions stay English in Russian UI.
- Eighteen books for every age: eleven English and seven Russian titles, with 164 reading pages. The ten fables have individual shelf entries. Original illustrations and source PDFs are bundled; text-only books have new story artwork.
- Reader with saved position, completion percentage, contents, backwards navigation, adjustable text and illustration zoom.
- Four source-grounded, prepared questions after each three-page batch (including a final shorter batch), with four answer options each. Children press **Start test** when ready; unfinished quizzes resume only through **Continue test**. Two attempts per question; three errors reset the current batch and require rereading. Attempts survive closing or restarting. All questions must be passed before credit; exhausted quizzes require rereading. Earlier rewards are preserved and repeated answers do not award duplicate coins. Each completed reading page earns 10 coins.
- Wallet, daily allowance, elapsed access windows, transaction recovery, reading streak and milestones.
- PIN-gated parent settings, language, sounds, daily allowance and essential app selection.
- Native Android/iOS restriction implementations; **native compilation, signing and device behavior are not yet verified**.

All state stays in local preferences. Uninstalling the app or clearing browser storage removes the local profile. There is no account, backend, advertising, subscription, remote report or game.

## Verify

```sh
flutter analyze
flutter test
flutter build web --no-web-resources-cdn
npm install --prefix /tmp/littlewins-browser playwright
# In another terminal, serve build/web on port 7357 first.
node tools/web_smoke.cjs
```

The browser test verifies button-started batch quizzes, attempts across reloads, three-error resets, rereading gates, all 13 English pages, purchases, the parent gate and languages, and saves screenshots/report in `docs/verification/`. Override `APP_URL`, `PLAYWRIGHT_MODULE` or `SMOKE_OUTPUT_DIR` if needed. It aborts external runtime requests and fails if any occur. See the [batch quiz verification](docs/verification/batch-quizzes/REPORT.md) for the latest results.

See [the implementation plan](docs/superpowers/plans/2026-09-25-littlewins.md), [verification report](docs/verification/REPORT.md), and [native setup](docs/NATIVE_SETUP.md).

## Content

`tools/prepare_books.py` regenerates the bundled reading content from `books/` using Poppler and Pillow. `tools/prepare_art.py` extracts supplied illustration assets. `tools/prepare_feedback_sounds.py` generates the bundled sounds offline with Python and NumPy. `assets/fonts/OFL.txt` contains the font license. Book credit screens retain source attribution; original PDFs retain their full notices. The Frog Prince source is non-commercial and includes Creative Commons attribution/share-alike notices; review the original source terms before distribution. No content is fetched at runtime.

## Listening editions

Choose **Listen & play** on Home or in the Library for all eighteen complete stories, split into 258 narration parts with 179 picture questions. Narration preserves the supplied story text and omits structural labels such as chapter numbers. Russian uses Gemini/Sulafat at its natural pace; English uses Qwen/longanlingxin at 0.85×. Each book owns its illustrations and audio under `assets/books/<id>/`. Audio is bundled; the app does not need an OpenRouter key at runtime. Listening progress and story stars are separate from reading coins.

See [toddlerbooks.md](toddlerbooks.md) for the content workflow and [verification](docs/verification/new-books/README.md) for browser and audio checks.
