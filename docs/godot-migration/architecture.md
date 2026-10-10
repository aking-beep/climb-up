# CLIMB UP in Godot: architecture and migration plan

Status: **prototype**. The Godot project in `godot/` is an A/B candidate
built alongside the Expo app, which is untouched and still the shipping
game. Nothing in `src/` depends on `godot/`, and nothing in `godot/`
imports TypeScript.

The question this prototype answers: does Godot give CLIMB UP a better
adventure game (movement, level authoring, presentation, mobile feel) than
Expo + Skia, at an acceptable migration cost? See
[comparison.md](comparison.md) for the answer so far.

## 1. The existing game (Expo), audited

| Layer | Where | What it does | Verdict for Godot |
| --- | --- | --- | --- |
| Expedition engine | `src/game/engine/` (`apply`, `rules`, `select`, `score`) | Deterministic, seeded. State: altitude, health, energy, acclimatization, oxygen, supplies, weather and objective risk, team condition, hours, summit and safe-return flags, a score ledger of once-only marked notes. Cards with choices; effects applied once. | **Preserve the rules, port later.** It is the game's design and has 30+ tests. Port to GDScript only when Godot is chosen, and run the same scenarios against both. |
| Kilimanjaro content | `src/expeditions/kilimanjaro/` | 10-day Lemosho, event cards, party (Jun, Marco, You, Lena) with derived poses, three gated climbs | **Preserve as data.** Cards and party move over as data, not code. |
| Scoring | `src/game/engine/score.ts` | Judgment 34 %, risk 28 %, teamwork 18 %, preparation 20 %; not returning caps the score at 40; a summit without return at 36; a strong return earns +12 | **Preserve exactly.** This is "how high you climb isn't how you win". |
| Hybrid coordinator | `src/game/hybrid/` | A card choice launches a challenge; one `ChallengeOutcome` lands once (attempt ids, stale/duplicate checks); a bounded modifier shades the card's effect (stats −12…+6, hours 0…12, scores −8…+8) | **Preserve the contract.** The Godot climb emits the same `ChallengeOutcome` shape (section 6). |
| Climb simulation | `src/features/climbing/sim.ts` | 60 Hz fixed-step tile sim: walk, scramble faces, stamina, loose rock, exposed step with telegraphed gusts, slips to the last cairn, Marco (help/leave/step back), regroup, retreat | **Redesign on Godot's physics.** Keep the tuning and the rules (telegraphed wind, slips not deaths, helping costs stamina and pays back later); replace the hand-written collision with `CharacterBody2D` and `TileMapLayer`. |
| Levels | `src/features/climbing/levels/*.ts` | ASCII tile maps, 20–22 tiles wide, 2–3 minutes each | **Redesign.** Godot levels are 5–10 minutes, wider than a screen, with slopes, camps and people. The ASCII legend survives as an authoring format. |
| Rendering | `src/features/climbing/render/`, `src/features/world/` | Skia: parallax, tiles, sprites, fog, bloom, grading; HD-2D expedition diorama | **Replace with Godot nodes** (`Parallax2D`, `PointLight2D`, `CPUParticles2D`, `CanvasModulate`, shaders). |
| Art | `tools/art/*.py` → `assets/hd2d/` | Project-owned generated art: party sheets (32 × 40, 27 side frames, 12 map frames), tiles, scenery | **Reuse.** The Godot project copies the generated PNGs; `tools/art/godot_barranco.py` adds the Godot tileset. |
| Persistence | `src/game/save/` | Versioned save, migrations, corrupt/newer/invalid handling, interrupted climb restored | **Preserve the rules** (versioned, validated, never trust a save). Godot saves JSON to `user://`. |
| Tests | Jest, 125 tests | engine, coordinator, save, sim, levels, difficulty ramp | **Mirror** in Godot's headless test runner (`godot/tests/`). |

## 2. Godot architecture

One repository, one Godot project, shared core, game modes on top. Crag
mode gets a folder only when it is built; nothing is stubbed for it now.

```text
godot/
  project.godot           landscape 480 × 270 pixel viewport, scaled ×4 to 1080p
  core/                   shared by every mode
    input/                GameInput: actions, never raw keys; touch overlay
    player/               Climber (CharacterBody2D), state machine, animation
    climbing/             StaminaModel, terrain kinds, climb rules
    world/                Terrain (ASCII → TileMapLayer + semantics), LevelBuilder
    weather/              WindSchedule, Weather (clear … snow), particles
    camera/               ExpeditionCamera: look-ahead, bounds, reveal zones, shake
    companions/           Companion (follower, needs help, catches a slip)
    audio/                Audio: buses, ambience, footsteps, placeholder sounds
    save/                 SaveGame: versioned JSON, validation, migration hook
    settings/             Settings: quality (FULL / REDUCED / LOW POWER), reduced motion
    ui/                   dialogue box, choice panel, HUD, pause
  modes/
    expedition/           ExpeditionState (prototype subset), briefing, outcome, mapping
      levels/kilimanjaro/barranco/   the level data and scene
  assets/                 sprites, terrain, scenery, audio (all project-owned or placeholder)
  tests/                  headless runner + suites, including a scripted full ascent
```

Principles:

- **Gameplay rules live in plain `RefCounted` classes** (stamina, wind,
  outcome, save validation, expedition state), so they are testable without
  a scene and portable later.
- **Nodes do presentation and physics.** The climber is a
  `CharacterBody2D`; terrain is a `TileMapLayer` with collision, and a
  parallel semantic grid answers "is this climbable, loose, exposed, a rest
  spot".
- **Input goes through actions** (`move_left`, `move_right`, `climb_up`,
  `climb_down`, `interact`, `brace`, `rest`, `pause`). Keyboard, gamepad and
  the touch overlay all feed the same actions.
- **Quality settings never touch the simulation.** Physics runs at 60 Hz
  regardless; reduced quality cuts particles, fog layers and lights.
- **The environment is the antagonist.** No enemies; wind, loose rock,
  exposure, fatigue, and time.

## 3. Systems kept, systems redesigned

Kept (rules and numbers carried over from the Expo sim):

- Stamina bar sized by expedition energy: `55 + energy × 0.45`, 55–100.
- Drain 6/s climbing, 2/s hanging, ×1.6 on loose rock; regen 10/s still,
  3/s walking, 26/s on a rest stone; "tired" below 30 %.
- A fall over 3.2 tiles is a slip, not a death: stumble, back to the last
  cairn with at least half stamina. Three slips and the team calls it.
- Wind: warning 1.5 s, gust 1.1 s, period by weather risk. Telegraphed,
  never a reflex test.
- Marco: help (costs stamina, then he climbs behind you and catches one
  slip), leave him for Lena (costs team condition at camp), or step back.
  Then continue, regroup (full stamina, half an hour), or turn back.
- Retreat is always available and always resolves as a retreat.

Redesigned:

- **Movement** gains slopes, mantling onto ledges, scrambling boulders
  (faster, cheaper than climbing), explicit **brace** in the wind (standing
  still no longer suffices on the exposed step: an unbraced climber is
  pushed), **rest** as an action (sit down, recover faster, time passes).
- **Levels** are connected spaces with a camp, people to talk to, signs,
  and a transition out, not a single tower.
- **Camera** composes the mountain: it leads in the direction of travel,
  pulls back at vistas, and holds the wall in frame on climbs.

## 4. Migration risks

| Risk | Mitigation |
| --- | --- |
| Two codebases drift | Godot ports rules only after the decision; until then the Expo engine is the reference and Godot holds a prototype subset. |
| Expedition engine port bugs | Port with the same seeded scenarios as the Jest tests; compare outcomes card by card. |
| Mobile export (Android/iOS) | Godot exports need export templates and, for iOS, Xcode. Not available in this environment; must be proven on a developer machine early. |
| Touch controls feel | Prototype overlay is built; needs real thumbs. |
| Art pipeline | Generated art transfers; hand-drawn art would come in as sheets with the same frame order. |
| Team skills | GDScript is small and readable; the project avoids plugins. |
| Environment used to build this prototype | Godot 4.4.1 from Ubuntu's archive, run headless and under Xvfb for tests and screenshots. No web, Android or iOS templates, so no playable link from here: open `godot/` in the Godot editor and press Play. |

## 5. Comparison criteria

Measured or judged, not assumed (results in [comparison.md](comparison.md)):
game feel, movement, physics, animation, level authoring, lighting,
particles, camera, performance (only with device numbers), mobile controls,
maintainability, development speed, asset pipeline, expedition integration,
Android and iOS deployment.

## 6. Outcome mapping to the Expo engine

The Godot climb ends by writing a `ChallengeOutcome` with the same fields
as `src/game/hybrid/types.ts`:

```json
{
  "attemptId": "kilimanjaro:7:kili-wall:12",
  "challengeId": "barranco-wall",
  "result": "complete | retreat | fail",
  "staminaLeft": 0,
  "slips": 0,
  "assisted": true,
  "regrouped": false,
  "seconds": 0
}
```

plus Godot-only detail the Expo modifier ignores today (`caught`,
`windStrikes`, `looseSeconds`, `restSeconds`, `checkpoint`). Fed to
`resolve()` in `src/game/hybrid/coordinator.ts`, the Barranco policy in
`src/expeditions/kilimanjaro/challenges.ts` applies:

| Result | Lands on the expedition |
| --- | --- |
| complete | the card (up to Karanga, −8 energy, +4 acclimatization, +2 team, judgment +6, teamwork +4), then: −2 health per slip (max −6); −4 energy under 25 % stamina; helped Marco +5 team, +3 energy, teamwork +6; left him −6 team, teamwork −6; regrouped +2 energy, +1 h, judgment +3 |
| retreat | stay at Barranco, the lost day, half the energy back, acclimatization and team gains undone, judgment +3 |
| fail | stay at Barranco, −6 health, −4 energy, −4 team, risk management −6 |

The Godot prototype applies this same table to its own small
`ExpeditionState` so the result screen shows real consequences. Section 1's
"port later" applies to everything else in the engine.

## 7. Safe return

The expedition loop is ascent → summit → descent → safe return, and the
score already refuses to reward a summit without a return. In Godot:

- `ExpeditionState.phase` is `ascent`, `summit`, `descent` or `home`;
  only `home` with `returned_safely` scores as a success.
- Levels declare a direction (`up` or `down`). A descent level reuses the
  same terrain and climber with down-climbing, tired legs, and failing light
  as its hazards.
- The summit scene's exit leads to the first descent level, never to the
  credits.

None of the descent is built in this prototype.
