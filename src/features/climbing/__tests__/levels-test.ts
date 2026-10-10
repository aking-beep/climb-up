/// <reference types="jest" />

import { LAVA_TOWER_LEVEL } from '@/features/climbing/levels/lavaTower';
import { SUMMIT_NIGHT_LEVEL } from '@/features/climbing/levels/summitNight';
import {
  HZ,
  NO_INPUT,
  command,
  createSim,
  gustAt,
  outcomeOf,
  step,
  type ClimbInput,
  type ClimbSim,
} from '@/features/climbing/sim';

const RIGHT: ClimbInput = { x: 1, y: 0, act: false };
const LEFT: ClimbInput = { x: -1, y: 0, act: false };
const UP: ClimbInput = { x: 0, y: 1, act: false };

function drive(sim: ClimbSim, input: ClimbInput | ((s: ClimbSim) => ClimbInput), done: (s: ClimbSim) => boolean, limit = 90 * HZ) {
  for (let i = 0; i < limit; i += 1) {
    if (done(sim)) return;
    step(sim, typeof input === 'function' ? input(sim) : input);
  }
  throw new Error(`Gave up at (${sim.x.toFixed(2)}, ${sim.y.toFixed(2)}) mode=${sim.mode} pose=${sim.pose} stamina=${sim.stamina.toFixed(0)} slips=${sim.slips}`);
}

/** Stand still until the arms come back. */
function rest(sim: ClimbSim, fraction = 0.9) {
  drive(sim, NO_INPUT, (s) => s.stamina >= s.maxStamina * fraction || s.mode !== 'play', 240 * HZ);
}

/** Walk only when the wind will stay calm for a moment. */
function patient(direction: ClimbInput) {
  return (s: ClimbSim) => (gustAt(s, s.tick + 1) === 'calm' && gustAt(s, s.tick + 12) === 'calm' ? direction : NO_INPUT);
}

describe('the Lava Tower', () => {
  test('parses with three cairns and no teammate', () => {
    expect(LAVA_TOWER_LEVEL.checkpoints).toHaveLength(4);
    expect(LAVA_TOWER_LEVEL.mate).toBeNull();
  });

  test('a careful climb reaches the top', () => {
    const sim = createSim({ level: LAVA_TOWER_LEVEL, seed: 5, energy: 85, weatherRisk: 25 });
    drive(sim, RIGHT, (s) => s.x >= 4.4);
    drive(sim, UP, (s) => s.y < 27.6);
    drive(sim, RIGHT, (s) => s.x >= 8.4 && s.grounded);
    drive(sim, UP, (s) => s.y < 26.6);
    drive(sim, RIGHT, (s) => s.x >= 15.4 && s.grounded);
    expect(sim.checkpoint).toBe(1);
    rest(sim);
    drive(sim, UP, (s) => s.y < 19.8);
    drive(sim, LEFT, (s) => s.x <= 14 && s.grounded);
    expect(sim.checkpoint).toBe(2);
    rest(sim);
    drive(sim, patient(LEFT), (s) => s.x <= 1.2);
    drive(sim, UP, (s) => s.y < 9.8);
    drive(sim, RIGHT, (s) => s.x >= 14.5);
    expect(sim.checkpoint).toBe(3);
    rest(sim);
    drive(sim, UP, (s) => s.y < 2.9);
    drive(sim, LEFT, (s) => s.mode === 'done');
    expect(sim.result).toBe('complete');
    expect(sim.slips).toBe(0);
    expect(outcomeOf(sim, 'a', 'lava-tower')).toMatchObject({ result: 'complete', assisted: null });
  });
});

describe('the summit night', () => {
  test('parses with five cairns and Jun on the fourth switchback', () => {
    expect(SUMMIT_NIGHT_LEVEL.checkpoints).toHaveLength(5);
    expect(SUMMIT_NIGHT_LEVEL.mate).toEqual({ x: 10.5, y: 15 });
  });

  test('the cold slows recovery', () => {
    const warm = createSim({ level: SUMMIT_NIGHT_LEVEL, seed: 1, energy: 80, weatherRisk: 20 });
    const cold = createSim({ level: SUMMIT_NIGHT_LEVEL, seed: 1, energy: 80, weatherRisk: 20, recovery: 0.55 });
    warm.stamina = 10;
    cold.stamina = 10;
    for (let i = 0; i < HZ; i += 1) {
      step(warm, NO_INPUT);
      step(cold, NO_INPUT);
    }
    expect(cold.stamina - 10).toBeCloseTo((warm.stamina - 10) * 0.55, 1);
  });

  test('a careful climb reaches Stella Point, helping Jun', () => {
    const sim = createSim({ level: SUMMIT_NIGHT_LEVEL, seed: 9, energy: 70, weatherRisk: 30, recovery: 0.55 });
    drive(sim, RIGHT, (s) => s.x >= 20.5);
    drive(sim, UP, (s) => s.y < 32.8);
    drive(sim, LEFT, (s) => s.x <= 19 && s.grounded);
    rest(sim);
    drive(sim, LEFT, (s) => s.x <= 1.2);
    expect(sim.checkpoint).toBe(1);
    drive(sim, UP, (s) => s.y < 26.8);
    drive(sim, RIGHT, (s) => s.x >= 20.5 && s.grounded);
    expect(sim.checkpoint).toBe(2);
    rest(sim);
    drive(sim, UP, (s) => s.y < 20.8);
    drive(sim, LEFT, (s) => s.x <= 19 && s.grounded);
    rest(sim);
    drive(sim, LEFT, (s) => s.x <= 1.2);
    expect(sim.checkpoint).toBe(3);
    drive(sim, UP, (s) => s.y < 14.8);
    drive(sim, RIGHT, (s) => s.mode !== 'play' || s.x >= 20.5);
    expect(sim.mode).toBe('mate');
    rest(sim);
    drive(sim, { x: 0, y: 0, act: true }, (s) => s.mode === 'decide');
    command(sim, { type: 'continue' });
    drive(sim, RIGHT, (s) => s.x >= 20.5 && s.grounded);
    expect(sim.checkpoint).toBe(4);
    rest(sim);
    drive(sim, UP, (s) => s.y < 8.8);
    drive(sim, LEFT, (s) => s.x <= 19 && s.grounded);
    rest(sim);
    drive(sim, patient(LEFT), (s) => s.x <= 1.2);
    drive(sim, UP, (s) => s.y < 2.9);
    drive(sim, RIGHT, (s) => s.mode === 'done');
    expect(sim.result).toBe('complete');
    expect(sim.slips).toBe(0);
    expect(outcomeOf(sim, 'a', 'summit-night')).toMatchObject({ result: 'complete', assisted: true });
  });
});
