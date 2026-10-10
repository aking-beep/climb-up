# Gameplay

How high you climb isn't how you win. A summit that does not come home is not a success. A careful retreat can outscore a rushed top.

The playable expedition is a fictional ten-day Lemosho on Kilimanjaro. Everest cards and scoring tests remain in the engine. The title screen starts Kilimanjaro.

## Two layers, one expedition

Most of the day is a decision: walk, sleep, a morning job, a night in camp. Those choices still resolve in the expedition engine immediately.

The Barranco Wall morning is the first section the player walks. It is a short fictional scramble, not the real wall, not a route description, and not climbing instruction.

The player:

- Reviews stamina, which starts from the expedition's energy.
- Walks the lower rock with Left and Right.
- Scrambles only inside a marked ledge. A scramble spends stamina and moves to the next shelf.
- Rests to recover stamina. Rest does not move the party up the mountain in the expedition until the scene ends.
- Meets Marco on the high ledge and chooses to stay, rest with him, or go on.
- Reaches the far checkpoint, comes back down, or falls three times.

Wind on the high ledge pushes back. One loose stone slows the party once. Three falls end the attempt. Coming back down is always available, including while paused.

## What the expedition records

| Scene result | Expedition |
| --- | --- |
| Finished | The original Karanga choice is applied once. Falls, heavy fatigue, or leaving Marco can add a short hold afterwards. Staying with Marco adds a teamwork mark. |
| Came back down | A hold at Barranco. The wall card is still there in the morning. |
| Three falls | A harder hold at Barranco. The wall card remains. |

The same attempt cannot be resolved twice. Repeating the scene after a retreat starts a new attempt. It does not stack the Karanga move.

## Controls

Portrait. One thumb on a direction is enough. Scramble and Rest are separate buttons, not a faster tap rate. Pause freezes the clock. Calm view uses the slower step and drops the foreground strip, wind streaks, and pose bob. Haptics mark a scramble, a fall, a retreat, and the end of the attempt. They are skipped when the device has none.

## Later modes

Expedition mode is this long journey. Other mountains can be new `ExpeditionDefinition` modules. Crag mode, if it is built later, should be another registered challenge: short, varied, and still reported once. Rope, knot, belay, and anchor teaching is out of scope until a qualified climber reviews it. This slice does not teach those skills.
