# CLIMB UP 2.0: the redesign in the game

The Magic Patterns redesign (branch `feature/magic-patterns-redesign`) is a
React/Vite prototype: screens, flows, tokens and copy. This page records how
it is built natively in the Godot game, what was adapted, and what is still
open.

## Where things are

- **Reference:** `design/magic-patterns/` holds the prototype exactly as
  uploaded (84 files, plus its own `README.md` and `package.json`).
  - The upload had overwritten the root `README.md` and `package.json`.
    Both were put back: the root `package.json` belongs to the frozen Expo
    app and drives the engine parity export (`tools/godot/export_content.ts`).
  - The prototype is not built or shipped. It is a spec to read.
- **Production:** everything playable is in `godot/`, built on the current
  game branch (alpine pitches, per-route maps, the quarter bar on the
  fastest way, rain).
  - The Build Codes in the request were written against `main@29e7e09`.
    They are adapted to this branch's APIs rather than copied in.

## Decisions

1. **One game, not two.** The redesign wraps the game that exists: new
   screens around the same climbing, scoring, styles, expedition engine and
   route maps. Nothing protected changes (AGENTS.md "Game rules are
   protected").
2. **Flags for anything that changes how a climb plays.** All flags are in
   `FeatureFlags` (`godot/core/flags/feature_flags.gd`):

   | Flag | Default | What it does |
   | --- | --- | --- |
   | `hub` | on | The hub is the front door. Off: the classic title (`modes/title/title.tscn`). |
   | `hero_in_climbs` | on | You and the team are drawn with the rig in every climb. The pixel sprites keep running unseen, because teammates follow their clips. |
   | `camp_world` | on | After a climb or a day, the party arrives in the walkable camp. Off: the camp board. |
   | `gear_effects` | on | Packed gear changes expedition climbs. Crag routes keep the crag's own shoe choice. |
   | `knowledge` | on | The climbing school, and the optional partner check in crag briefs. |
   | `expedition_achievements` | off | The prototype's proposed expedition achievements. They need a new record, so they are not built. |

3. **No new bitmaps.** New UI, the hub landscape, the climbers, the camp
   and the topos are drawn in code: `_draw`, polygons and gradients. The
   prototype's image URLs (CDN-hosted generated plates) are not used. They
   are not ours to ship, and they would break offline play.
4. **Real data only.** Profile numbers, achievements, the passport and the
   boards come from this phone's records, and from the records service when
   one is set. When there is nothing, the screen says so (for example "—"
   for no best). Nothing is simulated.
5. **Earned, never bought.** There is no payment integration, so there are
   no purchases, prices or currencies. Every lock is something you do
   (`core/profile/unlocks.gd`): stars, sends, achievements, a summit, an
   expedition finished, knowledge checks. `test_profile` checks that no
   catalogue entry mentions money.
6. **Knowledge checks are a game, labelled as one.** Every question shows
   "A game, not a lesson. Learn knots, belaying and anchors from a
   qualified instructor, in person, before you rely on them." The answers
   follow standard practice. Where the real answer depends on the
   situation, the card says it is simplified. Answering never changes a
   climb, its style or its score.

## What was built

| System | Files | Notes |
| --- | --- | --- |
| UI kit | `core/ui/ui_tokens.gd`, `ui_kit.gd`, `ui_icon.gd`, `journal_sheet.gd`, `journal_page.gd`, `segmented_tabs.gd`, `meter.gd`, `settings_sheet.gd` | Tokens from the prototype's `index.css`. Touch targets at least 22 px (48 dp). Safe-area pinning. Press squash and fades, instant with reduced motion. Drawn icons. |
| The climber | `core/hero/hero_rig.gd`, `hero.gd`, `team_looks.gd` | A port of the prototype's rig (`heroRig.ts`, `Hero.tsx`): 21 poses, two-bone IK, two body builds, ink outline, a key light, faces with expressions, all cosmetic layers. Lena, Marco, Jun and the camp crew use the same rig with fixed looks. |
| Profile | `core/profile/profile.gd` (autoload), `profile_data.gd`, `unlocks.gd`, `cosmetic_catalog.gd`, `equipment_catalog.gd`, `knowledge_checks.gd` | Own save file (`user://climb_up_profile.json`), validated on load. Progress is read from Crag and Records, never copied. |
| Hub | `modes/hub/hub.gd`, `hub_landscape.gd`, `world_map.gd` | The main scene. Parallax layers, the time of day from the phone's clock, the climber on the boulder (tap for profile), destination tags, Continue, today's route, records, settings. A first-time tip points at the lesson. The world map has 7 continents. Africa is playable; 11 other places are marked "not in the game yet". |
| Pages | `modes/profile/profile_screen.gd`, `locker_screen.gd`, `modes/crag/school_screen.gd` | Profile: numbers, achievements, passport. Locker: looks (swatches, locks with reasons) and gear (effects, trades). School: 14 cards on knots, belaying, anchors and clipping, and reading the route. |
| Expedition | `modes/expedition/picker.gd`, `prep.gd`, `briefing.gd`, `camp/camp_world.gd` | Picker: continue, or pick a route (days, bar size, the three climbs, the party). It asks before overwriting an expedition under way. Prep: Lena's briefing, read from each level's own spec, plus your pack and gear hints. Camp world: see below. |
| Gear in climbs | `modes/expedition/levels/climb_level.gd` (`kit`), `alpine.gd` | Walking, rock, wet rock, rest recovery, hits, rope rest, hauling and extra rests, each multiplied from `Profile.effects()`. |
| Crag | `modes/crag/crag_select.gd`, `route_topo.gd`, `crag_level.gd` (partner check) | The guidebook page: every route with its topo from its own map, bolting, exposure, crux, third-star challenge and the crag's shoes. The brief offers an optional partner check. |

### The walkable camp

Tap the ground to walk, or tap a person to walk up and talk. Arrows and E
work too. Every action is the expedition's own call, so the camp and the
board can't disagree:

| Who or what | What it does |
| --- | --- |
| Lena, at the map board | Today's decision (`Expedition.choose`). The first tap shows the risk, the second decides. Also the climb that waits (`resume_climb`) and, at the end, the scorecard. |
| Neema, the ranger | The weather briefing for the next climb (`Briefing`), with the gear that would help. |
| Baraka, the cook | The stores, and "put the water on" (`play_routine`). |
| Marco and Jun | How they are (`Party.members`, `Trek.sickness`), and what you can do for them: `tend`, `treat`, `medicate`, `send_down`. Jun also does the head count. |
| Juma, the porter | Your pack: swap gear between climbs. |
| Your tent | How you will feel on the next climb (`Condition`), what you carry, and a save. Camp is a checkpoint. Also "pole pole". |
| The signpost | The camp board, with everything on one page. |

People who went down are not in camp. The sky (cloud, rain, night) is a
pure function of the expedition state (`Briefing.sky`).

### Gear

The first item in each slot is the standard kit: open, no effect. Every
other item is a trade.

| Slot | Item | Effect | Opens with |
| --- | --- | --- | --- |
| Shoes | Stiff boots | walking −12%, climbing +8% | finish an expedition |
| Shoes | Rock shoes | climbing −10%, walking +12% | 2 stars on Warm-up Wall |
| Helmet | Alpine helmet | hits −25%, walking +3% | send Leap of Faith |
| Rope | Dry-treated rope | rope rest +40% | Iron arms |
| Rope | Thin rope | pulls cost −40%, rope rest −20% | Redpoint |
| Harness | Padded alpine | rope rest +25%, walking +2% | 6 stars |
| Clothing | Hard shell | wet rock's extra cost −40%, walking +4% | 3 knowledge checks |
| Clothing | Down layer | rests +20%, climbing +5% | reach the top of Kilimanjaro |
| Supplies | Energy gels | +1 rest, walking +4% | 10 stars |
| Supplies | Thermos of tea | rests +15%, walking +2% | 6 knowledge checks |

## API differences from the Build Codes

| Build Code assumes | This branch has |
| --- | --- |
| `leaderPoints` on a run | `points`, `summit`, `artifacts` (`Records.data["expedition"]`) |
| `Party.expedition_hour` is an int | float |
| `CampWidgets.STAT` in `core/ui` | `modes/expedition/camp/camp_widgets.gd` |
| `Artifacts.kept_total` | `Artifacts.kept_on(session, climb)` |
| `barranco.txt` map | per-route maps from `tools/levels/route_levels.py` |
| summit mate from the prototype | Jun (per-route people in `places.gd`) |
| title as the main scene | the hub (`modes/hub/hub.tscn`); the classic title stays reachable |
| `Crag.MENU` the menu | `Crag.MENU` is the guidebook page; `Crag.CLASSIC_MENU` is the old menu |
| `Expedition.MENU` the menu | `Expedition.MENU` is the picker; `Expedition.CLASSIC_MENU` the old menu |

## Protected and untouched

These are not changed:

- the expedition engine (`modes/expedition/engine/`) and `kilimanjaro.json`;
- the 178-step parity test;
- crag scoring and styles;
- the route maps and their hashes;
- achievements, the logbook and the daily route.

Tests guard these: `test_engine_parity`, `test_routes`, `test_logbook`,
`test_daily`, and `test_expedition_v2`. `test_expedition_v2` checks that a
choice made in the camp leaves the same session as the same choice on the
board.

## Tests added

| Test | What it covers |
| --- | --- |
| `test_hub.gd` | The main scene; everything on screen and a thumb tall, with no overlaps at 16:9 and 19.5:9; Continue; the tags; settings and the back button; the classic title flag. |
| `test_profile.gd` | Saving and loading; locks; no money in the catalogues; gear trades; the flag; knowledge counting; a corrupt file; real numbers; the pages; the school; the locker. |
| `test_hero.gd` | Finite, deterministic poses; hands reach the holds; IK keeps limb lengths; every look draws. |
| `test_expedition_v2.gd` | The picker; the overwrite check; briefings from the levels; the sky as a pure function; walking, talking and deciding (the same as the board); camp jobs; the porter; people sent down; the scorecard. |
| `test_gear.gd` | The standard kit changes nothing; packed gear changes the climb; the hard shell in rain; the dry rope on a pitch; the flag off. |
| `test_crag_v2.gd` | The guidebook page and its locks; topos match the maps; shoes; the partner check is optional and leaves the record untouched. |

## Not done, on purpose or for later

- **Crag clip v2** (Build Code 2: `ClipRules`, `fall_now`, rail, rope rest
  on request). It would change how crag routes score and which styles they
  earn, and the records service validates those. Not built. It needs a
  game-rules decision first.
- **Expedition achievements**: proposed in the prototype. They need a new
  persistent record and a records-service change. The flag stays off.
- **Barranco hold-choice faces and the summit-night breath/headlamp
  minigame** (Build Code 5): the existing played climbs (nine places,
  alpine pitches) already fill those slots. They were not replaced.
- **Device testing**: none of this has been played on a physical phone.
  Emulators and headless runs only.
