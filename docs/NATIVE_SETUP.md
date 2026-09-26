# Native screen-time setup and final device checks

No MobAI calls were made. Device checks are deferred under the user's instruction. The current Linux environment has no Android SDK or Xcode; native implementation is statically reviewed, not build- or device-verified.

## iOS

For a free Apple ID, use `./build.sh --withoutSC` and re-sign the resulting
unsigned IPA on install. This preview removes the ScreenTimeMonitor extension
and restricted entitlements in the remote checkout, and uses simulated reward
timers without app blocking. Push the updated iOS build workflow to the default
branch once first. See [preview build instructions](../README.md#build-an-iphone-preview-without-screen-time).
The requirements below apply to the full Screen Time build.

- Minimum iOS 16; use a child Apple ID in Family Sharing. The bridge requests `.child` authorization, not weaker individual/self-control authorization.
- Open `ios/Runner.xcworkspace` in Xcode on macOS. Select your development team for **Runner** and **ScreenTimeMonitor**.
- Replace the sample bundle identifiers `com.example.readapp` and `com.example.readapp.ScreenTimeMonitor` with identifiers registered to your team.
- Set `LITTLEWINS_APP_GROUP` consistently for both targets to your registered App Group. The default is `group.com.example.readapp`. Both entitlement files and Info.plists use this build setting.
- Enable Family Controls and App Groups for both targets. Distribution requires Apple's Family Controls approval for the app and extension: https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement
- The Xcode project already contains extension build phases, the Runner dependency, embedded `.appex`, shared protection source, and separate entitlements.
- The parent connects Screen Time, then picks **individual** essential apps/sites. All category shields are applied except those tokens. iOS determines unrestrictable system apps.
- Purchases schedule a DeviceActivity interval before lifting shields. An atomic shared receipt binds expiry to the transaction. The monitor extension reapplies shields at the interval end; the app also reconciles on foreground. Automatic date/time is required while protection is enabled.
- The app promises an **elapsed access window**, including time spent outside Littlewins, not a per-app active-use stopwatch. The default 15-minute purchase meets Apple's minimum monitoring interval.

### Device installation: extension bundle-ID mismatch

The local `readapp-a808a39b.ipa` contains a consistent pair:
`com.example.readapp` and `com.example.readapp.ScreenTimeMonitor`.
In `readapp-a808a39b-signed.ipa`, re-signing changed only the app to
`com.example.readapp.9726U234MP`. iOS rejects the extension because its ID
does not start with the installed app's ID followed by a dot. This failure
occurs after the Xcode build, during re-signing/installation.

For device builds with Screen Time, use development signing for both targets.
`builder.json` declares the extension and a `development` profile; selecting
that profile lets the existing CI workflow sign each target with its own
provisioning profile. Register your app/extension IDs and shared App Group
first, update the sample IDs in Xcode and `builder.json` together, and create
development profiles containing Family Controls and the shared App Group.
Both profiles must cover the test device and use the same development certificate.

With those files available, run (replace paths with your local files):

```bash
builder signing setup --name development \
  --certificate /path/to/development.p12 \
  --profile /path/to/Runner.mobileprovision \
  --extension-profile /path/to/ScreenTimeMonitor.mobileprovision
builder ios build --profile development
builder dev flutter --ipa dist/<new-build>.ipa
```

Choose **No** at the **Resign app** prompt for this already signed IPA.
The current `build.sh` explicitly builds unsigned; use the signed build command
above for this path. Pass the new IPA explicitly so an older `-signed.ipa`
artifact is not selected. Once it is installed, subsequent hot-reload sessions
can use `builder dev flutter --skip-install --bundle-id <registered-app-id>`.

Do not edit the signed IPA's plist: that invalidates its signature. A re-signer
that changes the app ID must also update and sign embedded extensions with
matching IDs and provisioning profiles. Renaming the extension alone does not
provide its required Screen Time entitlements. This setup has not been
installed or tested on a device in this workspace.

Reference: [Builder v0.11.0 signing and extension configuration](https://github.com/MobAI-App/ios-builder/blob/v0.11.0/README.md#code-signing).

## Android

- Install/configure an Android SDK, then run `flutter build apk --debug`.
- Parent settings explain the data access before opening Usage Access and Accessibility settings. The parent must enable both permissions. Return through the parent PIN gate to finish each step.
- Accessibility receives window-state events without retrieving screen contents. UsageEvents identifies resumed activities so keyboard/notification windows do not replace the protected foreground app.
- A native accessibility overlay shields non-essential apps. Expiration is checked while the app remains in use, independent of Flutter. Deadlines use elapsed realtime and fail closed after reboot.
- The native picker lists launchable apps. Dialer, launcher, settings, system/emergency UI and the active keyboard are kept available; parents can add essentials.
- Native essentials dialogs close on backgrounding. Flutter parent routes, including recovery/PIN change, invalidate on hidden/paused lifecycle states.
- This is user-authorized parental-control enforcement, not device-owner/kiosk mode: system permissions can be revoked, data cleared or the app uninstalled. OEM behavior, battery management and distribution permission policies require device/release review.

## Required final device matrix

1. Fresh onboarding, confirmed PIN, recovery code, wrong-PIN cooldown and restart during cooldown.
2. Screen Time authorization denied, approved and revoked; incomplete setup never claims active protection.
3. Essential app accessible; non-essential app shielded with zero purchased time. Phone/emergency flows remain usable.
4. Change essentials, then background during the native picker. Return must require the parent PIN and discard pending picker changes.
5. Purchase 15 minutes after earning 100 coins. Verify coins/allowance, allowed app access, background Littlewins and force-stop/relaunch behavior.
6. Keep a non-essential app open at expiry, including with its keyboard/notification shade open. The shield must return.
7. Reboot/time-change behavior, expiry while device asleep, midnight rollover, and delayed monitor callbacks.
8. Native activation failure or interrupted reply: receipt reconciliation must retain the debit for activated time or refund a confirmed non-activation.
9. Read/resume both books offline, verify sound, Russian layout and English questions, and repeat a page without duplicate reward.
10. Confirm actual device screenshots against the supplied scenes; Flutter web visual checks cannot establish native safe-area/font/OS-sheet fidelity.
