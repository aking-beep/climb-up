# Roadmap

The first slice is a Kilimanjaro day that can open a walkable Barranco scramble and write one result back. Later phases wait on that loop staying intact.

## In the tree

- Expedition engine, scoring, and the Everest tests.
- Kilimanjaro's ten-day fiction, camps, party jobs, and day and night cards.
- HD-2D camp diorama on the expedition screen.
- Hybrid coordinator, one challenge registry entry, and save version 1.
- Barranco simulation: walk, scramble, stamina, wind, one loose stone, Marco, checkpoints, retreat, three-fall failure.
- Layered morning picture on web. The same layers drawn with Skia on native.
- Single-image pose offsets. Not sprite sheets.
- Pause, Calm view, and haptics on the scramble screen.

## Not started

- Device frame-time profiles on iOS and Android. Calm view is the reduced mode. 60 steps a second is the simulation target, not a measured phone frame rate.
- Sound.
- More walkable sections: forest, plateau, summit night, descent.
- Further mountains: Everest as a playable route, Mont Blanc, Aconcagua, Denali, Cotopaxi, Chimborazo.
- Crag mode. The registry can hold another scene later. No hold, rope, or belay system is implemented.
- A Godot prototype. Do not start one until this Expo scene proves the collisions, camera, or lighting cannot stay maintainable. Do not embed Godot inside Expo, and do not keep two production sims.

## Order

Finish and play the Barranco loop before adding mountains or a second engine. A new scene should add a level, a registry row, and tests that the expedition card resolves once.
