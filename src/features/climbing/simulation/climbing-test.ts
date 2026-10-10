/// <reference types="jest" />

import { activeScramble, createBarranco, stepClimb } from './barranco';
import { drainClock } from './clock';
import { EMPTY_INPUT, type ClimbInput, type ClimbWorld } from './types';

function hold(world: ClimbWorld, input: ClimbInput, seconds: number): ClimbWorld {
  let next = world;
  const frames = Math.round(seconds * 30);
  for (let frame = 0; frame < frames; frame += 1) next = stepClimb(next, input, 1 / 30);
  return next;
}

function auto(world: ClimbWorld): ClimbInput {
  if (world.phase.kind !== 'free') return EMPTY_INPUT;
  if (world.prompt) return { ...EMPTY_INPUT, help: true };
  if (world.stamina < 18 && world.onGround) return { ...EMPTY_INPUT, rest: true };
  if (activeScramble(world)) return { ...EMPTY_INPUT, scramble: true };
  return { ...EMPTY_INPUT, right: true };
}

describe('the Barranco scramble', () => {
  test('walking moves along the rock and spends stamina', () => {
    const start = createBarranco(80);
    const walked = hold(start, { ...EMPTY_INPUT, right: true }, 1.2);
    expect(walked.x).toBeGreaterThan(start.x + 40);
    expect(walked.onGround).toBe(true);
    expect(walked.stamina).toBeLessThan(start.stamina);
    expect(walked.falls).toBe(0);
  });

  test('a scramble climbs onto the next ledge instead of jumping there', () => {
    let world = createBarranco(80);
    for (let frame = 0; frame < 400 && !activeScramble(world); frame += 1) {
      world = stepClimb(world, { ...EMPTY_INPUT, right: true }, 1 / 30);
    }
    expect(activeScramble(world)?.id).toBe('lower-ledge');
    const started = stepClimb(world, { ...EMPTY_INPUT, scramble: true }, 1 / 30);
    expect(started.action).toBe('approach');
    expect(started.y).toBe(world.y);
    expect(started.stamina).toBe(world.stamina);
    let climbed = started;
    for (let frame = 0; frame < 90 && climbed.phase.kind === 'scramble'; frame += 1) {
      climbed = stepClimb(climbed, EMPTY_INPUT, 1 / 30);
    }
    expect(climbed.phase.kind).toBe('free');
    expect(climbed.y).toBeLessThan(world.y - 20);
    expect(climbed.onGround).toBe(true);
    expect(climbed.stamina).toBe(world.stamina - 8);
  });

  test('three falls end the attempt, and retreat stops it first', () => {
    let world = createBarranco(40);
    world = { ...world, y: 400, onGround: false };
    world = stepClimb(world, EMPTY_INPUT, 1 / 30);
    world = { ...world, y: 400, onGround: false };
    world = stepClimb(world, EMPTY_INPUT, 1 / 30);
    world = { ...world, y: 400, onGround: false };
    world = stepClimb(world, EMPTY_INPUT, 1 / 30);
    expect(world.failed).toBe(true);
    expect(world.falls).toBe(3);

    const quit = stepClimb(createBarranco(80), { ...EMPTY_INPUT, retreat: true }, 1 / 30);
    expect(quit.retreated).toBe(true);
    expect(quit.failed).toBe(false);
  });

  test('a careful pass can reach the top of the scramble', () => {
    let world = createBarranco(88);
    let guard = 0;
    while (!world.finished && !world.failed && guard < 8000) {
      world = stepClimb(world, auto(world), 1 / 30);
      guard += 1;
    }
    expect(world.failed).toBe(false);
    expect(world.finished).toBe(true);
    expect(world.hazards).toContain('helped-marco');
    expect(world.x).toBeGreaterThan(1400);
  });

  test('the same inputs land in the same place at two frame sizes', () => {
    const fine = play(1 / 60, 120);
    const coarse = play(1 / 30, 60);
    expect(coarse.x).toBeCloseTo(fine.x, 4);
    expect(coarse.stamina).toBeCloseTo(fine.stamina, 4);
    expect(coarse.y).toBeCloseTo(fine.y, 4);
  });

  test('rest cannot refill past the stamina the expedition brought', () => {
    let world = createBarranco(40);
    world = { ...world, stamina: 10 };
    const rested = hold(world, { ...EMPTY_INPUT, rest: true }, 30);
    expect(rested.stamina).toBeLessThanOrEqual(40);
    expect(rested.stamina).toBeGreaterThan(10);
    const high = hold({ ...createBarranco(90), stamina: 90 }, { ...EMPTY_INPUT, rest: true }, 10);
    expect(high.stamina).toBe(90);
  });

  test('a slip stays on the ledge when stamina is too low to climb', () => {
    let world = createBarranco(80);
    for (let frame = 0; frame < 400 && !activeScramble(world); frame += 1) {
      world = stepClimb(world, { ...EMPTY_INPUT, right: true }, 1 / 30);
    }
    world = { ...world, stamina: 4 };
    const slipped = stepClimb(world, { ...EMPTY_INPUT, scramble: true }, 1 / 30);
    expect(slipped.action).toBe('slip');
    expect(slipped.y).toBe(world.y);
  });
});

function play(frameDt: number, frames: number): ClimbWorld {
  let world = createBarranco(80);
  let accumulator = 0;
  const input = { ...EMPTY_INPUT, right: true };
  for (let frame = 0; frame < frames; frame += 1) {
    const drained = drainClock(accumulator, frameDt);
    accumulator = drained.accumulator;
    for (let step = 0; step < drained.steps; step += 1) world = stepClimb(world, input, drained.dt);
  }
  return world;
}
