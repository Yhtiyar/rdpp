# littlewins

An offline Flutter reading app built from `MVP.md` and the supplied `scenes/` references. Children read, answer a question, and earn 10 coins per verified page. 100 coins buys a 15-minute access window.

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

## Included

- Reference artwork, bundled Nunito font with Cyrillic support, animation, confetti, sound and reduced-motion support.
- Parent onboarding, age group, confirmed six-digit PIN, private recovery code, and persisted retry cooldown.
- English and Russian interfaces; English book content/questions stay English in Russian UI.
- Both supplied books for every age: 13 text-bearing pages of **The Frog Prince**, 9 pages of **Колобок**. Original illustrations and source PDFs are bundled. Illustration-only PDF pages accompany text pages and do not generate extra rewards.
- Reader with saved position, completion percentage, contents, backwards navigation, adjustable text and illustration zoom.
- One source-grounded, pregenerated question and hint per reading page. Repeated answers do not award duplicate coins. Credits are once per distinct page in this MVP; both books together can earn 220 coins.
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

The browser test earns ten pages through the UI, purchases time, reloads, tests the parent gate and languages, and saves screenshots/report in `docs/verification/`. Override `APP_URL` or `PLAYWRIGHT_MODULE` if needed. It aborts external runtime requests and fails if any occur.

See [the implementation plan](docs/superpowers/plans/2026-09-25-littlewins.md), [verification report](docs/verification/REPORT.md), and [native setup](docs/NATIVE_SETUP.md).

## Content

`tools/prepare_books.py` regenerates the bundled reading content from `books/` using Poppler and Pillow. `tools/prepare_art.py` extracts supplied illustration assets and generates local sound effects. `assets/fonts/OFL.txt` contains the font license. Book credit screens retain source attribution; original PDFs retain their full notices. The Frog Prince source is non-commercial and includes Creative Commons attribution/share-alike notices; review the original source terms before distribution. No content is fetched at runtime.
