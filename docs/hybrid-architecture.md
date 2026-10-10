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
6. A completed scramble applies the original choice once, then an optional bounded follow-up (`wait`, not camp rest) for falls, stamina, or the Marco decision.
7. A retreat or a failure does not take the "move up" choice and does not receive the camp-rest gift. The wall card stays available. The next attempt gets a new id because history and elapsed time have changed.

The only registered scene is `barranco-wall`, opened by choice id `kili-wall-climb` on event `kili-wall`. The button label is not the identifier.

`hold` is a camp rest. Above 3,000 m it adds acclimatization and energy. `wait` stays at the same height and does not. Challenge failure, retreat, and the scramble's extra cost all use `wait`.

## Simulation and picture

`src/features/climbing/simulation` steps the scramble. `drainClock` turns a frame into at most four steps of 1/60 second. Calm view changes the picture only. It does not change the step. Buttons write input. The clock is what moves the climber. A retreat or a companion choice is latched once and consumed by the next step.

Rendering reads that state. It does not decide collisions, stamina, or the expedition result.

Web draws `ViewScene` with React Native views. iOS and Android draw `SkiaScene` with the same camera, the same pose offsets, and the same pictures. Skia is not imported on web, so a canvas failure cannot blank the page Expo web is verified with.

## Save

Schema version 2 stores the expedition state, the pending challenge, and `climb: null`. Version 1 files migrate on read. The key is still `climb-up-save-v1` on the web and `climb-up.db` on native. Writes are queued, so an older write cannot finish over a newer one. A bad payload is rejected and `explainSave` says why.

Restoring a pending attempt reopens the scramble at the camp side of the ledge. The attempt id is kept and the card is still unspent. Position on the rock is not stored. `climb: null` is that decision, written down so a later version can add it without pretending it already exists.

## What this slice does not do

Crag mode is not a second ruleset. Future short climbs should register another `ChallengeSpec` and another level, then report through `resolveChallenge`. Godot is not in the repository. Do not add a second production simulation beside this one.
