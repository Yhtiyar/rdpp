# Illustrated icons — 2026-09-28

Integrated the five user-supplied 3D illustrations from `assets/art/new-generated/`.
MiMi's artwork and animation are unchanged by this update.

| Illustration | Used in |
| --- | --- |
| Home | Home navigation |
| Book | Books navigation, reading buttons, first milestone, welcome screen |
| Coin | Header balance, home savings, wallet, progress, reward particles, welcome screen |
| Trophy | My wins navigation and story superstar milestone |
| Lock | Parent access button, PIN entry and PIN setup |

Navigation has a short selection spring. Unreached milestones are desaturated;
earned milestones retain their full color. Existing accessible labels and the
app's reduced-motion policy apply to the illustrations. Listening story stars
remain distinct from spendable reading coins.

The source PNGs remain intact. Only the production WebPs are bundled, in
`assets/art/icons/`: five 512×512 images, 114,018 bytes total, with transparency.
Headphones and growth were not supplied and retain their existing artwork.

To rebuild the production images with ImageMagick:

```sh
mkdir -p assets/art/icons
for name in home book coin trophy lock; do
  convert "assets/art/new-generated/$name.png" -resize 512x512 \
    -define webp:alpha-quality=100 -quality 92 "assets/art/icons/$name.webp"
done
```

## Verification

- `flutter analyze`: no issues.
- `flutter test`: all 90 tests passed.
- `flutter build web --release --no-web-resources-cdn --no-wasm-dry-run`: passed.
- `APP_URL=http://127.0.0.1:7373 node tools/icon_web_check.cjs`: see
  [browser check results](after/checks.json).
- Screenshots inspected at 320px, 430px, and 1365px widths, including Russian
  home and milestone layouts, parent PIN entry, wallet and onboarding.
- All five production assets loaded. No browser errors or layout overflows.
- Reduced-motion progress stays still. Normal selection has intermediate
  animation frames and then settles. Navigation preserves reading progress.

The browser script uses direct CDP captures for the brief navigation spring:
Playwright's screenshot synchronization initially took longer than the 550ms
animation in the software renderer and captured only the settled state.

| Screen | Before | After |
| --- | --- | --- |
| Home | [Before](before/home-430.png) | [After](after/home-430.png) |
| Milestones | [Before](before/wins-430.png) | [After](after/wins-430.png) |
| Wallet | [Before](before/wallet-430.png) | [After](after/wallet-430.png) |
| Parent access | [Before](before/parent-lock-430.png) | [After](after/parent-lock-430.png) |
| Welcome | [Before](before/welcome-430.png) | [After](after/welcome-430.png) |

Additional evidence: [320px Russian milestones](after/milestones-ru-320.png),
[desktop home](after/home-1365.png), [navigation during selection](after/navigation-frame-0.png),
[navigation settled](after/navigation-settled.png).
