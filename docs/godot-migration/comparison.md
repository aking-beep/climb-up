# Godot vs Expo + Skia: first comparison

Written after the first pass of the Godot Barranco Wall (`godot/`). It
compares what was built and measured in this repository. Anything not
measured is marked as such. **No device has run either version's climb yet,
so there are no frame rates here.**

## What exists in each

| | Expo + Skia (`src/`) | Godot 4 (`godot/`) |
| --- | --- | --- |
| Barranco Wall | 22 × 34 tiles, one screen wide, portrait | 228 × 98 tiles, ~14 screens of terrain, landscape |
| Route | camp, 2 faces, exposed step, Marco, gully | camp with people and signs, approach under a buttress, scramble band, face, traverse over a void, rest ledge, steeper face, exposed ledge, Marco, loose gully with a resting niche, shoulder with a view, crouch ledge in the wind, upper face, plateau, descent to Karanga |
| Movement | walk, climb faces, step off, wind slip | walk with slopes, scramble, climb, traverse, mantle onto ledges, step-assist over lips, rest (sit), brace, slip, fall, catch the rock on a short fall, help |
| Teammate | Marco: help, leave, step back; helped Marco catches a slip | the same choices and catch, plus Marco physically follows your exact path up the wall; walking past him counts as leaving him |
| Expedition | the full engine, 10 days, 3 gated climbs | the same Kilimanjaro expedition: the engine ported to GDScript and replayed against seven recorded TypeScript playthroughs (178 steps, identical); a camp screen with the diorama, cards, camp beats and party; all three climbs playable |
| Other climbs | Lava Tower, summit night | Lava Tower (150 × 64 tiles) and summit night (132 × 92, by headlamp), with the Expo difficulty ramp |
| Tests | 125 Jest tests | 49 headless Godot tests, including scripted full ascents of all three climbs with every hazard live, and whole expeditions played on each route |
| Playable now | web build via the artifact link; Expo Go | web build via its own artifact link; a debug Android APK; or the Godot editor (4.7+) |

A route-knowing bot climbs the Godot wall in **137 s of game time**, the
Lava Tower in 60 s and the summit night in 237 s (measured by the tests). A first-time player
reading signs, talking, waiting out gusts and slipping will take longer;
5–8 minutes is an estimate, not a measurement.

## Criteria

| Criterion | Evidence | Leans |
| --- | --- | --- |
| Game feel, movement | Godot's `CharacterBody2D` gave slopes, floor snapping, ledges and collision without writing a collision solver. The Expo sim needed its own collision, corner correction and a slip-around-lip fix, and still has no slopes. Feel on a real thumb is untested in both. | Godot |
| Physics | Godot: built-in, used as is. Expo: deterministic custom sim, which is easier to unit test exactly. Godot's run was made testable with `--fixed-fps 60` and a scripted input layer; the full ascent is reproducible. | Even |
| Animation | Both use the same generated 32 × 40 sheets and the same clip table. Godot's `AnimatedSprite2D` needed no custom frame code. | Godot (slightly) |
| Level authoring | Both levels are ASCII maps generated from a script here. Godot also offers in-editor tile painting, which this prototype does not use yet. Godot's level is 6× the area of the Expo one and was not harder to build. | Godot |
| Lighting | Godot: `CanvasModulate` that dims under overhangs, a light around the climber, a flickering fire light, all built in. Expo: hand-made gradients and blend modes. | Godot |
| Particles | Godot: `CPUParticles2D` for dust and gust streaks. Expo: hand-made particles. | Godot |
| Camera | Comparable. Godot's has look-ahead, look-up on faces, reveal zones at vistas and shake. | Even |
| Performance | **Not measured on any device.** Godot runs the compatibility (OpenGL) renderer; quality settings cut fog, particles and lights, and a test shows they never change the simulation. | Unknown |
| Mobile controls | Expo has an on-screen pad. Godot has a floating analog stick, a context button and an edge guard, checked in an emulated phone browser. Neither tested on a real phone. | Unknown |
| Maintainability | Godot: about 3,800 lines of GDScript in total, with rules in plain classes (stamina, wind, outcome, expedition state, saves) and a test runner. Expo: TypeScript, strict, with mature tooling. | Even |
| Development speed | The Godot slice (bigger level, more mechanics, flow, saves, tests, recording) was built in one pass. The level bugs that mattered were found by the scripted ascent, not by eye. | Godot (this pass) |
| Asset pipeline | Shared: the Python art scripts feed both. Godot needs `.import` sidecar files (committed). | Even |
| Expedition integration | Both now run the Kilimanjaro expedition. Godot's engine is a port, held to Expo's by replaying recorded playthroughs; Expo also has Everest and the other mountains. | Expo (more content), Godot (parity shown for Kilimanjaro) |
| Android deployment | Expo: EAS build or Expo Go today. Godot: a 30 MB debug APK exported from the official template with `apksigner` alone (no Gradle, no full SDK); **not yet installed on a real phone**. | Even, pending a phone |
| iOS deployment | Expo: EAS. Godot: export from the editor on a Mac with Xcode; **not attempted here**. | Expo, until proven |
| Sharing a test build | Expo: web build as an artifact link (about 6 MB of JS and assets). Godot: web build as an artifact link too, but the engine is a 10 MB gzipped download before anything shows, and the build is single-threaded. | Expo (lighter) |

## Recommendation

**Promising, not yet decided.** For the adventure layer, Godot
produced a noticeably richer, larger, more physical climb, with lighting and
particles that took little code. That is the part of CLIMB UP you are
pushing toward with Goner as the reference. Expo still wins on everything
already shipped: the complete expedition engine, 125 tests, and one-tap
sharing and testing on phones.

Before committing to Godot:

1. **Put the APK on a phone.** The web and Android builds exist now
   (`tools/godot/export.sh`). Note fps on the crouch ledge (wind streaks,
   fog) at Full and Low power, and how long the web build takes to load on
   mobile data.
2. **Play it with thumbs.** Judge the touch overlay, the mantle, and the
   brace timing. Change `Climber` constants and the overlay before anything
   else.
3. **If both hold up, port the expedition engine** to GDScript behind the
   same rules, driven by the same seeded scenarios as the Jest suite, and
   keep Expo until the Godot build passes them.

If the phone build is poor (performance, controls, or export friction),
keep Expo for the strategy game and use what this prototype taught the
Expo climb (slopes, mantle, a larger connected level, light under rock).
