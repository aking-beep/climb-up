/// <reference types="jest" />

import { CALM_DT, SIM_DT, drainClock } from './clock';

describe('the climbing clock', () => {
  test('a 60 Hz frame is one simulation step', () => {
    const drained = drainClock(0, SIM_DT, false);
    expect(drained.steps).toBe(1);
    expect(drained.dt).toBe(SIM_DT);
    expect(drained.accumulator).toBeCloseTo(0, 6);
  });

  test('a long frame is capped so the simulation cannot spiral', () => {
    const drained = drainClock(0, 0.5, false);
    expect(drained.steps).toBe(4);
    expect(drained.dt).toBe(SIM_DT);
    expect(drained.accumulator).toBe(0);
  });

  test('calm mode takes fewer, longer steps', () => {
    const drained = drainClock(0, 0.1, true);
    expect(drained.dt).toBe(CALM_DT);
    expect(drained.steps).toBe(2);
    expect(drained.steps * drained.dt).toBeLessThanOrEqual(0.1 + 1e-6);
  });
});
