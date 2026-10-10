/// <reference types="jest" />

import { createBarranco, stepClimb } from '@/features/climbing/simulation/barranco';
import { EMPTY_INPUT } from '@/features/climbing/simulation/types';

import { presentPose } from './poses';

describe('climber poses', () => {
  test('a single source image is offset, not played as a sprite sheet', () => {
    const idle = presentPose(createBarranco(80));
    expect(idle.id).toBe('idle');
    expect(idle.frameCount).toBe(1);
    expect(idle.fallback).toBe('single-image');

    const walking = presentPose({ action: 'walk', stamina: 70, seconds: 0.4 });
    const tired = presentPose({ action: 'walk', stamina: 10, seconds: 0.4 });
    const scramble = presentPose({ action: 'scramble', stamina: 70, seconds: 0.4 });
    expect(walking.frameCount).toBe(1);
    expect(tired.id).toBe('fatigue');
    expect(scramble.dy).not.toBe(idle.dy);
    expect(scramble.squash).toBeLessThan(1);
  });

  test('scrambling records the action for that step', () => {
    let world = createBarranco(80);
    for (let frame = 0; frame < 400 && world.action !== 'walk'; frame += 1) {
      world = stepClimb(world, { ...EMPTY_INPUT, right: true }, 1 / 30);
    }
    expect(world.action).toBe('walk');
    expect(presentPose(world).id).toBe('walk');
  });
});
