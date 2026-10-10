/// <reference types="jest" />

import { startKilimanjaro } from '@/expeditions/kilimanjaro';

import { explainSave, parseSave, queueSave, type SaveFile } from './persistence';

function file(): SaveFile {
  return {
    version: 2,
    state: startKilimanjaro(12),
    pending: {
      attemptId: 'barranco-wall-12-0-0',
      challengeId: 'barranco-wall',
      eventId: 'kili-wall',
      choiceId: 'kili-wall-climb',
      choiceIndex: 0,
    },
    climb: null,
  };
}

describe('expedition saves', () => {
  test('a version 1 save migrates, and a broken one is explained', () => {
    const saved = file();
    const legacy = {
      version: 1,
      state: saved.state,
      pending: {
        attemptId: saved.pending?.attemptId,
        challengeId: 'barranco-wall',
        eventId: 'kili-wall',
        choiceIndex: 0,
      },
    };
    const migrated = parseSave(JSON.stringify(legacy));
    expect(migrated?.version).toBe(2);
    expect(migrated?.pending?.choiceId).toBe('kili-wall-climb');
    expect(migrated?.climb).toBeNull();
    expect(parseSave('not json')).toBeNull();
    expect(explainSave('not json')).toEqual({ ok: false, error: 'The save is not readable.' });
    expect(parseSave(JSON.stringify({ version: 3, state: saved.state }))).toBeNull();
    expect(parseSave(JSON.stringify({ version: 2, state: { seed: 1 } }))).toBeNull();
  });

  test('saves run in order, and a failed write does not block the next one', async () => {
    const saved = file();
    let release: () => void = () => undefined;
    const gate = new Promise<void>((resolve) => {
      release = resolve;
    });
    const writes: string[] = [];
    const first = queueSave(saved, async () => {
      await gate;
      writes.push('first');
    });
    const second = queueSave({ ...saved, pending: null }, async () => {
      writes.push('second');
    });
    const failed = queueSave(saved, async () => {
      throw new Error('disk full');
    });
    const third = queueSave(saved, async () => {
      writes.push('third');
    });
    release();
    await expect(first).resolves.toEqual({ ok: true });
    await expect(second).resolves.toEqual({ ok: true });
    await expect(failed).resolves.toEqual({ ok: false, error: 'disk full' });
    await expect(third).resolves.toEqual({ ok: true });
    expect(writes).toEqual(['first', 'second', 'third']);
  });
});
