/// <reference types="jest" />

import { Tile, parseLevel, tileAt } from '@/features/climbing/level';
import { BARRANCO_LEVEL } from '@/features/climbing/levels/barranco';
import {
  HZ,
  NO_INPUT,
  TUNING,
  command,
  createSim,
  gustAt,
  maxStaminaFor,
  outcomeOf,
  step,
  type ClimbInput,
  type ClimbSim,
} from '@/features/climbing/sim';

function fresh(level = BARRANCO_LEVEL, energy = 88, weatherRisk = 20): ClimbSim {
  return createSim({ level, seed: 42, energy, weatherRisk });
}

/** Holds an input until `done` is true. Fails the test if it never is. */
function drive(sim: ClimbSim, input: ClimbInput | ((sim: ClimbSim) => ClimbInput), done: (sim: ClimbSim) => boolean, limit = 60 * HZ) {
  for (let i = 0; i < limit; i += 1) {
    if (done(sim)) return sim;
    step(sim, typeof input === 'function' ? input(sim) : input);
  }
  throw new Error(`Gave up at (${sim.x.toFixed(2)}, ${sim.y.toFixed(2)}) mode=${sim.mode} pose=${sim.pose} stamina=${sim.stamina.toFixed(1)} slips=${sim.slips}`);
}

const RIGHT: ClimbInput = { x: 1, y: 0, act: false };
const LEFT: ClimbInput = { x: -1, y: 0, act: false };
const UP: ClimbInput = { x: 0, y: 1, act: false };

/** A careful player: walks, scrambles, waits out the wind, helps Marco. */
function climbBarranco(sim: ClimbSim, onMate: 'help' | 'leave' = 'help') {
  // Camp, then the two boulders.
  drive(sim, RIGHT, (s) => s.x >= 5.3);
  drive(sim, UP, (s) => s.y < 31.5);
  drive(sim, RIGHT, (s) => s.x >= 9.3 && s.grounded);
  drive(sim, UP, (s) => s.y < 30.5);
  drive(sim, RIGHT, (s) => s.x >= 20.5 && s.grounded);
  expect(sim.checkpoint).toBe(1);
  // First face, to the small ledge.
  drive(sim, UP, (s) => s.y < 24.8);
  drive(sim, LEFT, (s) => s.x <= 19 && s.grounded);
  expect(sim.checkpoint).toBe(2);
  // Second face, to the exposed step.
  drive(sim, { x: 1, y: 1, act: false }, (s) => s.climbing);
  drive(sim, UP, (s) => s.y < 17.8);
  drive(sim, LEFT, (s) => s.x <= 19 && s.grounded);
  expect(sim.checkpoint).toBe(3);
  // The exposed step: only move in the calm.
  drive(sim, (s) => (gustAt(s, s.tick + 1) === 'calm' && gustAt(s, s.tick + 12) === 'calm' ? LEFT : NO_INPUT), (s) => s.x <= 1.2);
  // Left face, up to the high ledge.
  drive(sim, UP, (s) => s.y < 9.8);
  drive(sim, RIGHT, (s) => s.mode !== 'play' || s.x >= 14.5);
  expect(sim.mode).toBe('mate');
  expect(sim.checkpoint).toBe(4);
  if (onMate === 'help') {
    drive(sim, { x: 0, y: 0, act: true }, (s) => s.mode === 'decide');
    expect(sim.mate.state).toBe('helped');
  } else {
    command(sim, { type: 'leave-mate' });
  }
  command(sim, { type: 'continue' });
  // Loose gully to the top, then left to the exit.
  drive(sim, RIGHT, (s) => s.x >= 14.5);
  drive(sim, UP, (s) => s.y < 2.9);
  drive(sim, LEFT, (s) => s.mode === 'done');
  return sim;
}

describe('level parsing', () => {
  test('reads the Barranco map', () => {
    expect(BARRANCO_LEVEL.width).toBe(22);
    expect(BARRANCO_LEVEL.height).toBe(34);
    expect(BARRANCO_LEVEL.start).toEqual({ x: 1.5, y: 33 });
    expect(BARRANCO_LEVEL.checkpoints).toHaveLength(5);
    expect(BARRANCO_LEVEL.mate).toEqual({ x: 10.5, y: 10 });
    expect(tileAt(BARRANCO_LEVEL, -1, 5)).toBe(Tile.Rock);
    expect(tileAt(BARRANCO_LEVEL, 3, 99)).toBe(Tile.Rock);
    expect(tileAt(BARRANCO_LEVEL, 3, -4)).toBe(Tile.Air);
  });

  test('rejects broken maps', () => {
    expect(() => parseLevel('x', 'x', ['P.E', '..'])).toThrow(/row 1/);
    expect(() => parseLevel('x', 'x', ['P.?'])).toThrow(/unknown tile/);
    expect(() => parseLevel('x', 'x', ['..E'])).toThrow(/start/);
    expect(() => parseLevel('x', 'x', ['P..'])).toThrow(/exit/);
  });
});

describe('movement and collision', () => {
  test('the climber stands on rock and does not fall through the floor', () => {
    const sim = fresh();
    for (let i = 0; i < 120; i += 1) step(sim, NO_INPUT);
    expect(sim.y).toBe(33);
    expect(sim.grounded).toBe(true);
    expect(sim.pose).toBe('idle');
  });

  test('walking into a boulder stops at its face', () => {
    const level = parseLevel('wall', 'wall', ['......', '.P.#.E', '######']);
    const sim = fresh(level);
    for (let i = 0; i < 120; i += 1) step(sim, RIGHT);
    expect(sim.x).toBeCloseTo(3 - TUNING.width / 2, 5);
    expect(sim.pose).toBe('idle');
  });

  test('the level edge is a wall', () => {
    const sim = fresh();
    for (let i = 0; i < 120; i += 1) step(sim, LEFT);
    expect(sim.x).toBeCloseTo(TUNING.width / 2, 5);
  });

  test('climbing only happens on a face, and stops at its top', () => {
    const sim = fresh();
    step(sim, UP);
    expect(sim.climbing).toBe(false);
    drive(sim, RIGHT, (s) => s.x >= 5.3);
    drive(sim, UP, (s) => s.climbing);
    for (let i = 0; i < 3 * HZ; i += 1) step(sim, UP);
    // The face is rows 30–32; the feet stop where the hands run out.
    expect(sim.y).toBeGreaterThan(30);
    expect(sim.y).toBeLessThan(30.1);
    expect(sim.pose).toBe('climb');
  });

  test('a long fall is a slip back to the checkpoint', () => {
    const level = parseLevel('drop', 'drop', ['P....E', '##....', '......', '......', '......', '......', '######']);
    const sim = fresh(level);
    drive(sim, RIGHT, (s) => s.slipTicks > 0);
    expect(sim.slips).toBe(1);
    drive(sim, NO_INPUT, (s) => s.slipTicks === 0);
    expect(sim.x).toBe(level.start.x);
    expect(sim.y).toBe(level.start.y);
  });

  test('the simulation is deterministic', () => {
    const a = climbBarranco(fresh());
    const b = climbBarranco(fresh());
    expect(a.tick).toBe(b.tick);
    expect(a.stamina).toBe(b.stamina);
    expect(outcomeOf(a, 'x', 'barranco-wall')).toEqual(outcomeOf(b, 'x', 'barranco-wall'));
  });
});

describe('stamina', () => {
  test('the bar is sized by expedition energy', () => {
    expect(maxStaminaFor(100)).toBe(100);
    expect(maxStaminaFor(88)).toBe(95);
    expect(maxStaminaFor(0)).toBe(55);
  });

  test('hanging on a face drains it, standing gives it back, running out is a slip', () => {
    const sim = fresh();
    drive(sim, RIGHT, (s) => s.x >= 5.3);
    drive(sim, UP, (s) => s.climbing);
    const full = sim.stamina;
    for (let i = 0; i < HZ; i += 1) step(sim, NO_INPUT);
    expect(sim.pose).toBe('hang');
    expect(full - sim.stamina).toBeCloseTo(TUNING.drainHanging, 0);
    drive(sim, NO_INPUT, (s) => s.slipTicks > 0, 120 * HZ);
    expect(sim.stamina).toBe(0);
    drive(sim, NO_INPUT, (s) => s.slipTicks === 0);
    const low = sim.stamina;
    for (let i = 0; i < HZ; i += 1) step(sim, NO_INPUT);
    expect(sim.stamina - low).toBeCloseTo(TUNING.regenStill, 0);
  });

  test('three slips end the attempt as a failure', () => {
    const sim = fresh(BARRANCO_LEVEL, 0);
    drive(sim, RIGHT, (s) => s.x >= 5.3);
    for (let slip = 0; slip < 3; slip += 1) {
      drive(sim, RIGHT, (s) => s.x >= 5.3);
      drive(sim, UP, (s) => s.climbing);
      drive(sim, NO_INPUT, (s) => s.slipTicks > 0 || s.mode === 'done', 120 * HZ);
      drive(sim, NO_INPUT, (s) => s.slipTicks === 0);
    }
    expect(sim.mode).toBe('done');
    expect(sim.result).toBe('fail');
    expect(outcomeOf(sim, 'a', 'barranco-wall')?.result).toBe('fail');
  });
});

describe('wind on the exposed step', () => {
  test('gusts arrive on a fixed schedule set by the weather', () => {
    const calm = fresh(BARRANCO_LEVEL, 88, 0);
    const stormy = fresh(BARRANCO_LEVEL, 88, 100);
    expect(stormy.gustPeriod).toBeLessThan(calm.gustPeriod);
    const kinds = new Set(Array.from({ length: calm.gustPeriod }, (_, t) => gustAt(calm, t)));
    expect(kinds).toEqual(new Set(['calm', 'warn', 'blow']));
  });

  test('moving in a gust is a slip; standing still is not', () => {
    const level = parseLevel('step', 'step', ['P.NNNNNNNNNN.E', '##############']);
    const moving = fresh(level);
    drive(moving, RIGHT, (s) => s.slips > 0 || s.mode === 'done', 30 * HZ);
    expect(moving.slips).toBe(1);

    const still = fresh(level);
    drive(still, (s) => (gustAt(s, s.tick + 1) === 'calm' && gustAt(s, s.tick + 12) === 'calm' ? RIGHT : NO_INPUT), (s) => s.x >= 3.5);
    for (let i = 0; i < still.gustPeriod * 2; i += 1) step(still, NO_INPUT);
    expect(still.slips).toBe(0);
  });
});

describe('the Barranco Wall', () => {
  test('a careful climb completes, helping Marco', () => {
    const sim = climbBarranco(fresh());
    expect(sim.result).toBe('complete');
    expect(sim.slips).toBe(0);
    expect(sim.pose).toBe('celebrate');
    const outcome = outcomeOf(sim, 'attempt', 'barranco-wall');
    expect(outcome).toMatchObject({ result: 'complete', assisted: true, slips: 0, regrouped: false });
    expect(outcome!.seconds).toBeGreaterThan(30);
  });

  test('leaving Marco is reported', () => {
    const sim = climbBarranco(fresh(), 'leave');
    expect(outcomeOf(sim, 'a', 'barranco-wall')).toMatchObject({ result: 'complete', assisted: false });
  });

  test('helping Marco takes a sustained hold, not taps', () => {
    const sim = fresh();
    sim.mode = 'mate';
    for (let i = 0; i < 200; i += 1) step(sim, { x: 0, y: 0, act: i % 2 === 0 });
    expect(sim.mate.state).toBe('waiting');
    for (let i = 0; i < TUNING.helpTicks; i += 1) step(sim, { x: 0, y: 0, act: true });
    expect(sim.mate.state).toBe('helped');
  });

  test('regrouping restores stamina and costs time', () => {
    const sim = fresh();
    sim.mode = 'decide';
    sim.stamina = 10;
    command(sim, { type: 'regroup' });
    expect(sim.stamina).toBe(sim.maxStamina);
    expect(sim.regrouped).toBe(true);
    expect(sim.mode).toBe('play');
  });

  test('retreat is available at any time and is final', () => {
    const sim = fresh();
    for (let i = 0; i < 30; i += 1) step(sim, RIGHT);
    command(sim, { type: 'retreat' });
    expect(sim.mode).toBe('done');
    const before = sim.x;
    step(sim, RIGHT);
    expect(sim.x).toBe(before);
    expect(outcomeOf(sim, 'a', 'barranco-wall')).toMatchObject({ result: 'retreat', assisted: null });
  });

  test('no outcome until the attempt ends', () => {
    expect(outcomeOf(fresh(), 'a', 'barranco-wall')).toBeNull();
  });
});
