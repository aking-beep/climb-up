# Testing

## Automated (run before every push)

```bash
npm test            # Jest: engine, coordinator, save, simulation, runtime
npm run typecheck   # tsc --noEmit, strict
npm run lint        # expo lint (includes React Compiler hook rules)
npx expo-doctor     # needs network for 2 of its 21 checks
```

| Suite | Covers |
| --- | --- |
| `src/game/engine/__tests__/engine-test.ts` | original expedition engine (unchanged) |
| `src/expeditions/kilimanjaro/*-test.ts` | route, events, party, full careful and reckless playthroughs (unchanged) |
| `src/game/hybrid/__tests__/coordinator-test.ts` | launching, resolving once, duplicates, stale and malformed outcomes, retreat and fail, modifier bounds, balance against resting, scoring after a played wall |
| `src/game/save/__tests__/save-test.ts` | save round trip, corrupt, newer, and invalid files, interrupted climb restored and resolved once across three "app launches", failed writes |
| `src/features/climbing/__tests__/sim-test.ts` | level parsing, collision, climbing limits, falls, stamina drain and recovery, three-slip failure, wind timing, held help (taps do nothing), regroup, retreat, determinism, and a **scripted full ascent** of the Barranco level |
| `src/features/climbing/__tests__/presentation-test.ts` | sprite clip timing, camera follow and bounds, reduced-motion shake, parallax ordering |
| `src/features/climbing/__tests__/runtime-test.ts` | 60 Hz simulation independent of display rate, stall handling, immutable frames, low-power publishing, hints |

## On a phone

```bash
npm install
npx expo start              # scan the QR code with Expo Go (SDK 57)
```

If Expo Go reports a missing native module for Skia or SQLite, build a
development client instead:

```bash
npx eas-cli@latest build:configure
npx eas-cli@latest build --profile development --platform android   # or ios
npx expo start --dev-client
```

### Manual checklist for the Barranco slice

1. Start a new expedition and play to Barranco Camp: *Walk the forest and set
   camp*, *Sleep under the trees*, *Break camp and keep a patient pace*,
   *Stake the tents and sleep*, *Cross the plateau and pitch at Shira 2*,
   *Sleep before the tower*, *Tag the tower, then sleep low*,
   *Sleep and leave the wall for morning*.
2. The wall card shows **Playable climb** on *Climb the wall and camp at
   Karanga*. Choose it.
3. Briefing: energy and stamina shown. Start.
4. Walk, scramble the two boulders, climb both faces, cross the exposed step
   only between gusts, help Marco, climb the gully, reach the marker.
5. *Return to the expedition*. You are at Karanga. The field note mentions
   Marco. The journal has one entry for the wall.
6. Repeat with: back off from the briefing; back off from pause mid-wall; three
   slips (hang on a face until your arms give out). Each returns you to
   Barranco with the wall card spent.
7. Interruption: start the wall, background the app, then kill it. Relaunch.
   The title screen offers *Return to the Barranco Wall*; the expedition screen
   shows the waiting card. Return to the wall, or back off. Either lands once.
8. Settings (pause menu): reduced motion, low power, pad on the right,
   tap instead of hold, show frame rate. Check each takes effect.
9. Android: hardware back pauses instead of leaving.
10. With *Show frame rate* on, note fps on the exposed step (the heaviest
    scene: gust streaks plus mist) and on the high ledge.

## Web (development only)

```bash
npm run web      # copies canvaskit.wasm into public/, then starts the dev server
```

Arrow keys or WASD to move, Space to help, Escape to pause.

Headless Chromium needs `--enable-unsafe-swiftshader --use-angle=swiftshader`;
without them it falls back to a deprecated software WebGL path that leaves the
Skia canvas stale while the briefing sheet is open. That is a test-browser
artefact, not an app bug.

## Not yet verified

- Any run on a physical iOS or Android device, including Expo Go module
  availability and real frame rates.
- The teammate and decision overlays have been exercised by simulation tests
  but not looked at in a browser or on a device.
- VoiceOver and TalkBack passes.
