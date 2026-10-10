# Gameplay spec

> How high you climb isn't how you win.

CLIMB UP scores judgment, preparation, teamwork, and getting home. The
expedition layer decides *whether* to climb. The playable layer decides *how*.
Neither should reward pressing on past the margin.

All numbers below are game tuning, not physiology or climbing advice. Scenes
flagged `review: 'sme'` in the event data, and any future rope, belay, or anchor
content, need review by qualified climbing specialists before anything is
presented as accurate.

## The loop

1. **Camp** (expedition screen). Read the field note, the team, and the
   stores. Optional camp beats (pole pole, water, head count, sitting with a
   struggling teammate) cost an hour and do not spend the card.
2. **Decide** (event card). Most choices resolve immediately. A choice marked
   **Playable climb** opens a challenge instead.
3. **Climb** (challenge screen). A short, controlled scene of 2–4 minutes.
   Movement, stamina, wind, and a teammate.
4. **Return**. The outcome lands on the expedition once: the card's own effect,
   shaded by how the climb went. Back at camp, the field note says what changed.

## Three climbs to the summit

The expedition cannot be summited by cards alone. Three camps are gated: every
way up out of them is a played climb. The cards still decide *how* (tag the
tower or skip it, start the summit on the night you arrive or after the rest
day), and the card's effects still apply; the climb decides whether the party
gets there today.

| Camp | Climb | What makes it hard |
| --- | --- | --- |
| Shira 2 | **The Lava Tower** (warm-up) | loose scree benches and a long scree gully; plateau wind on a ledge under an overhang; a chimney to the top. No teammate. |
| Barranco | **The Barranco Wall** (middle) | faces, an exposed step in the wind, Marco stuck on the high ledge, a loose gully. |
| Barafu | **Summit night** (final, hardest) | five frozen switchbacks by headlamp; Jun's hands have gone numb; the crater rim is open to the wind; Stella Point at first light. |

### Difficulty ramp

Each climb is harder than the one before, and the summit night is always the
hardest. The numbers live in `difficulty` on each scene (`scenes.ts`);
`difficulty-test.ts` fails if a later climb is not harder on every measure
(time on rock before the arms give out, time to get your breath back, how
often the gusts come, slips allowed, and how much climbable rock there is).

| | Lava Tower | Barranco Wall | Summit night |
| --- | --- | --- | --- |
| Stamina recovery | 100 % | 85 % | 55 % (cold) |
| Stamina drain on rock | × 0.85 | × 1.0 | × 1.25 |
| Wind (added to weather risk for gusts) | −15 | +5 | +30 |
| Slips before the attempt fails | 4 | 3 | 2 |
| Cost to help the teammate | – | 15 stamina | 22 stamina |
| Health per slip at camp (max) | −1 (−4) | −2 (−6) | −3 (−9) |
| A failed attempt | health −4, energy −3 | health −6, energy −4 | health −10, energy −6 |
| Helped the teammate | – | team +5, energy +3, teamwork +6 | team +6, energy +4, teamwork +8 |
| Left the teammate | – | team −6, teamwork −6 | team −10, teamwork −8 |

Back off or fail and the party stays at that camp, a day poorer. The next
morning's route card offers the way on again, and that launches the same climb.

## Barranco Wall

Card `kili-wall`, choice *Climb the wall and camp at Karanga*. The other two
choices (*Rest beneath the wall*, *Turn around in the valley*) still resolve
immediately, as before.

### Briefing

Shows the team's energy, the stamina it buys (`55 + energy × 0.45`, capped
55–100), team condition, and weather risk. *Start up the wall*, or
*Back off and stay at Barranco*, which resolves as a retreat.

### Route (the level, bottom to top)

| Section | Mechanic | Checkpoint |
| --- | --- | --- |
| Barranco Camp | walk; two boulders to scramble over | start |
| Approach | walk to the base of the wall | cairn 1 |
| First face | 8-tile scramble | cairn 2 on a small ledge |
| Second face | 7-tile scramble to the exposed step | cairn 3 |
| Exposed step | slow traverse under an overhang; gusts | – |
| Left face | 9-tile scramble | – |
| High ledge | rest stone; Marco; decision | cairn 4 |
| Loose gully | 8-tile scramble, 1.6× stamina drain | – |
| Top | walk to the marker toward Karanga | exit |

### Controls

- A four-way pad for one thumb. Every direction is **press and hold**.
- ▲ on a rock face grabs and climbs. ◀/▶ while climbing moves along the face,
  or off it onto a ledge. ▼ climbs down; ▼ on the ground lets go.
- No rapid tapping anywhere. Helping Marco is one tap: the help-up plays out
  over about 1.2 seconds, with a progress bar, and the same button stops it.
  Holding Space (web) or the context action does the same; letting go of a
  hold drains the progress (twice as fast as it builds).
- Every held direction is released whenever the screen changes mode (the
  teammate sheet, the decision, the end), so a finger left on the pad when a
  sheet opens never keeps the climber walking.
- Pause (top right, Android back, or Escape on web) opens: Resume, Back off the
  wall, and settings.
- Web/desktop testing: arrow keys or WASD, Space to help.

### Mechanics and tuning (`TUNING` in `sim.ts`)

| | Value |
| --- | --- |
| Walk / tired walk / exposed step | 3.0 / 2.0 / 1.3 tiles/s |
| Climb up / sideways | 2.0 / 1.5 tiles/s |
| Stamina drain climbing / hanging | 6 / 2 per s (× 1.6 on loose rock) |
| Stamina recovery still / walking / rest stone | 10 / 3 / 26 per s |
| "Tired" below | 30 stamina |
| Safe fall | 3.2 tiles; longer is a slip |
| Slips before the attempt fails | 3 |
| Help Marco | 72 ticks held, costs 15 stamina |
| Gust cycle | warn 1.5 s, blow 1.1 s, period 3.5–5.5 s (worse weather is shorter) |

**Slip:** a one-second stumble animation, then back to the last cairn with at
least half stamina. Haptic warning and a camera kick (none with reduced motion).

**Wind:** on the exposed step, a warning (streaks, haptic, hint "Wind coming.
Stop and brace.") precedes each gust. Standing still through a gust is safe
(the climber braces). Moving during one is a slip. This is a timing and
patience mechanic, not a reflex test: the warning is long and the schedule is
regular.

**Marco:** reaching the high ledge opens a choice:

The sheet spells out both prices: now (stamina) and at camp (team,
teamwork), taken from the same rules that will land the outcome.

- *Help Marco up*: costs 15 stamina; disabled below that, with "step back and
  rest first" (the rest stone is a few steps away). Marco then climbs behind
  you and **catches your next slip**: it does not count toward failing, and you
  come back at three quarters of your stamina instead of half. The HUD shows
  "Marco has your back" until he has caught one.
- *Leave Marco for Lena*: free now; you climb on alone, and it costs team
  condition and teamwork at camp.
- *Step back*: return to play; walk away and come back to reopen it. Climbing
  on past him without choosing counts as leaving him.

Then: *Keep climbing*, *Regroup here* (full stamina, half an hour of the day),
or *Turn back to Barranco*.

### Outcomes

The card's effect (move up to Karanga, 12 h, −8 energy, +4 acclimatization,
+2 team, *kept the wall day short* +6 judgment, *came off the wall together*
+4 teamwork) is combined with a bounded modifier:

| Result | Modifier on top of the card |
| --- | --- |
| **Complete** | slips: −2 health each (max −6). Under 25 % stamina: −4 energy. Helped Marco: +5 team, +3 energy, *stopped for Marco* +6 teamwork. Left Marco (or walked past him): −6 team, *left Marco for Lena* −6 teamwork. Regrouped: +2 energy, +1 h, *regrouped halfway* +3 judgment. |
| **Retreat** | stays at Barranco (`wait`: no camp-rest bonus), +12 h, +4 energy, −4 acclimatization, −2 team; card scores dropped; *backed off while it was your choice* +3 judgment |
| **Fail** (3 slips; caught slips don't count) | stays at Barranco (`wait`), +12 h, −6 health, −4 energy, −4 acclimatization, −4 team; card scores dropped; *the wall took more than the team had* −6 risk management |

Balance rules, enforced by tests:

- A challenge can never move the party higher than the card would.
- Per-stat modifier limits −12…+6, hours 0…12, score notes −8…+8, and every
  note carries a once-only mark.
- Backing off is never better than *Rest beneath the wall* on time, energy,
  acclimatization, team, or total score.
- A failed climb is worse than backing off.
- The card is spent once, whatever the result, so a challenge cannot be
  replayed for rewards. After a retreat the way on is the ordinary route card.

## Accessibility

- Press-and-hold for movement, never tapping speed. Helping a teammate is a
  single tap (tap again to stop), so it needs no sustained grip. The old
  *Tap instead of hold* setting is kept in saves but no longer shown.
- *Pad on the right* swaps the control side.
- *Reduced motion*: no camera shake, camera snaps instead of easing, no
  drifting clouds or particles.
- *Low power*: renders at half the display rate with less weather. The
  simulation is unaffected.
- 64 pt touch targets with hit slop; screen-reader labels and hints on every
  control; stamina is exposed as a progress bar with a value; hints are a
  polite live region.
- The HUD sits on a dark scrim and repeats stamina as text, so it does not rely
  on colour.

## Future: Crag mode (not started)

Short technical routes, separate from expeditions. Planned to reuse
`features/climbing` (sim, runtime, renderer) with a different level type:
hold-to-hold movement with body position and timing instead of free
scrambling. Route selection and progression would live outside the expedition
engine. No rope, belay, anchor, or knot content will be presented as
instruction without specialist review.
