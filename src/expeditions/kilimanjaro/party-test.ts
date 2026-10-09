/// <reference types="jest" />

import { applyEffect } from '@/game/engine';
import { kilimanjaro, startKilimanjaro, currentKilimanjaroEvent } from '@/expeditions/kilimanjaro';

import { membersOf, routineActions, routineEffect, tendEffect } from './party';

describe('the party', () => {
  test('Marco feels the mountain first and Lena holds the pace', () => {
    const party = membersOf(startKilimanjaro(3));
    const marco = party.find((person) => person.id === 'marco');
    const lena = party.find((person) => person.id === 'lena');
    const you = party.find((person) => person.id === 'you');
    expect(marco && lena && you).toBeTruthy();
    expect(marco!.energy).toBeLessThan(you!.energy);
    expect(lena!.spirits).toBeGreaterThan(you!.spirits);
    expect(marco!.pose).toBe('walk');
    expect(party.map((person) => person.id)).toEqual(['jun', 'marco', 'you', 'lena']);
  });

  test('a tired Marco can be sat with, and it shows on him', () => {
    const tired = { ...startKilimanjaro(3), energy: 40, teamCondition: 50 };
    const before = membersOf(tired).find((person) => person.id === 'marco');
    expect(before?.pose).not.toBe('walk');
    const effect = tendEffect(tired, 'marco');
    expect(effect?.mark).toBe('tend-marco');
    const after = applyEffect(tired, effect!, kilimanjaro);
    const marco = membersOf(after).find((person) => person.id === 'marco');
    expect(marco!.energy).toBeGreaterThan(before!.energy);
    expect(tendEffect(after, 'marco')).toBeNull();
  });

  test('the morning routine is once per camp and does not spend the decision', () => {
    const start = startKilimanjaro(9);
    const card = currentKilimanjaroEvent(start).id;
    const actions = routineActions(start);
    expect(actions.map((action) => action.id)).toEqual(['pole-pole', 'water', 'head-count']);
    expect(actions.every((action) => action.enabled)).toBe(true);

    let state = start;
    for (const action of actions) {
      state = applyEffect(state, routineEffect(state, action.id)!, kilimanjaro);
    }
    expect(currentKilimanjaroEvent(state).id).toBe(card);
    expect(state.checkpoint).toBe(start.checkpoint);
    expect(state.acclimatization).toBeGreaterThan(start.acclimatization);
    expect(state.supplies).toBe(start.supplies - 1);
    expect(routineActions(state).every((action) => action.done)).toBe(true);
    expect(routineEffect(state, 'pole-pole')).toBeNull();
  });

  test('the same jobs change their names in the dark', () => {
    const dark = { ...startKilimanjaro(1), elapsedHours: 13 };
    const labels = routineActions(dark).map((action) => action.label);
    expect(labels).toContain('Slow the first hour');
    expect(labels).toContain('Check before anyone leaves');
  });
});
