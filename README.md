# CLIMB UP

How high you climb isn't how you win.

A mobile mountaineering strategy and adventure game. The first expedition is
a simplified Kilimanjaro: you choose a route and a permit, make camp
decisions each day and night, and play three climbs on the way (the Lava
Tower, the Barranco Wall and the summit night) whose outcomes feed back into
the expedition. Reaching the summit is not the win. A careful retreat can
outscore a reckless summit, and a summit without a safe return is not a
successful expedition.

This is a simplified game about expedition judgment. It is not professional
mountaineering instruction, a route description, or medical advice.

## Two builds

**The Godot game ([`godot/`](godot/)) is where the game is now.** Landscape,
touch controls, web and Android builds. See [godot/README.md](godot/README.md)
for how to run it, what is in it and how it is tested.

- **Expedition:** the Kilimanjaro trip. Three routes with their own permits
  and stores, sickness per person, a medicine kit, people sent down for good
  (the camps remember them), seven endings. Every choice shows its hours,
  costs and a risk band before you pick it. The three climbs are played:
  stamina is the one bar, and sleep, food, sickness and the party's health
  set its size; thistles, siafu, ravens, stonefall, cracked slabs, ice, wind
  and rolling stones take from it.

**The Expo app (the repository root) is the original prototype:** the same
expedition engine in TypeScript, with the Barranco Wall as its one played
climb. The Godot engine is a port of it and is checked against it step for
step (the parity test). New work goes into Godot.

```bash
npm start            # the Expo prototype (Expo Go, or npm run web)
npm test
npm run typecheck
npm run lint
```

## Playtesting

[docs/playtest-checklist.md](docs/playtest-checklist.md) is a one-page
checklist for playing the Android build on a phone with touch only.

Design and architecture notes are in [`docs/`](docs/): start with
[hybrid-architecture.md](docs/hybrid-architecture.md) and
[development-roadmap.md](docs/development-roadmap.md).
