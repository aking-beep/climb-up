/// <reference types="jest" />

import {
  chooseKilimanjaro,
  currentKilimanjaroEvent,
  scoreKilimanjaro,
  startKilimanjaro,
} from '@/expeditions/kilimanjaro';
import { BARRANCO_WALL, kilimanjaroHybrid } from '@/expeditions/kilimanjaro/challenges';
import { KILI_EVENTS } from '@/expeditions/kilimanjaro/events';
import { abandon, choose, createSession, play, resolve } from '@/game/hybrid/coordinator';
import { MODIFIER_LIMITS, combineEffect } from '@/game/hybrid/reconcile';
import type { ChallengeOutcome, HybridSession } from '@/game/hybrid/types';
import type { ExpeditionState } from '@/game/types';

const TO_THE_WALL = [
  'Walk the forest and set camp',
  'Sleep under the trees',
  'Break camp and keep a patient pace',
  'Stake the tents and sleep',
  'Cross the plateau and pitch at Shira 2',
  'Sleep before the tower',
  'Tag the tower, then sleep low',
  'Sleep and leave the wall for morning',
];

function byLabel(state: ExpeditionState, label: string): number {
  const card = currentKilimanjaroEvent(state);
  const index = card.choices.findIndex((choice) => choice.label === label);
  if (index < 0) throw new Error(`"${label}" is not on ${card.id}`);
  return index;
}

function atTheWall(seed = 7): ExpeditionState {
  return TO_THE_WALL.reduce((state, label) => chooseKilimanjaro(state, byLabel(state, label)), startKilimanjaro(seed));
}

const CLIMB = 'Climb the wall and camp at Karanga';

function launched(seed = 7): HybridSession {
  const state = atTheWall(seed);
  const result = choose(kilimanjaroHybrid, createSession(kilimanjaroHybrid, state), byLabel(state, CLIMB));
  if (!result.launched) throw new Error('The wall did not launch.');
  return result.session;
}

function outcome(session: HybridSession, patch: Partial<ChallengeOutcome> = {}): ChallengeOutcome {
  return {
    attemptId: session.pending!.attemptId,
    challengeId: 'barranco-wall',
    result: 'complete',
    staminaLeft: 60,
    slips: 0,
    assisted: true,
    regrouped: false,
    seconds: 140,
    ...patch,
  };
}

describe('hybrid coordinator', () => {
  test('the registry points at a real card and a real choice', () => {
    const card = KILI_EVENTS.find((event) => event.id === BARRANCO_WALL.eventId);
    expect(card?.choices.map((choice) => choice.label)).toContain(BARRANCO_WALL.choiceLabel);
  });

  test('a plain choice is spent immediately, exactly as before', () => {
    const state = startKilimanjaro(7);
    const session = createSession(kilimanjaroHybrid, state);
    const result = choose(kilimanjaroHybrid, session, 0);
    expect(result.launched).toBeNull();
    expect(result.session.state).toEqual(chooseKilimanjaro(state, 0));
    expect(result.session.prior).toBe(state);
  });

  test('choosing the wall opens a pending challenge and leaves the state untouched', () => {
    const state = atTheWall();
    expect(currentKilimanjaroEvent(state).id).toBe('kili-wall');
    const session = createSession(kilimanjaroHybrid, state);
    const result = choose(kilimanjaroHybrid, session, byLabel(state, CLIMB));
    expect(result.launched?.challengeId).toBe('barranco-wall');
    expect(result.session.state).toBe(state);
    expect(result.session.pending?.historyLength).toBe(state.history.length);
  });

  test('the other wall choices are not playable', () => {
    const state = atTheWall();
    const session = createSession(kilimanjaroHybrid, state);
    const rest = choose(kilimanjaroHybrid, session, byLabel(state, 'Rest beneath the wall'));
    expect(rest.launched).toBeNull();
    expect(rest.session.state.seen).toContain('kili-wall');
  });

  test('a completed climb lands the card plus a bounded modifier, once', () => {
    const session = launched();
    const before = session.state;
    const { session: after, status } = resolve(kilimanjaroHybrid, session, outcome(session));
    expect(status).toBe('applied');
    expect(after.pending).toBeNull();
    expect(after.state.checkpoint).toBe('camp3');
    expect(after.state.seen).toContain('kili-wall');
    expect(after.state.history).toHaveLength(before.history.length + 1);
    expect(after.state.history.at(-1)?.choice).toBe(CLIMB);
    expect(after.state.marks['wall-assist']).toBe(true);
    expect(after.state.ledger.teamwork.map((note) => note.mark)).toEqual(
      expect.arrayContaining(['wall-team', 'wall-assist']),
    );

    // Same card choice without play, for comparison: the play only shades it.
    const plain = chooseKilimanjaro(before, byLabel(before, CLIMB));
    expect(after.state.checkpoint).toBe(plain.checkpoint);
    expect(after.state.altitude).toBe(plain.altitude);
    expect(Math.abs(after.state.teamCondition - plain.teamCondition)).toBeLessThanOrEqual(MODIFIER_LIMITS.statMax);
  });

  test('a duplicate outcome changes nothing', () => {
    const session = launched();
    const first = resolve(kilimanjaroHybrid, session, outcome(session));
    const again = resolve(kilimanjaroHybrid, first.session, outcome(session));
    expect(again.status).toBe('duplicate');
    expect(again.session).toBe(first.session);
  });

  test('an outcome for some other attempt is refused', () => {
    const session = launched();
    const wrong = resolve(kilimanjaroHybrid, session, outcome(session, { attemptId: 'made-up' }));
    expect(wrong.status).toBe('stale');
    expect(wrong.session).toBe(session);
  });

  test('an outcome for a state that has moved on is discarded, and the attempt closed', () => {
    const session = launched();
    // Some other path (an old build, a hand-edited save) moved the expedition on.
    const movedOn = { ...session, state: chooseKilimanjaro(session.state, byLabel(session.state, 'Rest beneath the wall')) };
    const result = resolve(kilimanjaroHybrid, movedOn, outcome(session));
    expect(result.status).toBe('stale');
    expect(result.session.state).toBe(movedOn.state);
    expect(result.session.pending).toBeNull();
    expect(result.session.resolvedAttempts).toContain(session.pending!.attemptId);
  });

  test('a malformed outcome is refused', () => {
    const session = launched();
    const bad = resolve(kilimanjaroHybrid, session, { ...outcome(session), result: 'teleport' as never });
    expect(bad.status).toBe('invalid');
    expect(bad.session.state).toBe(session.state);
  });

  test('a retreat keeps the team at Barranco and drops the summit-side scores', () => {
    const session = launched();
    const { session: after } = resolve(kilimanjaroHybrid, session, outcome(session, { result: 'retreat' }));
    expect(after.state.checkpoint).toBe('camp2');
    expect(after.state.altitude).toBe(session.state.altitude);
    expect(after.state.marks['wall-short']).toBeUndefined();
    expect(after.state.marks['wall-backoff']).toBe(true);
    expect(after.state.seen).toContain('kili-wall');
    // The way on is the ordinary route card now, not another free wall attempt.
    expect(currentKilimanjaroEvent(after.state).id).not.toBe('kili-wall');
  });

  test('backing off is never better than resting beneath the wall', () => {
    for (const seed of [7, 11, 23, 99, 1234]) {
      const session = launched(seed);
      const backedOff = resolve(kilimanjaroHybrid, session, outcome(session, { result: 'retreat' })).session.state;
      const before = session.state;
      const rested = chooseKilimanjaro(before, byLabel(before, 'Rest beneath the wall'));
      expect(backedOff.elapsedHours).toBeGreaterThanOrEqual(rested.elapsedHours);
      expect(backedOff.energy).toBeLessThanOrEqual(rested.energy);
      expect(backedOff.acclimatization).toBeLessThanOrEqual(rested.acclimatization);
      expect(backedOff.teamCondition).toBeLessThanOrEqual(rested.teamCondition);
      const total = (state: ExpeditionState) =>
        Object.values(state.ledger).flat().reduce((sum, note) => sum + note.delta, 0);
      expect(total(backedOff)).toBeLessThanOrEqual(total(rested));
    }
  });

  test('a failed climb is worse than backing off', () => {
    const session = launched();
    const failed = resolve(kilimanjaroHybrid, session, outcome(session, { result: 'fail', slips: 3 })).session.state;
    const backedOff = resolve(kilimanjaroHybrid, session, outcome(session, { result: 'retreat' })).session.state;
    expect(failed.health).toBeLessThan(backedOff.health);
    expect(failed.teamCondition).toBeLessThanOrEqual(backedOff.teamCondition);
  });

  test('a failed climb costs the team and stays low', () => {
    const session = launched();
    const { session: after } = resolve(kilimanjaroHybrid, session, outcome(session, { result: 'fail', slips: 3 }));
    expect(after.state.checkpoint).toBe('camp2');
    expect(after.state.health).toBeLessThan(session.state.health);
    expect(after.state.marks['wall-fail']).toBe(true);
  });

  test('abandoning the challenge resolves it as a retreat, once', () => {
    const session = launched();
    const first = abandon(kilimanjaroHybrid, session);
    expect(first.status).toBe('applied');
    expect(first.session.state.marks['wall-backoff']).toBe(true);
    const second = abandon(kilimanjaroHybrid, first.session);
    expect(second.status).toBe('stale');
  });

  test('camp beats are blocked while a challenge is pending', () => {
    const session = launched();
    const after = play(kilimanjaroHybrid, session, { note: 'tea', hours: 1, move: 'hold', energy: 5 });
    expect(after).toBe(session);
  });

  test('choosing again while pending returns the same attempt', () => {
    const session = launched();
    const again = choose(kilimanjaroHybrid, session, 0);
    expect(again.launched?.attemptId).toBe(session.pending?.attemptId);
    expect(again.session).toBe(session);
  });

  test('the attempt id is deterministic for the same expedition moment', () => {
    expect(launched(7).pending?.attemptId).toBe(launched(7).pending?.attemptId);
    expect(launched(7).pending?.seed).toBe(launched(7).pending?.seed);
  });

  test('the modifier cannot exceed its limits', () => {
    const effect = combineEffect(
      { note: 'base', energy: -8, move: 'up', hours: 12 },
      {
        note: 'greedy',
        stats: { energy: 50, health: -90 },
        hours: 400,
        keepBaseScores: true,
        scores: {
          judgment: { label: 'huge', delta: 999, mark: 'huge' },
          teamwork: { label: 'unmarked', delta: 5 },
        },
      },
    );
    expect(effect.energy).toBe(-8 + MODIFIER_LIMITS.statMax);
    expect(effect.health).toBe(MODIFIER_LIMITS.statMin);
    expect(effect.hours).toBe(12 + MODIFIER_LIMITS.hoursMax);
    expect(effect.scores?.judgment).toEqual({ label: 'huge', delta: MODIFIER_LIMITS.scoreMax, mark: 'huge' });
    expect(effect.scores?.teamwork).toBeUndefined();
    expect(effect.move).toBe('up');
  });

  test('the expedition still scores and finishes after a played wall', () => {
    const session = launched();
    let state = resolve(kilimanjaroHybrid, session, outcome(session)).session.state;
    for (let guard = 0; guard < 60 && state.status === 'active'; guard += 1) {
      const card = currentKilimanjaroEvent(state);
      const turn = card.choices.findIndex((choice) => /turn|down|walk out|sleep at mweka/i.test(choice.label));
      state = chooseKilimanjaro(state, turn >= 0 ? turn : 0);
    }
    expect(state.status).not.toBe('active');
    const score = scoreKilimanjaro(state);
    expect(score.overall).toBeGreaterThanOrEqual(0);
    expect(score.lines.filter((line) => line.label === 'You stopped for Marco on the wall')).toHaveLength(1);
  });
});
