# Hybrid architecture

CLIMB UP keeps one expedition simulation. A playable scramble is a scene that reports a single outcome back into that simulation.

## Who owns the truth

`src/game/engine` and `src/expeditions/kilimanjaro` remain the authority for altitude, supplies, energy, team condition, history, marks, and score. The climbing scene does not keep a second copy of those numbers.

`src/game/hybrid` is the only door between a choice and a scene.

1. The player picks a choice.
2. `beginChallenge` looks up the choice in `challengeRegistry`. If it is not a playable challenge, the screen calls `chooseKilimanjaro` as before.
3. If it is playable, the coordinator stores a `PendingChallenge` and does not mark the card seen and does not apply the choice effect.
4. The scramble runs. Leaving the app keeps the pending attempt in the save.
5. `resolveChallenge` checks the attempt id, the event, the choice index, and the mark `resolved-{attemptId}`. A second call with the same attempt returns the same state.
6. A completed scramble applies the original choice once, then an optional bounded follow-up (`hold` only) for falls, stamina, or the Marco decision.
7. A retreat or a failure does not take the "move up" choice. The wall card stays available. The next attempt gets a new id because history and elapsed time have changed.

The only registered scene is `barranco-wall`, opened by the Kilimanjaro choice "Climb the wall and camp at Karanga" on event `kili-wall`.

## Simulation and picture

`src/features/climbing/simulation` steps the scramble. `drainClock` turns a frame into at most four steps of 1/60 second, or two steps of 1/30 second when Calm view is on. `stepClimb` still refuses a step longer than 1/30 second. A tap is one of those short steps. Holding a direction lets the clock keep stepping. Releasing clears the input so a click cannot walk forever.

Rendering reads that state. It does not decide collisions, stamina, or the expedition result.

Web draws `ViewScene` with React Native views. iOS and Android draw `SkiaScene` with the same camera, the same pose offsets, and the same pictures. Skia is not imported on web, so a canvas failure cannot blank the page Expo web is verified with.

## Save

Schema version 1 stores the expedition state and the pending challenge. Web uses `localStorage` (`climb-up-save-v1`). Native uses `expo-sqlite` (`climb-up.db`). A bad payload or a newer version is ignored. Restoring a pending attempt reopens the scramble at the start of the ledge. The attempt id is the one that was saved. The card is still unspent. Position on the ledge is not stored.

## What this slice does not do

Crag mode is not a second ruleset. Future short climbs should register another `ChallengeSpec` and another level, then report through `resolveChallenge`. Godot is not in the repository. Do not add a second production simulation beside this one.
