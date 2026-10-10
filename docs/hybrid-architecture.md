# Hybrid architecture

CLIMB UP alternates between two kinds of play: the **expedition** (card
decisions over days, the existing deterministic engine) and short **playable
challenges** (real-time climbing scenes). This document describes how they fit
together without either one owning the other's state.

Status as of this branch: the coordinator, save layer, simulation, and one
challenge (the Barranco Wall) are implemented and tested. Device testing has
not been done. See [development-roadmap.md](development-roadmap.md).

## Layers

```
src/app/                         Expo Router screens (thin)
  index.tsx                      title, start / continue
  climb.tsx                      expedition view; launches challenges
  challenge.tsx                  playable challenge route

src/game/engine/                 expedition engine (authoritative, unchanged rules)
src/game/hybrid/                 coordinator: pending challenges, reconciliation
src/game/save/                   versioned save file, store, settings, storage adapters
src/game/session.ts              app singletons + React hooks

src/expeditions/kilimanjaro/     content: route, events, party, challenges.ts

src/features/climbing/           real-time climbing
  level.ts, levels/              authored tile maps
  sim.ts                         deterministic 60 Hz simulation
  runtime.ts                     fixed-step loop, input, camera, frame snapshots
  camera.ts, sprites.ts, hints.ts
  render/                        Skia renderer (presentation only)
  ui/                            React Native controls, HUD, overlays
```

Dependencies only point downward: `features/climbing` never imports the
expedition engine, and the engine never imports anything from `hybrid` or
`features`. The coordinator is the only place the two meet.

## The decision boundary

Before this branch, choosing a card called `applyDecision`, which resolved the
choice's effect, marked the card seen, and wrote history in one step.

That is now `resolveDecision(state, index, def, adjust?)` in
`src/game/engine/select.ts`. `applyDecision` is a one-line wrapper over it, so
every existing call site and test behaves identically. The optional `adjust`
function reshapes the choice's effect *before* it is applied. That is the only
hook a challenge has into the engine: a challenge outcome is never applied as a
second effect on top of the card.

Three small engine changes support this:

- `Effect.scores` may hold a list of notes per score bucket, so a challenge's
  teamwork note does not overwrite the card's own. A single note is still
  accepted, so existing event data is unchanged.
- A new move, `wait`, keeps the party where it is **without** the camp-rest
  benefit that `hold` gives above 3000 m. Failed and abandoned challenges use
  it, so walking away from a climb can never be a disguised rest day.
- `Choice.id` is an optional stable id. Challenges are registered by card id and
  choice id, so editing a choice's wording cannot break or redirect a challenge.

## Playable choice flow

```
climb.tsx  ── choose(index) ──▶ coordinator.choose
                                 │ card choice registered as a challenge?
                                 ├─ no  → resolveDecision now (old behaviour)
                                 └─ yes → session.pending = PendingChallenge
                                          (expedition state NOT touched)
           ◀── launched ─────────┘
router.push('/challenge')
challenge.tsx → ChallengeView → runtime → sim … result
           ── resolve(outcome) ─▶ coordinator.resolve
                                   validate → combine → resolveDecision(adjust)
                                   pending = null, attemptId recorded
router.back() to climb.tsx (field note shows the change)
```

### Contracts (`src/game/hybrid/types.ts`)

- `ChallengeDefinition`: which card (`eventId`) and which choice
  (`choiceId`, the choice's stable id, so neither reordering nor rewording
  choices can launch the wrong thing) open the challenge, and a `modifier(outcome, baseEffect, state)`
  function returning an `OutcomeModifier`.
- `PendingChallenge`: `attemptId`, `eventId`, `choiceIndex`, `choiceLabel`,
  `historyLength`, and a deterministic `seed` for the simulation.
- `ChallengeOutcome`: `result` (`complete | retreat | fail`), `staminaLeft`,
  `slips`, `assisted`, `regrouped`, `seconds`. Plain data; savable.
- `OutcomeModifier`: bounded stat deltas, extra hours, an optional
  `move: 'wait'` (a challenge can take height away, never add it, and never
  turns into a rest),
  `keepBaseScores`, and its own score notes.

### Invariants

| Rule | Where it is enforced | Test |
| --- | --- | --- |
| A playable choice does not change expedition state until the outcome lands | `coordinator.choose` | `choosing the wall opens a pending challenge…` |
| Each attempt resolves exactly once | `resolvedAttempts` list, checked first | `a duplicate outcome changes nothing`, store restore test |
| An outcome must match the open attempt | `attemptId` comparison | `an outcome for some other attempt is refused` |
| An outcome for a state that has moved on is discarded | `historyLength` + current card check | `an outcome for a state that has moved on is discarded…` |
| A challenge cannot add height or large rewards | `boundModifier`: stats −12…+6, hours 0…12, scores −8…+8, notes must carry a mark | `the modifier cannot exceed its limits` |
| Score notes cannot be earned twice | engine `marks`, and every challenge note has a mark | engine behaviour, unchanged |
| Backing off is never better than the equivalent rest choice | Barranco modifier tuning | `backing off is never better than resting…` (5 seeds) |
| Camp beats are blocked while a challenge is pending | `coordinator.play` | `camp beats are blocked…` |

The attempt id is `expeditionId:seed:eventId:historyLength`. It is stable for
the same expedition moment, so a restarted attempt keeps its id, and a spent id
can never recur because history only grows.

## Save and resume

- Storage: `expo-sqlite/kv-store` on iOS and Android (`device.ts`), and
  `localStorage` on web (`device.web.ts`), behind a three-method `SaveStorage`
  interface. Tests use `memoryStorage`.
- File: `{ version, savedAt, session }`, key `climb-up/session`. `session`
  holds the expedition state, the previous state (for the field note),
  the pending challenge, and every resolved attempt id.
- Versioning: `SAVE_VERSION` plus a `MIGRATIONS` table keyed by source
  version. A save from a newer app, a corrupt file, or a file that fails shape
  validation is ignored (not deleted) and play starts fresh.
- Writes are queued in order after every change. A failed write is recorded
  (`store.lastError()`), never thrown into the UI.
- The root layout waits for the save to load before hiding the splash screen.

**What resume covers:** closing the app mid-climb keeps the pending
challenge. On return, the expedition screen shows "The Barranco Wall is
waiting" with *Return to the wall* or *Back off*, and the title screen offers
*Return to the Barranco Wall*.

**What it does not cover yet:** progress *inside* a climb is not saved. A
resumed attempt restarts from Barranco Camp with the same seed, so it plays
identically. Saving mid-climb would mean serialising the simulation; the sim is
plain data, so this is feasible later.

## Real-time climbing

### Simulation (`sim.ts`)

A pure TypeScript fixed-step simulation, one `step()` per 1/60 s, mutating a
plain `ClimbSim` object. Nothing in it reads the clock, random numbers, or the
platform. The only randomness is the seed, which offsets the gust schedule.
Same level + seed + input sequence gives the same result (tested).

- Tile collision, axis-separated, against `#` tiles; level edges are walls.
- Walking with acceleration, gravity, and a fall-distance check (a fall over
  3.2 tiles is a slip).
- Scrambling on `S`/`l` faces: press up to grab, the hands stop at the top of
  the face, step sideways onto the ledge. Corner correction slides a climber
  whose shoulder catches a lip.
- Stamina: drains while climbing (more on loose rock), recovers on the ground
  (fastest standing still on a rest stone). Empty arms means a slip.
- Slips return the climber to the last checkpoint. Three slips fail the
  attempt.
- Wind: a warn → blow → calm schedule over exposed `N` tiles, faster in
  worse expedition weather. Moving during a blow is a slip.
- Teammate: reaching Marco opens a held interaction and then a decision
  (continue, regroup, retreat).

### Runtime (`runtime.ts`)

Owns the sim, held input, camera and timing outside React. `advance(dt)` runs
as many 60 Hz steps as the elapsed time allows (at most 6 per frame, so a stall
drops time rather than fast-forwarding through the wall). After a batch it
publishes an immutable `Frame` snapshot. The screen subscribes with
`useSyncExternalStore`, so nothing mutable is read during render, which is
what the React Compiler lint rules require. Rendering is independent of
simulation rate. In low-power mode only every other display frame is published.

### Rendering (`render/`)

Skia draws one `Canvas` with ten conceptual layers: sky gradient and sun glow,
distant range, clouds and haze, middle-ground valley and ridge, the cliff
backdrop, the playable wall, characters and markers, out-of-focus foreground,
weather (mist bands, particles, gust streaks), and a grade/vignette pass. Level
geometry is baked once into a few `SkPath`s with `PathBuilder` rather than one
node per tile. Sprites come from a sheet, nearest-neighbour sampled at an
integer scale.

Skia is presentation only. The renderer reads frames and never changes game
state.

### Web

Skia on web needs CanvasKit (WebAssembly). `ChallengeHost.web.tsx` wraps the
view in `WithSkiaWeb`, and `npm run web` copies `canvaskit.wasm` into
`public/` first (gitignored). Native builds use `ChallengeHost.tsx`, which
re-exports the view directly. Web is a development convenience: the target
platforms are iOS and Android.

## Native modules and Expo Go

If Skia fails to load on a device, `ChallengeHost.tsx` catches it and shows an
explanation with *Back off and stay at Barranco*, which resolves the attempt
normally. The expedition never crashes because of the renderer.

New native dependencies, installed at the versions pinned in
`node_modules/expo/bundledNativeModules.json` for SDK 57:

- `@shopify/react-native-skia` 2.6.2
- `expo-sqlite` ~57.0.4 (config plugin added to `app.json` by `expo install`)

Both are part of the Expo SDK's module set, so they are expected to work in
Expo Go for SDK 57. **This has not been verified on a device** (see
[testing.md](testing.md)). If Expo Go reports a missing native module, use a
development build:

```bash
npx eas-cli@latest build:configure          # creates eas.json (none exists yet)
npx eas-cli@latest build --profile development --platform ios     # or android
npx expo start --dev-client
```

## Adding a challenge

1. Author a level in `src/features/climbing/levels/` (tile map + backdrop).
2. Give the launching choice an `id` in the event data, and add a
   `ChallengeDefinition` in the expedition's `challenges.ts` naming the card id
   and that choice id, with a modifier that respects the limits above.
3. Add it to the expedition's `challenges` list. The coordinator, save, and
   expedition screen pick it up. `challenge.tsx` currently mounts the Barranco
   level directly; a second challenge needs a level lookup by `challengeId`.
4. Write the balance test: the played outcome must not beat the equivalent
   unplayed choice on retreat or failure.
