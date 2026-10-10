/** Fixed simulation steps. The frame rate of the screen does not set the step size. */
export const SIM_HZ = 60;
export const SIM_DT = 1 / SIM_HZ;
export const CALM_HZ = 30;
export const CALM_DT = 1 / CALM_HZ;

const MAX_FRAME = 0.25;

export function drainClock(
  accumulator: number,
  frameSeconds: number,
  calm: boolean,
): { accumulator: number; steps: number; dt: number } {
  const dt = calm ? CALM_DT : SIM_DT;
  const maxSteps = calm ? 2 : 4;
  let acc = Math.max(0, accumulator) + Math.max(0, Math.min(frameSeconds, MAX_FRAME));
  let steps = 0;
  while (acc + 1e-8 >= dt && steps < maxSteps) {
    acc -= dt;
    steps += 1;
  }
  if (steps === maxSteps && acc > dt) acc = 0;
  return { accumulator: Math.max(0, acc), steps, dt };
}
