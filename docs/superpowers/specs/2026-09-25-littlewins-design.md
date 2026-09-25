# Littlewins MVP design

Authority: `MVP.md`, supplied `scenes/` artwork, and instruction to implement the plan using Flutter web for UI testing. No MobAI until the user grants access at the end.

## Outcome
A local-only reading app for children. Parents set up an age group, PIN, daily screen-time limit, and essential apps. Children read the two supplied books, answer bundled comprehension questions, earn coins, and exchange 100 coins for 15 minutes. No games, backend, subscriptions, email reports, or accounts.

## Visual and interaction design
Match the supplied scenes: near-white canvas, ink purple headings, rounded bold typography, purple gradient primary buttons, lavender/mint/peach surfaces, and the actual MiMi artwork. Extract illustrations from the references; never use screenshots as interactive screens. Use responsive phone-width composition, scrollable small screens, gentle MiMi floating, button compression, page transitions and reward confetti. Bundle sounds and Cyrillic-capable fonts for offline use. Reduced-motion and sound preferences are respected.

## Architecture
Flutter views consume a ChangeNotifier controller; a local repository persists a versioned snapshot. Reading content is bundled JSON with original illustrations extracted from the two PDFs. Platform services isolate sound and native screen-time MethodChannels. No network is needed at runtime.

## Reading and rewards
Preserve source text, illustrations and attribution. English books/questions remain English in Russian UI; library has Russian and English tabs. Both books available for every age. Reader saves page immediately, allows backwards navigation, table of contents, text-size adjustment, illustration zoom and a separate completion percentage. Only text-bearing source pages earn credit. A completed page requires reaching its bottom and answering its supplied question correctly. Wrong answers give a hint and allow retry. Each distinct page awards 10 coins once; rereading cannot farm coins. Progress across books accumulates. A short book's remainder carries across books, so 10 verified pages always earns 100 coins.

## Parent and time controls
Six-digit PIN is salted and hashed; confirmation on setup, retry cooldown, no embedded bypass. Local recovery code generated on setup and shown once; recovery is PIN-protected after setup. Parent gate covers settings, essentials, language, daily cap and PIN changes. Purchases require sufficient balance, remaining daily allowance and native authorization (web explicitly previews). Purchases are persisted with absolute expiry and serialized; errors do not consume coins. Time is an elapsed access window, including time away from Littlewins. UI uses expiry rather than a decrementing saved counter. Daily totals keyed by local date.

Android: explicit usage-access and accessibility permissions, app picker with essential apps exempted, AccessibilityService routes blocked launches to a shield, monotonic native deadlines and expiry checks. System/emergency and launcher flows remain available. User-visible limitations: ordinary Android permissions may be revoked; this is not device-owner kiosk enforcement.

iOS: FamilyControls authorization and FamilyActivityPicker for essential applications, ManagedSettings all-category shields except essentials, shared app-group state, DeviceActivityMonitor extension to reapply shields at expiry. Actual signing, Family Sharing authorization, system exclusions and relaunch/expiry behavior require device validation. Never report native protection active on web or when permissions are absent.

## Validation
Unit tests cover unique credits, progress, persistence, insufficient balance, daily caps, purchase races/failures, rollover/expiry and PIN protection. Widget/browser tests cover full onboarding, reading, wrong/right answers, rewards, Russian UI/English content, settings and reload. Flutter web screenshots are compared with scenes at phone dimensions. Native build checks run where SDKs are available; device checks are deferred by explicit user instruction. Visual similarity is assessed and differences recorded; no invented numeric score.
