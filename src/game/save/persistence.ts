import { Platform } from 'react-native';

import { challengeById } from '@/game/hybrid/challengeRegistry';
import type { PendingChallenge } from '@/game/hybrid/types';
import type { ExpeditionState } from '@/game/types';

export type SaveFile = {
  version: 2;
  state: ExpeditionState;
  pending: PendingChallenge | null;
  /** Ledge position is not stored. A restored attempt starts at the camp checkpoint. */
  climb: null;
};

export type SaveWrite = { ok: true } | { ok: false; error: string };

const KEY = 'climb-up-save-v1';
let chain: Promise<void> = Promise.resolve();
let problem: string | null = null;

export function saveProblem(): string | null {
  return problem;
}

export function parseSave(raw: string | null | undefined): SaveFile | null {
  const read = explainSave(raw);
  return read.ok ? read.file : null;
}

export function explainSave(raw: string | null | undefined): { ok: true; file: SaveFile } | { ok: false; error: string } {
  if (!raw) return { ok: false, error: 'The save is empty.' };
  let data: {
    version?: number;
    state?: Partial<ExpeditionState>;
    pending?: Partial<PendingChallenge> | null;
  };
  try {
    data = JSON.parse(raw) as typeof data;
  } catch {
    return { ok: false, error: 'The save is not readable.' };
  }
  if (data.version !== 1 && data.version !== 2) return { ok: false, error: 'The save version is not supported.' };
  if (!validState(data.state)) return { ok: false, error: 'The expedition in the save is incomplete.' };
  const pending = normalizePending(data.pending);
  if (data.pending && !pending) return { ok: false, error: 'The pending climb in the save does not match a known challenge.' };
  return { ok: true, file: { version: 2, state: data.state, pending, climb: null } };
}

function validState(state: Partial<ExpeditionState> | undefined): state is ExpeditionState {
  if (!state) return false;
  if (typeof state.seed !== 'number' || !Number.isFinite(state.seed)) return false;
  if (typeof state.checkpoint !== 'string' || typeof state.altitude !== 'number') return false;
  if (!Array.isArray(state.history) || !state.marks || typeof state.marks !== 'object') return false;
  return state.status === 'active' || state.status === 'complete' || state.status === 'failed';
}

function normalizePending(raw: Partial<PendingChallenge> | null | undefined): PendingChallenge | null {
  if (!raw) return null;
  if (typeof raw.attemptId !== 'string' || typeof raw.challengeId !== 'string' || typeof raw.choiceIndex !== 'number') {
    return null;
  }
  const spec = challengeById(raw.challengeId);
  if (!spec || raw.eventId !== spec.eventId) return null;
  if (raw.choiceId && raw.choiceId !== spec.choiceId) return null;
  return {
    attemptId: raw.attemptId,
    challengeId: spec.challengeId,
    eventId: spec.eventId,
    choiceId: spec.choiceId,
    choiceIndex: raw.choiceIndex,
  };
}

/** Writes run in order. An older write cannot replace a newer one. */
export function queueSave(file: SaveFile, write: (payload: string) => Promise<void>): Promise<SaveWrite> {
  const payload = JSON.stringify(file);
  const job = chain.then(async (): Promise<SaveWrite> => {
    try {
      await write(payload);
      return { ok: true };
    } catch (error) {
      const message = error instanceof Error ? error.message : 'The save could not be written.';
      return { ok: false, error: message };
    }
  });
  chain = job.then(
    () => undefined,
    () => undefined,
  );
  return job;
}

async function database() {
  const sqlite = await import('expo-sqlite');
  const db = await sqlite.openDatabaseAsync('climb-up.db');
  await db.execAsync(
    'CREATE TABLE IF NOT EXISTS save (id INTEGER PRIMARY KEY NOT NULL, payload TEXT NOT NULL)',
  );
  return db;
}

export async function readSave(): Promise<SaveFile | null> {
  try {
    if (Platform.OS === 'web') {
      return parseSave(globalThis.localStorage?.getItem(KEY));
    }
    const db = await database();
    const row = await db.getFirstAsync<{ payload: string }>('SELECT payload FROM save WHERE id = 1');
    return parseSave(row?.payload ?? null);
  } catch {
    return null;
  }
}

export function writeSave(file: SaveFile): Promise<SaveWrite> {
  return queueSave(file, async (payload) => {
    if (Platform.OS === 'web') {
      if (!globalThis.localStorage) throw new Error('This browser has no local storage.');
      globalThis.localStorage.setItem(KEY, payload);
      problem = null;
      return;
    }
    const db = await database();
    await db.runAsync('INSERT OR REPLACE INTO save (id, payload) VALUES (1, ?)', payload);
    problem = null;
  }).then((result) => {
    if (!result.ok) problem = result.error;
    return result;
  });
}

export async function clearSave(): Promise<void> {
  try {
    if (Platform.OS === 'web') {
      globalThis.localStorage?.removeItem(KEY);
      return;
    }
    const db = await database();
    await db.runAsync('DELETE FROM save WHERE id = 1');
  } catch {
    // Ignore a storage miss on the way out.
  }
}
