/// <reference types="jest" />

import { SIM_DT, drainClock } from './clock';

describe('the climbing clock', () => {
  test('a 60 Hz frame is one simulation step', () => {
    const drained = drainClock(0, SIM_DT);
    expect(drained.steps).toBe(1);
    expect(drained.dt).toBe(SIM_DT);
    expect(drained.accumulator).toBeCloseTo(0, 6);
  });

  test('a long frame is capped so the simulation cannot spiral', () => {
    const drained = drainClock(0, 0.5);
    expect(drained.steps).toBe(4);
    expect(drained.dt).toBe(SIM_DT);
    expect(drained.accumulator).toBe(0);
  });

  test('the same span of time is the same steps however the frames arrive', () => {
    const fine = framesOf(1 / 60, 60);
    const coarse = framesOf(1 / 30, 30);
    expect(coarse.steps).toBe(fine.steps);
    expect(coarse.advanced).toBeCloseTo(fine.advanced, 6);
  });
});

function framesOf(frameDt: number, count: number) {
  let acc = 0;
  let steps = 0;
  let advanced = 0;
  for (let frame = 0; frame < count; frame += 1) {
    const drained = drainClock(acc, frameDt);
    acc = drained.accumulator;
    steps += drained.steps;
    advanced += drained.steps * drained.dt;
  }
  return { steps, advanced };
}
