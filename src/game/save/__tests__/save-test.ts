/// <reference types="jest" />

import { currentKilimanjaroEvent, startKilimanjaro } from '@/expeditions/kilimanjaro';
import { kilimanjaroHybrid } from '@/expeditions/kilimanjaro/challenges';
import { createSession } from '@/game/hybrid/coordinator';
import type { ChallengeOutcome } from '@/game/hybrid/types';
import { SAVE_KEY, SAVE_VERSION, deserializeSave, serializeSave } from '@/game/save/schema';
import { DEFAULT_SETTINGS, parseSettings } from '@/game/save/settings';
import { memoryStorage } from '@/game/save/storage';
import { createGameStore, type GameStore } from '@/game/save/store';

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

function chooseLabel(store: GameStore, label: string) {
  const card = currentKilimanjaroEvent(store.get()!.state);
  const index = card.choices.findIndex((choice) => choice.label === label);
  if (index < 0) throw new Error(`"${label}" is not on ${card.id}`);
  return store.choose(index);
}

function completed(attemptId: string): ChallengeOutcome {
  return {
    attemptId,
    challengeId: 'barranco-wall',
    result: 'complete',
    staminaLeft: 50,
    slips: 1,
    assisted: true,
    regrouped: false,
    seconds: 120,
  };
}

const clock = () => new Date('2026-10-10T12:00:00Z');

describe('save file', () => {
  test('round-trips a session', () => {
    const session = createSession(kilimanjaroHybrid, startKilimanjaro(11));
    const loaded = deserializeSave(serializeSave(session, clock()));
    expect(loaded.ok).toBe(true);
    if (loaded.ok) {
      expect(loaded.file.version).toBe(SAVE_VERSION);
      expect(loaded.file.session).toEqual(session);
      expect(loaded.migratedFrom).toBeNull();
    }
  });

  test('refuses empty, corrupt, newer, and malformed saves', () => {
    expect(deserializeSave(null)).toEqual({ ok: false, reason: 'empty' });
    expect(deserializeSave('{nope')).toEqual({ ok: false, reason: 'corrupt' });
    expect(deserializeSave(JSON.stringify({ version: SAVE_VERSION + 1, session: {} }))).toEqual({
      ok: false,
      reason: 'newer',
    });
    expect(deserializeSave(JSON.stringify({ version: SAVE_VERSION, session: { state: {} } }))).toEqual({
      ok: false,
      reason: 'invalid',
    });
    expect(deserializeSave(JSON.stringify({ version: 0, session: {} }))).toEqual({ ok: false, reason: 'invalid' });
  });
});

describe('game store', () => {
  test('an interrupted climb is restored with its pending challenge, and lands once', async () => {
    const storage = memoryStorage();
    const first = createGameStore(kilimanjaroHybrid, storage, clock);
    await first.hydrate();
    first.start(7);
    for (const label of TO_THE_WALL) chooseLabel(first, label);
    const pending = chooseLabel(first, 'Climb the wall and camp at Karanga');
    expect(pending?.challengeId).toBe('barranco-wall');
    const before = first.get()!.state;
    await first.flush();

    // The app is closed mid-climb. A fresh process reads the save.
    const second = createGameStore(kilimanjaroHybrid, storage, clock);
    await second.hydrate();
    expect(second.get()?.pending).toEqual(pending);
    expect(second.get()?.state).toEqual(before);

    expect(second.resolve(completed(pending!.attemptId))).toBe('applied');
    expect(second.get()?.state.checkpoint).toBe('camp3');
    await second.flush();

    // And again: the result is saved, and the same outcome cannot land twice.
    const third = createGameStore(kilimanjaroHybrid, storage, clock);
    await third.hydrate();
    expect(third.get()?.pending).toBeNull();
    expect(third.get()?.state).toEqual(second.get()?.state);
    expect(third.resolve(completed(pending!.attemptId))).toBe('duplicate');
    expect(third.get()?.state).toEqual(second.get()?.state);
  });

  test('a corrupt save starts clean and is not deleted by reading it', async () => {
    const storage = memoryStorage({ [SAVE_KEY]: '{broken' });
    const store = createGameStore(kilimanjaroHybrid, storage, clock);
    const result = await store.hydrate();
    expect(result.ok).toBe(false);
    expect(store.get()).toBeNull();
    expect(store.isHydrated()).toBe(true);
    expect(storage.data[SAVE_KEY]).toBe('{broken');
  });

  test('a failing write is recorded, not thrown', async () => {
    const storage = memoryStorage();
    storage.write = async () => {
      throw new Error('disk full');
    };
    const store = createGameStore(kilimanjaroHybrid, storage, clock);
    store.start(3);
    await store.flush();
    expect((store.lastError() as Error).message).toBe('disk full');
    expect(store.get()?.state.seed).toBe(3);
  });

  test('subscribers hear every change', async () => {
    const store = createGameStore(kilimanjaroHybrid, memoryStorage(), clock);
    const heard = jest.fn();
    const stop = store.subscribe(heard);
    store.start(5);
    store.choose(0);
    stop();
    store.choose(0);
    expect(heard).toHaveBeenCalledTimes(2);
  });
});

describe('settings', () => {
  test('parse keeps known booleans and ignores the rest', () => {
    expect(parseSettings(null)).toEqual(DEFAULT_SETTINGS);
    expect(parseSettings('nope')).toEqual(DEFAULT_SETTINGS);
    expect(parseSettings(JSON.stringify({ reducedMotion: true, lowPower: 'yes', extra: 1 }))).toEqual({
      ...DEFAULT_SETTINGS,
      reducedMotion: true,
    });
  });
});
