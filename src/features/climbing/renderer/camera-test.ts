/// <reference types="jest" />

import { ROCK_ROW, easeCamera, rockCrop } from './camera';

describe('the Barranco picture', () => {
  test('a ledge crop starts where the rock picture becomes solid', () => {
    const crop = rockCrop(120);
    expect(crop.top + ROCK_ROW * crop.imageH).toBeCloseTo(0, 5);
    expect(crop.imageH + crop.top).toBeGreaterThanOrEqual(120);
  });

  test('calm view eases the camera without changing the tracked point', () => {
    const calm = easeCamera(0, 100, 0.2, true);
    const full = easeCamera(0, 100, 0.2, false);
    expect(calm).toBe(100);
    expect(full).toBeGreaterThan(0);
    expect(full).toBeLessThan(100);
  });
});