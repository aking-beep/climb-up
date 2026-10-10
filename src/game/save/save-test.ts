/// <reference types="jest" />

import { startKilimanjaro } from '@/expeditions/kilimanjaro';

import { parseSave } from './persistence';

describe('expedition saves', () => {
  test('a versioned save round-trips, and a broken one is ignored', () => {
    const file = {
      version: 1 as const,
      state: startKilimanjaro(12),
      pending: {
        attemptId: 'barranco-wall-12-0-0',
        challengeId: 'barranco-wall',
        eventId: 'kili-wall',
        choiceIndex: 0,
      },
    };
    expect(parseSave(JSON.stringify(file))?.pending?.challengeId).toBe('barranco-wall');
    expect(parseSave('not json')).toBeNull();
    expect(parseSave(JSON.stringify({ version: 2, state: file.state }))).toBeNull();
  });
});
