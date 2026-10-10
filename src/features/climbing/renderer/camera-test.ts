/// <reference types="jest" />

import { ROCK_ROW, rockCrop } from './camera';

describe('the Barranco picture', () => {
  test('a ledge crop starts where the rock picture becomes solid', () => {
    const crop = rockCrop(120);
    expect(crop.top + ROCK_ROW * crop.imageH).toBeCloseTo(0, 5);
    expect(crop.imageH + crop.top).toBeGreaterThanOrEqual(120);
  });
});