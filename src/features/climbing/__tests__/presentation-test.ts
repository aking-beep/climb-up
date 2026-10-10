/// <reference types="jest" />

import { createCamera, followCamera, kick, parallax } from '@/features/climbing/camera';
import { CLIMBER_CLIPS, frameAt, frameRect } from '@/features/climbing/sprites';

describe('sprite animation', () => {
  test('a looping clip walks its frames by their own durations', () => {
    const walk = CLIMBER_CLIPS.walk;
    expect([0, 119, 120, 250, 380, 480].map((ms) => frameAt(walk, ms))).toEqual([2, 2, 3, 4, 5, 2]);
  });

  test('a one-shot clip holds its last frame', () => {
    expect(frameAt(CLIMBER_CLIPS.slip, 10_000)).toBe(15);
  });

  test('uneven durations are respected', () => {
    expect(frameAt(CLIMBER_CLIPS.idle, 699)).toBe(0);
    expect(frameAt(CLIMBER_CLIPS.idle, 700)).toBe(1);
  });

  test('every pose has distinct frames within the 27-frame sheet', () => {
    for (const clip of Object.values(CLIMBER_CLIPS)) {
      for (const frame of clip.frames) {
        expect(frame.index).toBeGreaterThanOrEqual(0);
        expect(frame.index).toBeLessThan(27);
        expect(frame.ms).toBeGreaterThan(0);
      }
    }
    expect(new Set(CLIMBER_CLIPS.climb.frames.map((frame) => frame.index)).size).toBe(4);
  });

  test('frame rectangles index the sheet grid', () => {
    expect(frameRect({ frameWidth: 16, frameHeight: 24, columns: 8 }, 9)).toEqual({ x: 16, y: 24, width: 16, height: 24 });
  });
});

describe('camera', () => {
  const view = { width: 12, height: 20 };
  const level = { width: 22, height: 34 };

  test('starts on the climber, inside the level', () => {
    const camera = createCamera({ x: 1.5, y: 33 }, view, level);
    expect(camera.x).toBe(6);
    expect(camera.y).toBe(24);
  });

  test('eases toward the climber and looks up while climbing', () => {
    const start = createCamera({ x: 10, y: 30 }, view, level);
    const moved = followCamera(start, { x: 10, y: 25, climbing: true, facing: 1 }, view, level, 1 / 60, false);
    expect(moved.y).toBeLessThan(start.y);
    expect(moved.y).toBeGreaterThan(22);
    const snapped = followCamera(start, { x: 10, y: 25, climbing: true, facing: 1 }, view, level, 1 / 60, true);
    expect(snapped.y).toBe(22);
  });

  test('reduced motion has no shake', () => {
    const camera = createCamera({ x: 10, y: 30 }, view, level);
    expect(kick(camera, 0.5, true).shake).toBe(0);
    expect(kick(camera, 0.5, false).shake).toBe(0.5);
  });

  test('distant layers move less than near ones', () => {
    const camera = { x: 10, y: 20, shake: 0 };
    expect(Math.abs(parallax(camera, 0.1, 30).y)).toBeLessThan(Math.abs(parallax(camera, 1.3, 30).y));
  });
});
