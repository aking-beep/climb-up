# Testing

Sprint start, 10 Oct 2026: pull requests 6 and 7 were open and unmerged. The latest commit was `3ac1a42` on `cursor/barranco-hd2d-f079`. `npm test` reported 45 passing tests before this polish pass.

From the repository root:

```bash
npm test
npm run typecheck
npm run lint
```

`npm test` runs Jest. Expedition tests cover the careful Kilimanjaro path, a rushed path, a summit that does not return, and party jobs that do not spend the day's card. Engine tests still cover Everest scoring. Do not change hold-at-altitude behavior to "fix" a scramble penalty. A hold at 3000 meters and above already adds energy.

Hybrid tests cover:

- Starting the wall does not spend the day.
- A clean finish camps at Karanga once. Resolving the same attempt again changes nothing.
- A retreat stays at Barranco and leaves the wall card in place.
- Leaving Marco costs more than staying.

Climbing tests cover walking, the ledge scramble, three falls, retreat, and an automatic careful pass that reaches the top with Marco helped. Pose tests assert `frameCount` is 1. Clock tests assert a 60 Hz step, a capped long frame, and the slower Calm step.

## Web

`npm run web`, then open the title. "Start the expedition" stays in the footer, not in the scrolling sheet. Resume, when a save exists, stays in the sheet.

A direct `/climb?code=` boots that seed. After the morning wall card, "Climb the wall and camp at Karanga" opens the scramble. The stage should show the rock plate, distant mountains, and clouds, not a brick grid. Move right spends stamina. Come back down returns to Barranco with the wall card still offered. Pause stops movement. Calm hides the foreground strip.

The scramble is fiction. Copy on the screen says it is not a route. Tests should keep that boundary: no water volumes, no medicine, no rope or knot instruction.

Native Skia is not what the web harness draws. Check a device build before calling the Skia canvas verified.
