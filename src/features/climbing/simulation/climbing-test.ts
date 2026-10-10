/// <reference types="jest" />

import { activeScramble, createBarranco, stepClimb } from './barranco';
import { EMPTY_INPUT, type ClimbInput, type ClimbWorld } from './types';

function hold(world: ClimbWorld, input: ClimbInput, seconds: number): ClimbWorld {
  let next = world;
  const frames = Math.round(seconds * 30);
  for (let frame = 0; frame < frames; frame += 1) next = stepClimb(next, input, 1 / 30);
  return next;
}

function auto(world: ClimbWorld): ClimbInput {
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

  test('a scramble lifts the party onto the next ledge', () => {
    let world = createBarranco(80);
    for (let frame = 0; frame < 400 && !activeScramble(world); frame += 1) {
      world = stepClimb(world, { ...EMPTY_INPUT, right: true }, 1 / 30);
    }
    expect(activeScramble(world)?.id).toBe('lower-ledge');
    const climbed = stepClimb(world, { ...EMPTY_INPUT, scramble: true }, 1 / 30);
    expect(climbed.y).toBeLessThan(world.y);
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
    while (!world.finished && !world.failed && guard < 5000) {
      world = stepClimb(world, auto(world), 1 / 30);
      guard += 1;
    }
    expect(world.failed).toBe(false);
    expect(world.finished).toBe(true);
    expect(world.hazards).toContain('helped-marco');
    expect(world.x).toBeGreaterThan(900);
  });
});
