/// <reference types="jest" />

import { BARRANCO_LEVEL } from '@/features/climbing/levels/barranco';
import { createRuntime } from '@/features/climbing/runtime';
import { hintFor } from '@/features/climbing/hints';

function runtime() {
  return createRuntime({ level: BARRANCO_LEVEL, seed: 9, energy: 80, weatherRisk: 20, view: { width: 11, height: 20 }, now: () => 0 });
}

describe('climb runtime', () => {
  test('the simulation runs at 60 Hz whatever the display rate', () => {
    const fast = runtime();
    const slow = runtime();
    fast.press('right', true);
    slow.press('right', true);
    for (let i = 0; i < 120; i += 1) fast.advance(1 / 120, false, true);
    for (let i = 0; i < 30; i += 1) slow.advance(1 / 30, false, true);
    expect(fast.live().tick).toBe(60);
    expect(slow.live().tick).toBe(60);
    expect(fast.live().x).toBeCloseTo(slow.live().x, 6);
  });

  test('a long stall drops time instead of fast-forwarding through the wall', () => {
    const r = runtime();
    r.advance(5, false, true);
    expect(r.live().tick).toBeLessThanOrEqual(6);
  });

  test('frames are snapshots, not the live simulation', () => {
    const r = runtime();
    const before = r.frame();
    r.press('right', true);
    r.advance(0.5, false, true);
    expect(r.frame()).not.toBe(before);
    expect(before.sim.tick).toBe(0);
    expect(r.frame().sim.tick).toBeGreaterThan(0);
  });

  test('low-power rendering skips publishing but not simulating', () => {
    const r = runtime();
    const heard = jest.fn();
    r.subscribe(heard);
    r.advance(1 / 60, false, false);
    expect(heard).not.toHaveBeenCalled();
    expect(r.live().tick).toBe(1);
  });

  test('hints point at the next action', () => {
    const r = runtime();
    expect(hintFor(r.live())).toBeNull();
    r.press('right', true);
    for (let i = 0; i < 200 && r.live().x < 5.3; i += 1) r.advance(1 / 60, false, false);
    r.press('right', false);
    for (let i = 0; i < 20; i += 1) r.advance(1 / 60, false, false);
    expect(hintFor(r.live())).toMatch(/hold up/i);
  });
});
