import { applyDecision, applyEffect, createExpedition, currentEvent, scoreExpedition } from '@/game/engine';
import type { Effect, ExpeditionDefinition, ExpeditionScore, ExpeditionState } from '@/game/types';

import { KILI_EVENTS } from './events';
import { KILI_DESCENT, KILI_DISCLAIMER, KILI_ROUTE } from './route';

export const kilimanjaro: ExpeditionDefinition = {
  id: 'kilimanjaro',
  title: 'Kilimanjaro',
  routeName: 'Simplified 10-day Lemosho',
  disclaimer: KILI_DISCLAIMER,
  route: KILI_ROUTE,
  descentLadder: KILI_DESCENT,
  events: KILI_EVENTS,
};

export function startKilimanjaro(seed?: number): ExpeditionState {
  const resolved = seed ?? Math.floor(Math.random() * 1_000_000_000);
  return createExpedition(resolved, kilimanjaro);
}

export function currentKilimanjaroEvent(state: ExpeditionState) {
  return currentEvent(state, kilimanjaro);
}

export function chooseKilimanjaro(state: ExpeditionState, index: number): ExpeditionState {
  return applyDecision(state, index, kilimanjaro);
}

export function scoreKilimanjaro(state: ExpeditionState): ExpeditionScore {
  return scoreExpedition(state);
}

/** A morning or night beat. It does not spend the decision card. */
export function playKilimanjaro(state: ExpeditionState, effect: Effect | null): ExpeditionState {
  if (!effect || state.status !== 'active') return state;
  return applyEffect(state, effect, kilimanjaro);
}

export {
  KILI_DESCENT,
  KILI_DISCLAIMER,
  KILI_GATE,
  KILI_PROGRESS,
  KILI_ROUTE,
  KILI_SUMMIT,
  KNOWN_CAMPS,
  checkpointName,
  kiliCamping,
} from './route';
export { kiliGround } from './zones';
export { SME_REVIEW_IDS } from './events';
