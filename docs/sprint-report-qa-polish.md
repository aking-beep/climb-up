# Sprint: QA and polish (competitor review)

## What comparable games do, and what we took from it

| Game | What players and reviewers say | What it means for Climb Up | Done this sprint |
| --- | --- | --- | --- |
| **Cairn** (2026, The Game Bakers) | Stamina, warmth, food and water as survival gauges; clipping in or a camp restores and saves. The main complaint: the stamina system is too opaque, with too little feedback on grips. | Every number that can drop you must be visible before it does. Shelter and rest places should matter in the cold. | Rest stones shelter you from the cold (full rest, shown on the HUD). Climb results now say what each slip was and what to try next. |
| **Jusant** (2023, Don't Nod) | Forgiving falls: the rope and pitons cap what a fall costs, and slips rarely feel punishing. | Running out should give the player a moment to react, not a sudden drop. | Already in from the last round: empty arms hang on for 3 s with a warning. This sprint: a pause can no longer cancel a fall or skip the walk back. |
| **Crux** and mobile climbers (Climb!, Stickman Climb) | Simple two-button controls, quick onboarding, varied terrain, difficulty that rises for both casual and skilled players. | The first minute decides whether a new player stays. | The title screen now shows both modes in full on a phone (the second was hidden behind a scrollbar). Lesson tips moved to the top, so they no longer cover the climber or the CLIP button they point at. |
| **The Banner Saga / Oregon Trail** | Choices with weight and no obvious right answer; consequences that persist; travel speed traded against the caravan's needs. | The camp choices already carry into the climbs. They must stay readable. | Already in: the pre-climb breakdown. This sprint: the permit header no longer reads "0.0 days left". |
| **Mobile retention research (FTUE)** | Most churn happens on install day. Get players playing within about a minute; prefer learning by doing to walls of text. | Fix the first screens before anything else. | Title fit and tips on top (above), with tests. |

## QA: bugs found and fixed

A code audit plus hands-on first-run screenshots found these. Each fix has a test.

| Severity | Bug | Fix |
| --- | --- | --- |
| High | Pausing during a slip skipped the respawn. On the last slip it skipped the fail ending too, and you climbed on at "Slips 3/3". A hole fall under the pause menu counted twice. | A pause in the middle of a move (falling, slipping, mantling, helping) freezes it and carries on after. The hole check ignores the paused climber. |
| High | Crag daily: "Share today's result" left a screen with no buttons, and the app had to be killed. | The results come back straight away; the share card is made in the background. |
| High | Quitting after a hole fall, or before the first cairn, wiped the go on resume: slips, clock and the teammate you had helped. | Any go that has started (slips, time, a teammate) resumes. |
| Medium | Pausing mid-air cancelled a long fall; pausing mid-mantle dropped you off the lip; pausing while helping abandoned the help. | Same freeze-and-carry-on fix. Stones no longer hit you during the help animation. |
| Medium | The "this face takes N stamina" warning ignored the cold and fatigue, so it read about 18% low. | It now uses your real climbing speed. |
| Medium | Title and menus measured themselves before their text wrapped, which hid choices behind a scrollbar. | They measure again whenever the content changes. |
| Low | When your arms were empty, the hint said "get onto a ledge" while you could only climb down. | It says "Climb DOWN now". |
| Low | The weather line could read "0°C · freezing: 0% slower". | The words follow the shown number and never claim a 0% effect. |
| Low | Choosing medicine with an empty kit started the climb with no message. | It says "No dose left". |
| Low | The arms-failing flag outlived leaving the rock. | It is cleared on letting go. |

## Tests

138 passed, 0 failed (headless). New tests:
- menus fit;
- tips sit at the top;
- a pause never cancels a fall or a slip;
- a go with no cairn yet still resumes;
- share returns to the results;
- rest-stone shelter;
- slip coaching;
- the weather words match the number.

## Next sprint candidates

- Observe real players on a phone (the research's strongest advice); none of this was tested on a physical device.
- Expedition: a "best run" summary on the results screen (stars and everlastings per climb across expeditions).
- Crag: ghost of your best attempt's high point on the wall.
- Onboarding: a 30-second interactive opening climb before the first camp decision.

## Sources

- [Cairn review, The Outerhaven](https://www.theouterhaven.net/cairn-review-survive-the-climb/)
- [Cairn review, GameCritics](https://gamecritics.com/brad-gallaway/svg-review-cairn/)
- [Cairn review, Gaming Trend](https://gamingtrend.com/reviews/cairn-review/)
- [Jusant, Wikipedia](https://en.wikipedia.org/wiki/Jusant)
- [Jusant gets rock climbing right, Aftermath](https://aftermath.site/indie-game-jusant-gets-rock-climbing-right/)
- [Jusant design, Game Developer](https://gamasutra.com/design/unlocking-the-catharsis-of-climbing-in-meditative-puzzler-jusant)
- [Crux review, Gripped](https://gripped.com/?p=38543)
- [Best climbing games, Xbox Hub](https://www.thexboxhub.com/best-climbing-games-xbox/)
- [The Banner Saga interview, GameBanshee](https://gamebanshee.com/cy8u)
- [Mobile game onboarding and retention, Playio](https://blog.playio.co/mobile-game-onboarding-retention)
- [Perfecting the FTUE, PlaytestCloud](https://start.playtestcloud.com/blog/perfecting-the-first-time-user-experience-in-mobile-games)
