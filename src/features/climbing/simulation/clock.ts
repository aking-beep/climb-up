/** Fixed simulation steps. Calm view does not change this clock. */
export const SIM_HZ = 60;
export const SIM_DT = 1 / SIM_HZ;

const MAX_FRAME = 0.25;
const MAX_STEPS = 4;

export function drainClock(
  accumulator: number,
  frameSeconds: number,
): { accumulator: number; steps: number; dt: number } {
  const dt = SIM_DT;
  let acc = Math.max(0, accumulator) + Math.max(0, Math.min(frameSeconds, MAX_FRAME));
  let steps = 0;
  while (acc + 1e-8 >= dt && steps < MAX_STEPS) {
    acc -= dt;
    steps += 1;
  }
  if (steps === MAX_STEPS && acc > dt) acc = 0;
  return { accumulator: Math.max(0, acc), steps, dt };
}
