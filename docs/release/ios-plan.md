# Native iOS build: plan

**Status: planned, not started.** It starts after the Android beta passes
Gate 1 in `docs/development-roadmap.md` (phone tests and the 30–50 person
beta). Until then iPhone testers play the web build in Safari, sideways.

Why wait:
- The beta's retention and feel findings will change the game.
- An iOS release doubles the store, signing and device work for every
  change.
- The web build already gets iPhone feedback.

## What exists

- **An iOS export preset** (`godot/export_presets.cfg`, preset 2, "iOS"):
  - bundle id `com.climbup.game`, the same as the Android package;
  - version 0.9.0 (9);
  - minimum iOS 14;
  - iPhone and iPad;
  - the tests left out, as on Android.
- **Platform code that already copes with iOS:**
  - **Input:** touch only.
  - **Interruptions:** pause on background
    (`NOTIFICATION_APPLICATION_PAUSED`), the same path as Android.
  - **Haptics:** `Input.vibrate_handheld`, a no-op where there is no
    vibration.
  - **Save:** `user://`, so app storage on iOS.
  - **Records:** HTTPS only.
  - **Analytics:** local only.
- **Nothing Android-only that iOS needs a replacement for.**
  - There is no Android back button on iOS. Every screen already has an
    on-screen back or close.

## What it needs

| # | Step | Who | Notes |
| --- | --- | --- | --- |
| 1 | Apple Developer Program, as ARC Labs | ARC Labs | $99 a year. An organisation account needs a D-U-N-S number, which can take one to two weeks. Start early |
| 2 | Register the App ID `com.climbup.game`, and create the app in App Store Connect | ARC Labs | Same name and listing text as Play (`play-listing.md`) |
| 3 | A Mac with Xcode, or a macOS CI runner | ARC Labs / dev | Godot exports an Xcode project; Xcode signs and archives it. GitHub's `macos` runners can do this unattended |
| 4 | Godot 4.7.2 iOS export templates | dev | Same version as the editor |
| 5 | Signing | ARC Labs / dev | An Apple Distribution certificate and an App Store provisioning profile, kept as encrypted CI secrets like the Android upload key. App Store Connect API key for uploads. Never committed |
| 6 | `ios` target in `tools/godot/export.sh` and an `ios.yml` workflow | dev | Export, then `xcodebuild archive` and `-exportArchive`, then upload to TestFlight |
| 7 | iOS-specific checks | dev | Listed below |
| 8 | Privacy | ARC Labs / dev | A privacy manifest (`PrivacyInfo.xcprivacy`) declaring no tracking and the required-reason APIs Godot uses; the App Privacy answers mirror `data-safety.md` |
| 9 | Age rating and Kids category | ARC Labs | 12+ like Play's 13+ target. Not in the Kids category: the online records have an under-13 mode but are not designed for it |
| 10 | TestFlight | ARC Labs | Internal testers first, then an external group (needs Beta App Review) |

### iOS checks before TestFlight

These need real iPhones, at least one older (iPhone 11 class) and one
current:

- **Safe areas:** the notch and Dynamic Island in both landscape
  orientations, and the home indicator over the bottom controls.
- **Haptics:** the clip, catch and fall buzzes are felt and can be told
  apart (`Input.vibrate_handheld` lengths). If iOS flattens them into one
  pulse, add a small Core Haptics plugin.
- **Audio:** the session category, so the game respects the silent switch
  and other apps' music.
- **Frame rate** on the busy Kilimanjaro walls (Metal renderer).
  ProMotion phones stay at 60.
- **Interruptions:** a call, Control Centre, the app switcher, lock and
  unlock. Each pauses and resumes with nothing lost.
- **Storage:** the save survives an update, and nothing is written outside
  app storage.
- **Size:** the App Store download is reported after thinning. Keep it
  near the Android size.

## Rough effort

| Part | Time |
| --- | --- |
| Accounts (steps 1–2) | 1–3 weeks of waiting, mostly Apple's D-U-N-S and account checks |
| Engineering (steps 3–8) | About 3–5 days |
| A TestFlight round on two iPhones | 1 day |
