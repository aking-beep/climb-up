/// <reference types="jest" />

import {
  chooseEverest,
  currentEverestEvent,
  everest,
  startEverest,
} from '@/expeditions/everest';
import { EVEREST_EVENTS, SME_REVIEW_IDS } from '@/expeditions/everest/events';
import { altitudeStrain, applyEffect, pressure, scoreExpedition } from '@/game/engine';
import type { ExpeditionState } from '@/game/types';
import { STAT_KEYS } from '@/game/types';
import { hash } from '@/utils/number';

const CATEGORIES = [
  'weather',
  'acclimatization',
  'fatigue',
  'oxygen',
  'supplies',
  'team',
  'delay',
  'turnaround',
  'summit-window',
  'descent',
];

function trace(seed: number) {
  let state = startEverest(seed);
  const cards: string[] = [];
  for (let step = 0; step < 12 && state.status === 'active'; step += 1) {
    const card = currentEverestEvent(state);
    const index = hash(seed, step, card.choices.length) % card.choices.length;
    cards.push(`${card.id}#${index}`);
    state = chooseEverest(state, index);
  }
  return {
    cards,
    status: state.status,
    checkpoint: state.checkpoint,
    altitude: state.altitude,
    highestAltitude: state.highestAltitude,
    health: state.health,
    energy: state.energy,
    acclimatization: state.acclimatization,
    oxygen: state.oxygen,
    supplies: state.supplies,
    weatherRisk: state.weatherRisk,
    objectiveRisk: state.objectiveRisk,
    teamCondition: state.teamCondition,
    elapsedHours: state.elapsedHours,
    summitReached: state.summitReached,
    retreating: state.retreating,
    returnedSafely: state.returnedSafely,
    history: state.history.map((entry) => entry.choice),
    overall: state.status === 'active' ? null : scoreExpedition(state).overall,
  };
}

describe('expedition content', () => {
  test('Everest has a spread of prototype decisions, including scenes flagged for review', () => {
    expect(EVEREST_EVENTS.length).toBeGreaterThanOrEqual(20);
    const categories = new Set(EVEREST_EVENTS.map((event) => event.category));
    for (const category of CATEGORIES) expect(categories.has(category)).toBe(true);
    for (const event of EVEREST_EVENTS) {
      expect(event.choices.length).toBeGreaterThanOrEqual(2);
      expect(event.choices.length).toBeLessThanOrEqual(3);
    }
    expect(SME_REVIEW_IDS.length).toBeGreaterThan(0);
    for (const id of SME_REVIEW_IDS) {
      expect(EVEREST_EVENTS.find((event) => event.id === id)?.review).toBe('sme');
    }
  });
});

describe('decisions', () => {
  test('a decision records the choice and changes the expedition', () => {
    const start = startEverest(42);
    const event = currentEverestEvent(start);
    expect(event.checkpoints).toContain('briefing');

    const taken = chooseEverest(start, 0);
    const other = chooseEverest(start, 1);

    expect(taken.history).toHaveLength(1);
    expect(taken.history[0].choice).toBe(event.choices[0].label);
    expect(taken.seen).toContain(event.id);
    expect(taken.elapsedHours).toBeGreaterThan(start.elapsedHours);
    expect(taken.lastNote.length).toBeGreaterThan(0);
    expect(taken).not.toEqual(start);
    expect(other.history[0].choice).toBe(event.choices[1].label);
    expect(other.history[0].choice).not.toBe(taken.history[0].choice);
  });

  test('altitude, time, and resources follow the effect', () => {
    const start = startEverest(9);
    const climbed = applyEffect(start, { note: 'The approach begins.', hours: 2, move: 'up' }, everest);
    expect(climbed.checkpoint).toBe('approach');
    expect(climbed.altitude).toBeGreaterThan(start.altitude);
    expect(climbed.highestAltitude).toBe(climbed.altitude);
    expect(climbed.elapsedHours).toBe(2);

    const rested = applyEffect(
      climbed,
      { note: 'A rest day.', hours: 1, move: 'hold' },
      everest,
    );
    expect(rested.acclimatization).toBe(climbed.acclimatization + 8);

    const waited = applyEffect(climbed, { note: 'The step failed.', hours: 1, move: 'wait' }, everest);
    expect(waited.acclimatization).toBe(climbed.acclimatization);
    expect(waited.altitude).toBe(climbed.altitude);
    expect(waited.checkpoint).toBe(climbed.checkpoint);
    expect(waited.lastNote).not.toContain('catch the altitude');

    const spent = applyEffect(
      start,
      { note: 'Cache opened.', hours: 4, move: 'hold', supplies: -8, oxygen: 5 },
      everest,
    );
    expect(spent.supplies).toBe(start.supplies - 10);
    expect(spent.oxygen).toBe(start.oxygen + 5);
    expect(spent.lastNote).toContain('Cache opened.');
  });
});

describe('bounds', () => {
  test('meters and resources stay inside their ranges, including a hard drain', () => {
    let state = startEverest(3);
    state = applyEffect(
      state,
      {
        note: 'Everything spikes.',
        hours: 0,
        move: 'hold',
        health: 500,
        energy: 500,
        acclimatization: 500,
        oxygen: 500,
        supplies: 500,
        weatherRisk: 500,
        objectiveRisk: 500,
        teamCondition: 500,
      },
      everest,
    );
    for (const key of STAT_KEYS) {
      expect(state[key]).toBeGreaterThanOrEqual(0);
      expect(state[key]).toBeLessThanOrEqual(100);
    }

    state = applyEffect(
      state,
      {
        note: 'The cache is empty.',
        hours: 0,
        move: 'hold',
        supplies: -500,
        oxygen: -500,
        energy: -500,
      },
      everest,
    );
    expect(state.supplies).toBe(0);
    expect(state.oxygen).toBe(0);
    expect(state.energy).toBe(0);
    expect(state.health).toBeGreaterThan(0);

    let walked = startEverest(77);
    for (let step = 0; step < 40 && walked.status === 'active'; step += 1) {
      const card = currentEverestEvent(walked);
      walked = chooseEverest(walked, step % card.choices.length);
      for (const key of STAT_KEYS) {
        expect(walked[key]).toBeGreaterThanOrEqual(0);
        expect(walked[key]).toBeLessThanOrEqual(100);
      }
      expect(walked.altitude).toBeGreaterThanOrEqual(0);
      expect(walked.altitude).toBeLessThanOrEqual(8849);
      expect(walked.highestAltitude).toBeGreaterThanOrEqual(walked.altitude);
      expect(walked.highestAltitude).toBeLessThanOrEqual(8849);
    }
  });

  test('altitude strain and pressure stay predictable', () => {
    expect(altitudeStrain(10, 8849)).toEqual({ health: -14, energy: -12 });
    expect(altitudeStrain(90, 2000)).toEqual({ health: 0, energy: 0 });

    const calm = startEverest(1);
    const stressed: ExpeditionState = {
      ...calm,
      weatherRisk: 100,
      objectiveRisk: 100,
      energy: 0,
      altitude: 8849,
      acclimatization: 0,
    };
    expect(pressure(calm)).toBeGreaterThanOrEqual(0);
    expect(pressure(calm)).toBeLessThan(40);
    expect(pressure(stressed)).toBe(100);
  });
});

describe('retreat, summit, and the score', () => {
  test('turning around brings a living team home', () => {
    let state = startEverest(11);
    state = applyEffect(state, { note: 'Approach', hours: 6, move: 'up', acclimatization: 12 }, everest);
    state = applyEffect(state, { note: 'Base camp', hours: 8, move: 'up', acclimatization: 16 }, everest);
    expect(state.checkpoint).toBe('ebc');
    expect(state.summitReached).toBe(false);

    state = applyEffect(
      state,
      {
        note: 'You turn the expedition around.',
        hours: 6,
        move: 'retreat',
        scores: {
          judgment: {
            label: 'You turned around while the way down still existed',
            delta: 22,
            mark: 'turned',
          },
          riskManagement: { label: 'You left before the margin was gone', delta: 16, mark: 'turned-risk' },
          teamwork: { label: 'The team left together', delta: 8, mark: 'team-left' },
        },
      },
      everest,
    );
    expect(state.retreating).toBe(true);
    expect(state.summitReached).toBe(false);

    let guard = 0;
    while (state.status === 'active' && guard < 8) {
      state = applyEffect(state, { note: 'Down', hours: 6, move: 'down', energy: 3, teamCondition: 1 }, everest);
      guard += 1;
    }

    expect(state.status).toBe('complete');
    expect(state.returnedSafely).toBe(true);
    expect(state.summitReached).toBe(false);
    expect(state.checkpoint).toBe('complete');
    const score = scoreExpedition(state);
    expect(score.successful).toBe(true);
    expect(score.returnedSafely).toBe(true);
    expect(score.overall).toBeGreaterThan(70);
  });

  test('a summit by itself is not a high score and is not a success', () => {
    const lost = scoreExpedition({
      ...startEverest(1),
      summitReached: true,
      highestAltitude: 8849,
      altitude: 8849,
      checkpoint: 'summit',
      status: 'failed',
      returnedSafely: false,
    });
    expect(lost.summitReached).toBe(true);
    expect(lost.returnedSafely).toBe(false);
    expect(lost.successful).toBe(false);
    expect(lost.overall).toBeLessThan(50);
    expect(lost.overall).toBeLessThanOrEqual(36);
    expect(lost.explanation).toMatch(/not a success/i);
  });

  test('the same ledger scores much higher after a safe descent', () => {
    const base = startEverest(3);
    const shared: ExpeditionState = {
      ...base,
      summitReached: true,
      highestAltitude: 8849,
      health: 64,
      energy: 50,
      teamCondition: 72,
      supplies: 48,
      oxygen: 40,
      ledger: {
        judgment: [{ label: 'Measured pace', delta: 18 }],
        riskManagement: [{ label: 'Margin kept', delta: 10 }],
        teamwork: [{ label: 'The team stayed together', delta: 6 }],
        preparation: [],
      },
    };
    const home = scoreExpedition({
      ...shared,
      status: 'complete',
      returnedSafely: true,
      altitude: 1400,
      checkpoint: 'complete',
    });
    const stuck = scoreExpedition({
      ...shared,
      status: 'failed',
      returnedSafely: false,
      altitude: 7200,
      checkpoint: 'descent',
    });

    expect(home.returnedSafely).toBe(true);
    expect(stuck.returnedSafely).toBe(false);
    expect(stuck.successful).toBe(false);
    expect(home.overall).toBeGreaterThan(stuck.overall + 15);
    expect(stuck.overall).toBeLessThanOrEqual(36);
  });

  test('a reckless summit scores below an intelligent retreat', () => {
    let reckless = startEverest(5);
    let guard = 0;
    while (reckless.checkpoint !== 'summit' && reckless.status === 'active' && guard < 10) {
      reckless = applyEffect(
        reckless,
        {
          note: 'Up.',
          hours: 4,
          move: 'up',
          acclimatization: 20,
          health: 4,
          energy: 4,
          scores:
            guard === 0
              ? {
                  judgment: {
                    label: 'You kept climbing with the descent already in doubt',
                    delta: -16,
                    mark: 'reckless',
                  },
                  riskManagement: { label: 'You spent the margin on the way up', delta: -14, mark: 'spent-margin' },
                }
              : undefined,
        },
        everest,
      );
      guard += 1;
    }
    expect(reckless.summitReached).toBe(true);
    reckless = applyEffect(
      reckless,
      { note: 'The descent does not happen.', hours: 2, move: 'hold', health: -100, teamCondition: -100 },
      everest,
    );
    const recklessScore = scoreExpedition(reckless);
    expect(recklessScore.summitReached).toBe(true);
    expect(recklessScore.returnedSafely).toBe(false);
    expect(recklessScore.successful).toBe(false);
    expect(recklessScore.overall).toBeLessThanOrEqual(36);

    let retreat = startEverest(11);
    retreat = applyEffect(retreat, { note: 'Approach', hours: 6, move: 'up', acclimatization: 12 }, everest);
    retreat = applyEffect(retreat, { note: 'Base camp', hours: 8, move: 'up', acclimatization: 16 }, everest);
    retreat = applyEffect(
      retreat,
      {
        note: 'You turn the expedition around.',
        hours: 6,
        move: 'retreat',
        scores: {
          judgment: {
            label: 'You turned around while the way down still existed',
            delta: 22,
            mark: 'turned',
          },
          riskManagement: { label: 'You left before the margin was gone', delta: 16, mark: 'turned-risk' },
          teamwork: { label: 'The team left together', delta: 8, mark: 'team-left' },
        },
      },
      everest,
    );
    guard = 0;
    while (retreat.status === 'active' && guard < 8) {
      retreat = applyEffect(retreat, { note: 'Down', hours: 6, move: 'down', energy: 3, teamCondition: 1 }, everest);
      guard += 1;
    }
    const retreatScore = scoreExpedition(retreat);
    expect(retreatScore.summitReached).toBe(false);
    expect(retreatScore.returnedSafely).toBe(true);
    expect(retreatScore.successful).toBe(true);
    expect(retreatScore.overall).toBeGreaterThan(recklessScore.overall + 20);

    const strongSummit = scoreExpedition({
      ...startEverest(8),
      status: 'complete',
      summitReached: true,
      returnedSafely: true,
      highestAltitude: 8849,
      altitude: 1400,
      checkpoint: 'complete',
      health: 70,
      teamCondition: 80,
      supplies: 70,
      oxygen: 65,
      ledger: {
        judgment: [{ label: 'The summit bid still had a descent', delta: 30 }],
        riskManagement: [{ label: 'The window was real', delta: 12 }],
        teamwork: [{ label: 'Everyone who went up came down', delta: 8 }],
        preparation: [],
      },
    });
    expect(strongSummit.successful).toBe(true);
    expect(strongSummit.overall).toBeGreaterThan(retreatScore.overall);
    expect(strongSummit.overall).toBeGreaterThan(recklessScore.overall);
  });
});

describe('seeds', () => {
  test('the same seed plays the same expedition', () => {
    expect(startEverest(42)).toEqual(startEverest(42));
    expect(startEverest(0).seed).toBe(1);
    expect(trace(2026)).toEqual(trace(2026));
    expect(trace(2026)).not.toEqual(trace(2027));
  });
});
