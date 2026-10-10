/// <reference types="jest" />

import { PARTY, type Pose } from '@/components/world/scene';
import { KILI_PROGRESS } from '@/expeditions/kilimanjaro/route';
import { campProps, coverFit, partyLayout, pixelSize, routeLine, routeMarker, toView, ROUTE_MAP, type PlateMeta } from '@/features/world/layout';
import { MAP_CLIPS, PLATES, mapFrame, zoneFor } from '@/features/world/plates';

const META: PlateMeta = PLATES.rainforest.meta;

function order(poses: Pose[] = ['walk', 'walk', 'walk', 'walk']) {
  return PARTY.map((person, index) => ({ id: person.id, pose: poses[index] }));
}

describe('world layout', () => {
  test('every zone plate has a trail running up the plate and a camp on it', () => {
    for (const plate of Object.values(PLATES)) {
      const { trail, camp } = plate.meta;
      expect(trail.length).toBeGreaterThan(60);
      // Further along the trail is higher on the plate and smaller.
      expect(trail[trail.length - 1].y).toBeLessThan(trail[0].y);
      expect(trail[trail.length - 1].scale).toBeLessThan(trail[0].scale);
      expect(camp.x).toBeGreaterThan(0);
      expect(camp.x).toBeLessThan(1);
      expect(camp.y).toBeGreaterThan(0.3);
      expect(camp.y).toBeLessThan(1);
    }
  });

  test('the plate always covers the view', () => {
    for (const [w, h] of [
      [390, 310],
      [340, 270],
      [768, 400],
      [320, 480],
    ]) {
      const fit = coverFit(META, w, h);
      expect(fit.x).toBeLessThanOrEqual(0.001);
      expect(fit.y).toBeLessThanOrEqual(0.001);
      expect(fit.x + fit.width).toBeGreaterThanOrEqual(w - 0.001);
      expect(fit.y + fit.height).toBeGreaterThanOrEqual(h - 0.001);
    }
  });

  test('on the trail, the guide leads and the party is in view, nearer figures larger', () => {
    const fit = coverFit(META, 390, 310);
    const placed = partyLayout(META, fit, order(), { camping: false, retreating: false });
    expect(placed.map((p) => p.id)).toEqual(['lena', 'you', 'marco', 'jun']);
    for (const p of placed) {
      expect(p.x).toBeGreaterThan(0);
      expect(p.x).toBeLessThan(390);
      expect(p.y).toBeGreaterThan(0);
      expect(p.y).toBeLessThan(310);
      expect(p.frames).toBe('back');
    }
    for (let i = 1; i < placed.length; i += 1) expect(placed[i].px).toBeGreaterThanOrEqual(placed[i - 1].px);
  });

  test('a lagging walker drops back, a kneeling one kneels, and a retreat faces the camera', () => {
    const fit = coverFit(META, 390, 310);
    const steady = partyLayout(META, fit, order(), { camping: false, retreating: false });
    const tired = partyLayout(META, fit, order(['walk', 'lag', 'walk', 'walk']), { camping: false, retreating: false });
    const marco = (list: typeof steady) => list.find((p) => p.id === 'marco')!;
    expect(marco(tired).y).toBeGreaterThan(marco(steady).y);
    expect(marco(tired).tempo).toBeLessThan(1);
    const down = partyLayout(META, fit, order(['walk', 'kneel', 'walk', 'walk']), { camping: false, retreating: true });
    expect(marco(down).frames).toBe('kneel');
    expect(down.find((p) => p.id === 'lena')!.frames).toBe('front');
  });

  test('at camp everyone is near the fire, and the tents sit behind them', () => {
    const fit = coverFit(META, 390, 310);
    const placed = partyLayout(META, fit, order(), { camping: true, retreating: false });
    const fire = toView(fit, campProps(META).fire);
    for (const p of placed) expect(Math.hypot(p.x - fire.x, p.y - fire.y)).toBeLessThan(80);
    for (const tent of campProps(META).tents) expect(toView(fit, tent).y).toBeLessThan(fire.y);
  });

  test('sprite pixels stay in a readable range', () => {
    const fit = coverFit(META, 390, 310);
    expect(pixelSize(fit, 0)).toBeGreaterThan(0.4);
    expect(pixelSize(fit, 1)).toBeLessThanOrEqual(1.4);
  });

  test('the route map has every checkpoint, and the line starts at the gate', () => {
    for (const stop of KILI_PROGRESS) expect(ROUTE_MAP.some((item) => item.id === stop.id)).toBe(true);
    expect(routeLine()[0]).toEqual(routeMarker('briefing'));
    for (const point of routeLine()) {
      expect(point.x).toBeGreaterThan(0);
      expect(point.x).toBeLessThan(1);
    }
  });

  test('map sprites cycle through their clip frames', () => {
    expect(mapFrame('back', 0)).toBe(MAP_CLIPS.back.frames[0]);
    expect(mapFrame('back', MAP_CLIPS.back.ms)).toBe(MAP_CLIPS.back.frames[1]);
    expect(mapFrame('sit', 99999)).toBe(11);
    expect(zoneFor('rainforest')).toBe('rainforest');
    expect(zoneFor('snow')).toBe('snow');
  });
});
