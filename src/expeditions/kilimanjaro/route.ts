import type { CheckpointId, RouteStop } from '@/game/types';

/**
 * Simplified 10-day Lemosho for a game.
 * Published itineraries differ by a hundred metres and by where they put
 * the rest days. These figures are not a survey, not a park route, and
 * not for navigation.
 *
 * The ten days, as this game tells them:
 * 1 Londorossi Gate to Mti Mkubwa
 * 2 Shira 1
 * 3 Shira 2, with a short walk above camp
 * 4 Lava Tower, then sleep at Barranco
 * 5 Barranco Wall to Karanga
 * 6 the extra day at Karanga
 * 7 Barafu
 * 8 the rest day at Barafu
 * 9 Uhuru, then down toward Mweka
 * 10 Mweka Gate
 */
export const KILI_ROUTE: readonly RouteStop[] = [
  { id: 'briefing', name: 'Londorossi Gate', meters: 2100 },
  { id: 'approach', name: 'Mti Mkubwa Camp', meters: 2780 },
  { id: 'ebc', name: 'Shira 1 Camp', meters: 3500 },
  { id: 'camp1', name: 'Shira 2 Camp', meters: 3850 },
  { id: 'camp2', name: 'Barranco Camp', meters: 3960 },
  { id: 'camp3', name: 'Karanga Camp', meters: 4035 },
  { id: 'camp4', name: 'Barafu Camp', meters: 4640 },
  { id: 'summit', name: 'Uhuru Peak', meters: 5895 },
];

export const KILI_SUMMIT = 5895;
export const KILI_GATE = 1640;

export const KILI_PROGRESS: readonly { id: CheckpointId; name: string }[] = [
  ...KILI_ROUTE.map((stop) => ({ id: stop.id, name: stop.name })),
  { id: 'descent', name: 'Descent' },
  { id: 'complete', name: 'Expedition complete' },
];

/** One long step to Mweka Camp, then the gate. */
export const KILI_DESCENT: readonly number[] = [3100, KILI_GATE];

export const KILI_DISCLAIMER =
  'This is a simplified game about a ten-day Kilimanjaro expedition. It is not a route description, a park itinerary, or medical advice.';

/**
 * Camps that show up on the usual Kilimanjaro routes.
 * Only the Lemosho sleeps above are played. The rest are named so the
 * mountain is not reduced to one path.
 */
export const KNOWN_CAMPS: readonly { name: string; meters: number; route: string }[] = [
  { name: 'Londorossi Gate', meters: 2100, route: 'Lemosho' },
  { name: 'Mti Mkubwa Camp', meters: 2780, route: 'Lemosho' },
  { name: 'Shira 1 Camp', meters: 3500, route: 'Lemosho' },
  { name: 'Shira 2 Camp', meters: 3850, route: 'Lemosho' },
  { name: 'Moir Hut', meters: 4200, route: 'Northern Circuit' },
  { name: 'Lava Tower', meters: 4630, route: 'Lemosho' },
  { name: 'Barranco Camp', meters: 3960, route: 'Lemosho, Machame, Umbwe' },
  { name: 'Karanga Camp', meters: 4035, route: 'Southern Circuit' },
  { name: 'Barafu Camp', meters: 4640, route: 'Lemosho, Machame' },
  { name: 'Kosovo Camp', meters: 4870, route: 'Western Breach' },
  { name: 'Stella Point', meters: 5756, route: 'Summit path' },
  { name: 'Uhuru Peak', meters: 5895, route: 'Summit' },
  { name: 'Millennium Camp', meters: 3820, route: 'Descent variant' },
  { name: 'Mweka Camp', meters: 3100, route: 'Mweka descent' },
  { name: 'Mweka Gate', meters: 1640, route: 'Mweka descent' },
  { name: 'Machame Gate', meters: 1800, route: 'Machame' },
  { name: 'Machame Camp', meters: 2835, route: 'Machame' },
  { name: 'Shira Camp', meters: 3750, route: 'Machame' },
  { name: 'Marangu Gate', meters: 1860, route: 'Marangu' },
  { name: 'Mandara Hut', meters: 2700, route: 'Marangu' },
  { name: 'Horombo Hut', meters: 3720, route: 'Marangu' },
  { name: 'Kibo Hut', meters: 4703, route: 'Marangu, Rongai' },
  { name: 'Rongai Gate', meters: 1950, route: 'Rongai' },
  { name: 'Simba Camp', meters: 2625, route: 'Rongai' },
  { name: 'Second Cave', meters: 3450, route: 'Rongai' },
  { name: 'Third Cave', meters: 3800, route: 'Rongai, Northern Circuit' },
  { name: 'School Hut', meters: 4800, route: 'Rongai, Northern Circuit' },
  { name: 'Buffalo Camp', meters: 4020, route: 'Northern Circuit' },
  { name: 'Umbwe Gate', meters: 1800, route: 'Umbwe' },
  { name: 'Umbwe Cave Camp', meters: 2850, route: 'Umbwe' },
  { name: 'Arrow Glacier Camp', meters: 4870, route: 'Western Breach' },
  { name: 'Crater Camp', meters: 5730, route: 'Not used in this game' },
];

export function checkpointName(id: CheckpointId): string {
  return KILI_PROGRESS.find((stop) => stop.id === id)?.name ?? 'Expedition';
}

export function kiliCamping(checkpoint: CheckpointId, altitude: number): boolean {
  if (checkpoint === 'briefing' || checkpoint === 'summit' || checkpoint === 'complete') return false;
  if (checkpoint === 'descent') return altitude >= 2800;
  return true;
}
