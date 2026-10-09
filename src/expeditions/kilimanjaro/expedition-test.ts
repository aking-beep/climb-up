/// <reference types="jest" />

import { KILI_EVENTS, SME_REVIEW_IDS } from '@/expeditions/kilimanjaro/events';
import {
  chooseKilimanjaro,
  currentKilimanjaroEvent,
  kilimanjaro,
  scoreKilimanjaro,
  startKilimanjaro,
} from '@/expeditions/kilimanjaro';
import { KILI_ROUTE, KNOWN_CAMPS, kiliCamping } from '@/expeditions/kilimanjaro/route';
import { kiliGround } from '@/expeditions/kilimanjaro/zones';
import { dayPhase, expeditionHour } from '@/components/world/scene';
import { applyEffect } from '@/game/engine';
import type { ExpeditionState } from '@/game/types';
import { routineEffect } from '@/expeditions/kilimanjaro/party';

function chooseLabel(state: ExpeditionState, label: string): ExpeditionState {
  const card = currentKilimanjaroEvent(state);
  const index = card.choices.findIndex((choice) => choice.label === label);
  if (index < 0) {
    throw new Error(`"${label}" is not on ${card.id}: ${card.choices.map((choice) => choice.label).join(' | ')}`);
  }
  return chooseKilimanjaro(state, index);
}

const CAREFUL = [
  'Walk the forest and set camp',
  'Sleep under the trees',
  'Break camp and keep a patient pace',
  'Stake the tents and sleep',
  'Cross the plateau and pitch at Shira 2',
  'Sleep before the tower',
  'Tag the tower, then sleep low',
  'Sleep and leave the wall for morning',
  'Climb the wall and camp at Karanga',
  'Lie down in the valley',
  'Take the extra day',
  'Break camp for Barafu',
  'Lie down on the ridge',
  'Rest the day',
  'Keep the pace through the dark',
  'Turn down while you still can',
  'Sleep at Mweka',
  'Walk out to the gate',
];

const RUSH = [
  'Push the forest to gain a day',
  'Walk the mud in the dark',
  'Force the moorland before the team is ready',
  'Walk above camp in the dark',
  'Race the plateau',
  'Start for the tower in the dark',
  'Skip the tower and drop to Barranco',
  'Try the wall tonight',
  'Climb the wall and camp at Karanga',
  'Stay up and watch the ridge',
  'Push on tired to Barafu',
  'Pace the ridge',
  'Start for the summit tonight',
  'A photograph, then down',
  'Push the forest in the dark',
];

function play(labels: readonly string[], seed = 7): ExpeditionState {
  return labels.reduce((state, label) => chooseLabel(state, label), startKilimanjaro(seed));
}

describe('kilimanjaro route', () => {
  test('the ten-day sleeps are in order, and the other famous camps are named', () => {
    expect(KILI_ROUTE.map((stop) => stop.name)).toEqual([
      'Londorossi Gate',
      'Mti Mkubwa Camp',
      'Shira 1 Camp',
      'Shira 2 Camp',
      'Barranco Camp',
      'Karanga Camp',
      'Barafu Camp',
      'Uhuru Peak',
    ]);
    const names = KNOWN_CAMPS.map((camp) => camp.name);
    for (const name of [
      'Machame Camp',
      'Mandara Hut',
      'Horombo Hut',
      'Kibo Hut',
      'Simba Camp',
      'School Hut',
      'Moir Hut',
      'Buffalo Camp',
      'Umbwe Cave Camp',
      'Lava Tower',
      'Mweka Camp',
      'Mweka Gate',
    ]) {
      expect(names).toContain(name);
    }
    expect(KNOWN_CAMPS.find((camp) => camp.name === 'Crater Camp')?.route).toMatch(/not used/i);
  });

  test('the ground changes from forest to plateau to desert to the summit', () => {
    expect(kiliGround('briefing', 2100)).toBe('rainforest');
    expect(kiliGround('approach', 2780)).toBe('rainforest');
    expect(kiliGround('ebc', 3500)).toBe('moorland');
    expect(kiliGround('camp2', 3960)).toBe('desert');
    expect(kiliGround('camp4', 4640)).toBe('desert');
    expect(kiliGround('summit', 5895)).toBe('snow');
    expect(kiliCamping('briefing', 2100)).toBe(false);
    expect(kiliCamping('approach', 2780)).toBe(true);
    expect(kiliCamping('camp4', 4640)).toBe(true);
    expect(kiliCamping('summit', 5895)).toBe(false);
    expect(kiliCamping('descent', 3100)).toBe(true);
    expect(kiliCamping('complete', 1640)).toBe(false);
  });

  test('the deck has a real decision at every camp, including scenes flagged for review', () => {
    expect(KILI_EVENTS.length).toBeGreaterThanOrEqual(18);
    expect(KILI_EVENTS.filter((event) => event.category === 'night')).toHaveLength(7);
    for (const event of KILI_EVENTS) {
      expect(event.choices.length).toBeGreaterThanOrEqual(2);
      expect(event.choices.length).toBeLessThanOrEqual(3);
    }
    expect(SME_REVIEW_IDS.length).toBeGreaterThan(0);
    for (const id of SME_REVIEW_IDS) {
      expect(KILI_EVENTS.find((event) => event.id === id)?.review).toBe('sme');
    }
  });
});

describe('a ten-day walk', () => {
  test('using the rest days tags the tower, reaches Uhuru, and walks out', () => {
    let state = startKilimanjaro(7);
    state = chooseLabel(state, 'Walk the forest and set camp');
    expect(state.checkpoint).toBe('approach');
    expect(state.altitude).toBe(2780);
    expect(currentKilimanjaroEvent(state).id).toBe('kili-night-forest');
    expect(dayPhase(expeditionHour(state.elapsedHours))).toBe('night');

    state = chooseLabel(state, 'Sleep under the trees');
    expect(currentKilimanjaroEvent(state).id).toBe('kili-big-tree');
    expect(dayPhase(expeditionHour(state.elapsedHours))).toBe('day');

    state = chooseLabel(state, 'Break camp and keep a patient pace');
    state = chooseLabel(state, 'Stake the tents and sleep');
    state = chooseLabel(state, 'Cross the plateau and pitch at Shira 2');
    expect(state.altitude).toBe(3850);
    expect(state.highestAltitude).toBe(4100);
    expect(dayPhase(expeditionHour(state.elapsedHours))).toBe('night');

    state = chooseLabel(state, 'Sleep before the tower');
    state = chooseLabel(state, 'Tag the tower, then sleep low');
    expect(state.checkpoint).toBe('camp2');
    expect(state.altitude).toBe(3960);
    expect(state.highestAltitude).toBe(4630);

    for (const label of CAREFUL.slice(CAREFUL.indexOf('Sleep and leave the wall for morning'))) {
      state = chooseLabel(state, label);
    }
    expect(dayPhase(expeditionHour(state.elapsedHours))).toBe('dusk');
    expect(state.status).toBe('complete');
    expect(state.summitReached).toBe(true);
    expect(state.returnedSafely).toBe(true);
    expect(state.highestAltitude).toBe(5895);
    expect(state.altitude).toBe(1640);
    const day = Math.floor(state.elapsedHours / 24) + 1;
    expect(day).toBeGreaterThanOrEqual(9);
    expect(day).toBeLessThanOrEqual(12);
    for (const key of ['health', 'energy', 'supplies', 'teamCondition'] as const) {
      expect(state[key]).toBeGreaterThan(0);
    }
  });

  test('a summit without the walk out is not a success, and a rush scores below the ten-day return', () => {
    const careful = play(CAREFUL);
    const carefulScore = scoreKilimanjaro(careful);
    expect(carefulScore.successful).toBe(true);
    expect(carefulScore.overall).toBeGreaterThan(70);

    const rushed = play(RUSH);
    const rushedScore = scoreKilimanjaro(rushed);
    expect(rushed.summitReached).toBe(true);
    expect(rushed.returnedSafely).toBe(true);
    expect(rushedScore.overall).toBeLessThan(carefulScore.overall);

    const stuck = applyEffect(
      chooseLabel(play(CAREFUL.slice(0, CAREFUL.indexOf('Turn down while you still can'))), 'Stay on the summit'),
      { note: 'The descent does not happen.', hours: 2, move: 'hold', health: -100, teamCondition: -100 },
      kilimanjaro,
    );
    const stuckScore = scoreKilimanjaro(stuck);
    expect(stuckScore.summitReached).toBe(true);
    expect(stuckScore.returnedSafely).toBe(false);
    expect(stuckScore.successful).toBe(false);
    expect(stuckScore.overall).toBeLessThanOrEqual(36);
    expect(carefulScore.overall).toBeGreaterThan(stuckScore.overall + 20);
  });

  test('turning around on the plateau still brings the team home', () => {
    let state = startKilimanjaro(11);
    state = chooseLabel(state, 'Walk the forest and set camp');
    state = chooseLabel(state, 'Sleep under the trees');
    state = chooseLabel(state, 'Break camp and keep a patient pace');
    state = chooseLabel(state, 'Stake the tents and sleep');
    state = chooseLabel(state, 'Cross the plateau and pitch at Shira 2');
    state = chooseLabel(state, 'Sleep before the tower');
    state = chooseLabel(state, 'Turn the plateau around');
    expect(state.summitReached).toBe(false);
    expect(state.retreating).toBe(true);

    let guard = 0;
    while (state.status === 'active' && guard < 6) {
      state = applyEffect(state, { note: 'Down', hours: 8, move: 'down', energy: 2, teamCondition: 1 }, kilimanjaro);
      guard += 1;
    }
    expect(state.status).toBe('complete');
    expect(state.returnedSafely).toBe(true);
    expect(scoreKilimanjaro(state).successful).toBe(true);
    expect(scoreKilimanjaro(state).summitReached).toBe(false);
  });

  test('a camp job during the night does not spend the night challenge', () => {
    let state = chooseLabel(startKilimanjaro(4), 'Walk the forest and set camp');
    expect(currentKilimanjaroEvent(state).id).toBe('kili-night-forest');
    const effect = routineEffect(state, 'pole-pole');
    expect(effect).not.toBeNull();
    state = applyEffect(state, effect!, kilimanjaro);
    expect(currentKilimanjaroEvent(state).id).toBe('kili-night-forest');
    expect(dayPhase(expeditionHour(state.elapsedHours))).toBe('night');
  });

  test('the hard hour is a night, and it comes only after the Barafu rest', () => {
    const state = play(CAREFUL.slice(0, CAREFUL.indexOf('Keep the pace through the dark')));
    expect(currentKilimanjaroEvent(state).id).toBe('kili-hard-hour');
    expect(dayPhase(expeditionHour(state.elapsedHours))).toBe('night');
    expect(state.checkpoint).toBe('camp4');
    expect(state.marks['barafu-rest']).toBe(true);
  });
});
