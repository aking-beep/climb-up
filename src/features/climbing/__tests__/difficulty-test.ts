/// <reference types="jest" />

import { KILI_CHALLENGES } from '@/expeditions/kilimanjaro/challenges';
import { isClimbable } from '@/features/climbing/level';
import { CLIMB_ORDER, SCENES } from '@/features/climbing/scenes';
import { HZ, NO_INPUT, TUNING, createSim, step } from '@/features/climbing/sim';

const ENERGY = 75;
const WEATHER = 30;

/** Plain numbers for how hard a climb is, for the same party on the same day. */
function measure(id: (typeof CLIMB_ORDER)[number]) {
  const scene = SCENES[id];
  const sim = createSim({ level: scene.level, seed: 1, energy: ENERGY, weatherRisk: WEATHER, difficulty: scene.difficulty });
  // Seconds of moving on rock before the arms give out.
  const arms = sim.maxStamina / (TUNING.drainClimbing * sim.drain);
  // Seconds standing still to get from empty back to nine tenths.
  sim.stamina = 0;
  let ticks = 0;
  while (sim.stamina < sim.maxStamina * 0.9 && ticks < 600 * HZ) {
    step(sim, NO_INPUT);
    ticks += 1;
  }
  const rock = scene.level.tiles.filter((tile) => isClimbable(tile)).length;
  return { arms, breath: ticks / HZ, gustPeriod: sim.gustPeriod, slips: sim.maxSlips, helpCost: sim.helpCost, rock };
}

describe('the three climbs get harder, one after the other', () => {
  test('the climbs come in the order the expedition gates them', () => {
    const gates = ['camp1', 'camp2', 'camp3', 'camp4', 'camp5'];
    const byGate = [...KILI_CHALLENGES].sort((a, b) => gates.indexOf(a.gate) - gates.indexOf(b.gate)).map((c) => c.id);
    expect(byGate).toEqual([...CLIMB_ORDER]);
  });

  test('each climb is harder than the one before on every measure', () => {
    const [tower, wall, summit] = CLIMB_ORDER.map(measure);
    for (const [easier, harder] of [
      [tower, wall],
      [wall, summit],
    ]) {
      expect(harder.arms).toBeLessThan(easier.arms);
      expect(harder.breath).toBeGreaterThan(easier.breath);
      expect(harder.gustPeriod).toBeLessThan(easier.gustPeriod);
      expect(harder.slips).toBeLessThan(easier.slips);
      expect(harder.rock).toBeGreaterThan(easier.rock);
    }
  });

  test('the summit night is the final boss', () => {
    const all = CLIMB_ORDER.map(measure);
    const summit = all[all.length - 1];
    expect(CLIMB_ORDER[CLIMB_ORDER.length - 1]).toBe('summit-night');
    expect(summit.arms).toBe(Math.min(...all.map((m) => m.arms)));
    expect(summit.breath).toBe(Math.max(...all.map((m) => m.breath)));
    expect(summit.slips).toBe(2);
    expect(summit.helpCost).toBeGreaterThan(SCENES['barranco-wall'].difficulty.helpCost);
  });
});
