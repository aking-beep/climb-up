import type { CheckpointId, RouteStop } from '@/game/types';

/**
 * Simplified South Col camp altitudes for a game.
 * Real camps move with the season, the seracs, and the route.
 * Not a survey, and not for navigation. Needs specialist review
 * before any use outside this game.
 */
export const EVEREST_ROUTE: readonly RouteStop[] = [
  { id: 'briefing', name: 'Expedition briefing', meters: 1400 },
  { id: 'approach', name: 'Approach', meters: 3440 },
  { id: 'ebc', name: 'Everest Base Camp', meters: 5364 },
  { id: 'camp1', name: 'Camp I', meters: 6065 },
  { id: 'camp2', name: 'Camp II', meters: 6400 },
  { id: 'camp3', name: 'Camp III', meters: 7200 },
  { id: 'camp4', name: 'Camp IV', meters: 7900 },
  { id: 'summit', name: 'Summit attempt', meters: 8849 },
];

export const EVEREST_PROGRESS: readonly { id: CheckpointId; name: string }[] = [
  ...EVEREST_ROUTE.map((stop) => ({ id: stop.id, name: stop.name })),
  { id: 'descent', name: 'Descent' },
  { id: 'complete', name: 'Expedition complete' },
];

export const EVEREST_DESCENT: readonly number[] = [7900, 7200, 6400, 6065, 5364, 3440, 1400];

export const EVEREST_DISCLAIMER =
  'This is a simplified game about expedition judgment. It is not professional mountaineering instruction, a route description, or medical advice.';

export function checkpointName(id: CheckpointId): string {
  return EVEREST_PROGRESS.find((stop) => stop.id === id)?.name ?? 'Expedition';
}
