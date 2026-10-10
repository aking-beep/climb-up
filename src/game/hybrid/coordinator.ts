import { chooseKilimanjaro, currentKilimanjaroEvent, playKilimanjaro } from '@/expeditions/kilimanjaro';
import type { Effect, ExpeditionState } from '@/game/types';

import { challengeFor } from './challengeRegistry';
import type { ChallengeOutcome, PendingChallenge } from './types';

function attemptMark(attemptId: string): string {
  return `resolved-${attemptId}`;
}

function stamp(state: ExpeditionState, attemptId: string): ExpeditionState {
  const mark = attemptMark(attemptId);
  if (state.marks[mark]) return state;
  return { ...state, marks: { ...state.marks, [mark]: true } };
}

/** Opens a playable scene without spending the expedition card. */
export function beginChallenge(state: ExpeditionState, index: number): PendingChallenge | null {
  if (state.status !== 'active') return null;
  const card = currentKilimanjaroEvent(state);
  const choice = card.choices[index];
  if (!choice) return null;
  const spec = challengeFor(card.id, choice.id);
  if (!spec) return null;
  return {
    attemptId: `${spec.challengeId}-${state.seed}-${state.history.length}-${state.elapsedHours}`,
    challengeId: spec.challengeId,
    eventId: card.id,
    choiceId: spec.choiceId,
    choiceIndex: index,
  };
}

function followUp(outcome: ChallengeOutcome, mark: string): Effect | null {
  const left = outcome.hazardsEncountered.includes('left-marco');
  const helped = outcome.hazardsEncountered.includes('helped-marco');
  const messy = outcome.falls > 0 || left || outcome.staminaSpent > 70;
  if (!messy && !helped) return null;
  return {
    note: left
      ? 'Marco came off the scramble behind the rest of the party.'
      : helped
        ? 'You stayed with Marco until he was moving again.'
        : 'The scramble cost more than a clean pass.',
    hours: Math.min(2, outcome.falls),
    energy: messy ? -(8 + Math.min(8, outcome.falls * 4)) : 0,
    teamCondition: (left ? -6 : 0) + (helped ? 3 : 0),
    move: 'wait',
    mark,
    scores: helped
      ? {
          teamwork: {
            label: 'You stayed with Marco on the scramble',
            delta: 4,
            mark: 'wall-help',
          },
        }
      : undefined,
  };
}

/**
 * Writes the climb into the expedition a single time.
 * A retreat or a fall does not take the original "move up" choice.
 */
export function resolveChallenge(
  state: ExpeditionState,
  pending: PendingChallenge | null,
  outcome: ChallengeOutcome,
): ExpeditionState {
  if (!pending) return state;
  if (outcome.attemptId !== pending.attemptId) return state;
  if (outcome.challengeId !== pending.challengeId || outcome.choiceIndex !== pending.choiceIndex) return state;
  if (outcome.eventId !== pending.eventId || outcome.choiceId !== pending.choiceId) return state;
  if (outcome.result !== 'completed' && outcome.result !== 'retreated' && outcome.result !== 'failed') return state;
  const mark = attemptMark(outcome.attemptId);
  if (state.marks[mark]) return state;
  if (state.status !== 'active') return state;
  const card = currentKilimanjaroEvent(state);
  if (card.id !== pending.eventId) return state;
  const choice = card.choices[pending.choiceIndex];
  if (!choice || choice.id !== pending.choiceId) return state;

  if (outcome.result === 'completed') {
    const chosen = chooseKilimanjaro(state, pending.choiceIndex);
    const extra = followUp(outcome, mark);
    return extra ? playKilimanjaro(chosen, extra) : stamp(chosen, outcome.attemptId);
  }

  const gaveUp = outcome.result === 'retreated';
  return playKilimanjaro(state, {
    note: gaveUp
      ? 'You came back to the Barranco tents. The wall is still a morning decision.'
      : 'The scramble stopped the party. You are back among the tents.',
    hours: gaveUp ? 2 : 3,
    energy: gaveUp ? -10 : -16,
    health: gaveUp ? 0 : -3,
    teamCondition: gaveUp ? -2 : -6,
    move: 'wait',
    mark,
  });
}
