# Development roadmap

Status as of this branch (`ccr-b5506e55-rahee5`). "Done" means implemented and
covered by automated tests. Nothing has been run on a physical device yet.

## Repository audit (starting point)

- **Stack:** Expo SDK 57.0.27, React Native 0.86.3, React 19.2.3, Expo Router
  57, Reanimated 4.5.1, TypeScript 6.0.3 strict, Jest via `jest-expo`.
  Portrait only. EAS project id present; no `eas.json`.
- **Baseline:** 5 suites, 30 tests, typecheck and lint all green before any
  change.
- **Working:** the deterministic expedition engine (`createExpedition`,
  `currentEvent`, `applyDecision`, `applyEffect`, `scoreExpedition`); a
  ten-day Lemosho campaign with 7 night cards and turnaround and descent logic;
  party members with tappable camp actions; seeded expedition codes; the
  judgment-first score with ledger notes; the HD-2D diorama travel scene
  (painted plates, pixel party, tilt-shift blur, time-of-day grading,
  Reanimated snow).
- **Present but unreachable:** the Everest expedition (data complete, no
  screen starts it), and 11 components from earlier visual iterations
  (`TerrainStage`, `Climber`, `Camp`, `CloudLayer`, `DayNightLayer`,
  `EnvironmentTransition`, `ExpeditionParty`, `ParallaxMountain`,
  `RouteMarker`, `RouteProgress`, `TopoMark`, `WeatherLayer`). Left in place;
  candidates for removal.
- **Animation quality:** party sprites are single front-facing frames, moved
  with transforms (bob, lag). No frame animation existed.
- **Persistence:** none. Closing the app lost the expedition.
- **Risks found:** the decision handler applied effects immediately, with no
  seam for a deferred outcome (fixed with `resolveDecision`); `Effect.scores`
  held one note per bucket (extended to lists); background art has no recorded
  license.

## Phases

| Phase | Status | Notes |
| --- | --- | --- |
| 1. Audit and architecture | **Done** | Audit above; [hybrid-architecture.md](hybrid-architecture.md), [gameplay-spec.md](gameplay-spec.md), [hd2d-art-direction.md](hd2d-art-direction.md), [asset-manifest.md](asset-manifest.md), [testing.md](testing.md) |
| 2. Hybrid coordinator | **Done** | Pending challenges, deterministic attempt ids, registry by card and choice label, bounded reconciliation, exactly-once resolution, versioned SQLite save with migrations table, interrupted-attempt restore |
| 3. Graybox climbing | **Done** | 60 Hz deterministic sim, tile collision, scrambling, stamina, wind, checkpoints, teammate, complete, retreat, and fail; Barranco level with a scripted full ascent in tests; touch pad |
| 4. HD-2D graphics | **Partial** | Skia scene with the full 10-layer stack, parallax, depth blur, mist, particles, gust streaks, grading, sprite-sheet animation controller with 11 states. **Art is placeholder**: procedural wall, programmer sprites, reused background PNGs |
| 5. Hybrid integration | **Partial** | Camp → wall → camp works and saves. Team interaction is Marco only; Lena and Jun do not appear in the climb |
| 6. Mobile quality | **Not started** | Haptics, pause on background, Android back, low-power and reduced-motion settings, and an fps meter exist; no device profiling yet |
| 7. More playable content | **Not started** | |

## Next priorities, in order

1. **Run it on hardware.** Expo Go on one recent iPhone and one mid-range
   Android. Record fps on the exposed step with and without low power, and
   check that Skia and SQLite load in Expo Go (else make a development build,
   see [testing.md](testing.md)). Fix whatever that finds before anything else.
2. **Feel pass on the wall.** Tune `TUNING` from real thumbs: climb speeds,
   gust timing, stamina costs. Consider an analogue thumbstick option next to
   the d-pad.
3. **Real art for Barranco.** Commission or draw the climber and Marco sheets
   and the volcanic tileset (see the asset manifest). Swap them in without code
   changes beyond the sheet table.
4. **Save mid-climb.** Serialise `ClimbSim` into the pending challenge on pause
   and background, so an interrupted climb resumes where it stopped.
5. **Second challenge plumbing.** Look the level up by `challengeId`, not
   hard-coded Barranco. Then pick the next playable beat (the summit-night
   start from Barafu is the strongest candidate).
6. **Performance headroom.** If device numbers are short: record static level
   geometry into an `SkPicture`, move per-frame values to Reanimated shared
   values instead of React re-renders, and cap particle counts by device class.
7. **Housekeeping.** Remove the unreachable components or move them to an
   archive folder; decide Everest's future; record asset licenses.

## Godot

Not evaluated, by design. Revisit only if device profiling of this slice shows
that collision, camera, or lighting needs are beyond a maintainable custom
implementation. The simulation is engine-agnostic TypeScript, and the
expedition engine would have to be ported or bridged, which is the main cost
of any migration.
