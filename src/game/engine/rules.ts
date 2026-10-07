import type { ExpeditionState } from '@/game/types';
import { clamp } from '@/utils/number';

/** Game thresholds, not physiological facts. */
export function acclimatizationNeed(meters: number): number {
  if (meters < 3000) return 8;
  if (meters < 4500) return 28;
  if (meters < 5600) return 46;
  if (meters < 6600) return 62;
  if (meters < 7600) return 76;
  return 90;
}

export function altitudeStrain(acclimatization: number, meters: number): { health: number; energy: number } {
  const gap = acclimatizationNeed(meters) - acclimatization;
  if (gap > 30) return { health: -14, energy: -12 };
  if (gap > 12) return { health: -7, energy: -6 };
  return { health: 0, energy: 0 };
}

/** Combined pressure from weather, objective hazard, thin air, and fatigue. 0–100. */
export function pressure(state: ExpeditionState): number {
  const gap = Math.max(0, acclimatizationNeed(state.altitude) - state.acclimatization);
  const high = state.altitude >= 8000 ? 18 : state.altitude >= 7000 ? 10 : 0;
  return clamp(
    state.weatherRisk * 0.38 +
      state.objectiveRisk * 0.32 +
      gap * 0.2 +
      (100 - state.energy) * 0.1 +
      high,
    0,
    100,
  );
}

export function boundStat(value: number): number {
  return clamp(Math.round(value), 0, 100);
}

export function boundAltitude(value: number): number {
  return clamp(Math.round(value), 0, 8849);
}
