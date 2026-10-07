/// <reference types="jest" />

import { EVEREST_DESCENT, EVEREST_ROUTE } from '@/expeditions/everest/route';
import { TERRAIN, TERRAIN_HEIGHT, TERRAIN_WIDTH, terrainFor } from '@/expeditions/everest/terrain';
import type { TerrainId } from '@/expeditions/everest/terrain';

const EXPECTED: Record<string, TerrainId> = {
  briefing: 'valley',
  approach: 'forest',
  ebc: 'moraine',
  camp1: 'icefall',
  camp2: 'glacier',
  camp3: 'face',
  camp4: 'col',
  summit: 'ridge',
};

describe('terrain', () => {
  test('each camp stands on different ground', () => {
    const ids = EVEREST_ROUTE.map((stop) => terrainFor(stop.id, stop.meters).id);
    expect(ids).toEqual(EVEREST_ROUTE.map((stop) => EXPECTED[stop.id]));
    expect(new Set(ids).size).toBe(EVEREST_ROUTE.length);
  });

  test('the descent walks back down through different ground', () => {
    const ids = EVEREST_DESCENT.map((meters) => terrainFor('descent', meters).id);
    expect(ids).toEqual(['col', 'face', 'glacier', 'icefall', 'moraine', 'forest', 'valley']);
    expect(terrainFor('complete', 1400).label).toBe('Valley floor');
  });

  test('the climber’s feet stay inside the scene', () => {
    for (const scene of Object.values(TERRAIN)) {
      for (const t of [0, 0.1, 0.5, 0.9, 1]) {
        const foot = scene.foot(t);
        expect(foot.x).toBeGreaterThanOrEqual(0);
        expect(foot.x).toBeLessThanOrEqual(TERRAIN_WIDTH);
        expect(foot.y).toBeGreaterThan(24);
        expect(foot.y).toBeLessThan(TERRAIN_HEIGHT);
      }
    }
  });
});
