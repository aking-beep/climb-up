# Audio

Everything in `placeholder/` is **placeholder**: synthesized from noise and
tones by `tools/audio/placeholders.py`, project-owned, and meant to be
replaced with recorded or designed sound before release.

| Sound | Use | Wanted for release |
| --- | --- | --- |
| `step_dirt_*`, `step_rock_*` | footsteps by surface | real boots on dirt, scree, and rock; 6+ variations each |
| `grip_*` | a hand taking a hold | gloved hand on volcanic rock |
| `rockfall` | loose rock trickling away | small scree slides |
| `breath` | tired breathing | close-mic'd breaths at altitude, by effort |
| `slip` | a slip | scuff, slide, and impact on a pack |
| `chime`, `cairn` | interaction and cairn reached | a quiet, non-arcade cue |
| `wind_loop`, `gust` | wind on exposed ground | layered mountain wind with gust swells |
| `camp_loop` | Barranco Camp | camp: low voices, stove, fabric, distant wind |

Music is not a file: `core/audio/music_box.gd` makes it as it plays (soft
pads, a warm bass, a kalimba, bell or electric-piano line finding a melody
in the scale), one calm style per place: the camp, the Lava Tower, the
Barranco Wall, the summit night (it turns to a major key as the sun comes
up), the way down, and a lo-fi groove at the crag. It costs nothing to
ship and never repeats exactly. Footsteps, hops and hand sounds play under
it (`Audio.TRIM`). To hear the styles, render them:
`godot --headless --path godot --script res://tests/render_music.gd -- out=/tmp/music`.
