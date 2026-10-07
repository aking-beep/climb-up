import { applyDecision, createExpedition, currentEvent, scoreExpedition } from '@/game/engine';
import type { ExpeditionDefinition, ExpeditionScore, ExpeditionState } from '@/game/types';

import { EVEREST_EVENTS } from './events';
import { EVEREST_DESCENT, EVEREST_DISCLAIMER, EVEREST_ROUTE } from './route';

export const everest: ExpeditionDefinition = {
  id: 'everest',
  title: 'Mount Everest',
  routeName: 'Simplified South Col route',
  disclaimer: EVEREST_DISCLAIMER,
  route: EVEREST_ROUTE,
  descentLadder: EVEREST_DESCENT,
  events: EVEREST_EVENTS,
};

export function startEverest(seed?: number): ExpeditionState {
  const resolved = seed ?? Math.floor(Math.random() * 1_000_000_000);
  return createExpedition(resolved, everest);
}

export function currentEverestEvent(state: ExpeditionState) {
  return currentEvent(state, everest);
}

export function chooseEverest(state: ExpeditionState, index: number): ExpeditionState {
  return applyDecision(state, index, everest);
}

export function scoreEverest(state: ExpeditionState): ExpeditionScore {
  return scoreExpedition(state);
}

export { EVEREST_DISCLAIMER, EVEREST_PROGRESS, EVEREST_ROUTE, checkpointName } from './route';
export { SME_REVIEW_IDS } from './events';
