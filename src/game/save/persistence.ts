import { Platform } from 'react-native';

import type { PendingChallenge } from '@/game/hybrid/types';
import type { ExpeditionState } from '@/game/types';

export type SaveFile = {
  version: 1;
  state: ExpeditionState;
  pending: PendingChallenge | null;
};

const KEY = 'climb-up-save-v1';

export function parseSave(raw: string | null | undefined): SaveFile | null {
  if (!raw) return null;
  try {
    const data = JSON.parse(raw) as Partial<SaveFile>;
    if (data.version !== 1 || !data.state || typeof data.state.seed !== 'number') return null;
    if (data.state.status !== 'active' && data.state.status !== 'complete' && data.state.status !== 'failed') {
      return null;
    }
    const pending = data.pending?.attemptId && data.pending.challengeId ? data.pending : null;
    return { version: 1, state: data.state, pending };
  } catch {
    return null;
  }
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

export async function writeSave(file: SaveFile): Promise<void> {
  const payload = JSON.stringify(file);
  try {
    if (Platform.OS === 'web') {
      globalThis.localStorage?.setItem(KEY, payload);
      return;
    }
    const db = await database();
    await db.runAsync('INSERT OR REPLACE INTO save (id, payload) VALUES (1, ?)', payload);
  } catch {
    // The climb still proceeds when the device cannot store it.
  }
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
