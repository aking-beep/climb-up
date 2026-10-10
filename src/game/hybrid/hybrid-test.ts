/// <reference types="jest" />

import {
  chooseKilimanjaro,
  currentKilimanjaroEvent,
  startKilimanjaro,
} from '@/expeditions/kilimanjaro';
import type { ExpeditionState } from '@/game/types';

import { beginChallenge, resolveChallenge } from './coordinator';
import type { ChallengeOutcome } from './types';

const TO_WALL = [
  'Walk the forest and set camp',
  'Sleep under the trees',
  'Break camp and keep a patient pace',
  'Stake the tents and sleep',
  'Cross the plateau and pitch at Shira 2',
  'Sleep before the tower',
  'Tag the tower, then sleep low',
  'Sleep and leave the wall for morning',
];

function chooseLabel(state: ExpeditionState, label: string): ExpeditionState {
  const card = currentKilimanjaroEvent(state);
  const index = card.choices.findIndex((choice) => choice.label === label);
  if (index < 0) throw new Error(`missing ${label}`);
  return chooseKilimanjaro(state, index);
}

function atTheWall(): ExpeditionState {
  return TO_WALL.reduce((state, label) => chooseLabel(state, label), startKilimanjaro(7));
}

function outcome(partial: Partial<ChallengeOutcome> & Pick<ChallengeOutcome, 'result'>): ChallengeOutcome {
  return {
    attemptId: partial.attemptId ?? '',
    challengeId: 'barranco-wall',
    eventId: 'kili-wall',
    choiceIndex: 0,
    elapsedSeconds: 40,
    staminaSpent: 20,
    falls: 0,
    hazardsEncountered: [],
    ...partial,
  };
}

describe('a playable choice', () => {
  test('the wall opens a challenge and does not spend the day', () => {
    const state = atTheWall();
    expect(currentKilimanjaroEvent(state).id).toBe('kili-wall');
    const pending = beginChallenge(state, 0);
    expect(pending?.challengeId).toBe('barranco-wall');
    expect(beginChallenge(state, 1)).toBeNull();
    expect(currentKilimanjaroEvent(state).id).toBe('kili-wall');
    expect(state.checkpoint).toBe('camp2');
  });

  test('a clean finish applies the camp move once', () => {
    const state = atTheWall();
    const pending = beginChallenge(state, 0)!;
    const done = resolveChallenge(state, pending, outcome({ result: 'completed', attemptId: pending.attemptId }));
    expect(done.checkpoint).toBe('camp3');
    expect(done.altitude).toBe(4035);
    expect(done.seen).toContain('kili-wall');
    const again = resolveChallenge(done, pending, outcome({ result: 'completed', attemptId: pending.attemptId }));
    expect(again.altitude).toBe(done.altitude);
    expect(again.history.length).toBe(done.history.length);
    expect(again.energy).toBe(done.energy);
  });

  test('coming back down leaves the morning decision in place', () => {
    const state = atTheWall();
    const pending = beginChallenge(state, 0)!;
    const back = resolveChallenge(state, pending, outcome({ result: 'retreated', attemptId: pending.attemptId }));
    expect(back.checkpoint).toBe('camp2');
    expect(back.altitude).toBe(3960);
    expect(back.seen).not.toContain('kili-wall');
    expect(currentKilimanjaroEvent(back).id).toBe('kili-wall');
    expect(back.energy).toBeLessThan(state.energy);
    const retry = beginChallenge(back, 0);
    expect(retry?.attemptId).not.toBe(pending.attemptId);
  });

  test('leaving Marco behind is written once, on top of the climb', () => {
    const state = atTheWall();
    const pending = beginChallenge(state, 0)!;
    const clean = resolveChallenge(state, pending, outcome({ result: 'completed', attemptId: pending.attemptId }));
    const hard = resolveChallenge(
      state,
      pending,
      outcome({
        result: 'completed',
        attemptId: pending.attemptId,
        falls: 1,
        hazardsEncountered: ['left-marco'],
        staminaSpent: 40,
      }),
    );
    expect(hard.energy).toBeLessThan(clean.energy);
    expect(hard.teamCondition).toBeLessThan(clean.teamCondition);
    expect(hard.ledger.teamwork.some((note) => note.mark === 'wall-team')).toBe(true);
  });
});
