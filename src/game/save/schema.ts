import type { HybridSession } from '@/game/hybrid/types';

/**
 * Save format. Bump SAVE_VERSION and add a step to MIGRATIONS whenever the
 * shape of a saved session changes; never edit an old step.
 */
export const SAVE_VERSION = 1;
export const SAVE_KEY = 'climb-up/session';

export type SaveFileV1 = {
  version: 1;
  savedAt: string;
  session: HybridSession;
};

export type SaveFile = SaveFileV1;

/** `MIGRATIONS[n]` turns a version-n file into a version-(n+1) file. */
const MIGRATIONS: Record<number, (file: Record<string, unknown>) => Record<string, unknown>> = {
  // Version 0 was never written to disk: the prototype held state in memory.
};

export function serializeSave(session: HybridSession, now: Date): string {
  const file: SaveFile = { version: SAVE_VERSION, savedAt: now.toISOString(), session };
  return JSON.stringify(file);
}

export type LoadResult =
  | { ok: true; file: SaveFile; migratedFrom: number | null }
  | { ok: false; reason: 'empty' | 'corrupt' | 'newer' | 'invalid' };

export function deserializeSave(raw: string | null): LoadResult {
  if (raw === null || raw === '') return { ok: false, reason: 'empty' };
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return { ok: false, reason: 'corrupt' };
  }
  if (!isRecord(parsed) || typeof parsed.version !== 'number') return { ok: false, reason: 'corrupt' };
  const from = parsed.version;
  if (from > SAVE_VERSION) return { ok: false, reason: 'newer' };
  let file: Record<string, unknown> = parsed;
  for (let version = from; version < SAVE_VERSION; version += 1) {
    const step = MIGRATIONS[version];
    if (!step) return { ok: false, reason: 'invalid' };
    file = { ...step(file), version: version + 1 };
  }
  if (!isSaveFile(file)) return { ok: false, reason: 'invalid' };
  return { ok: true, file, migratedFrom: from === SAVE_VERSION ? null : from };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isSaveFile(file: Record<string, unknown>): file is SaveFile {
  const session = file.session;
  if (!isRecord(session)) return false;
  const state = session.state;
  if (!isRecord(state)) return false;
  if (typeof session.expeditionId !== 'string') return false;
  if (!Array.isArray(session.resolvedAttempts)) return false;
  if (session.pending !== null && !isRecord(session.pending)) return false;
  return (
    typeof state.seed === 'number' &&
    typeof state.checkpoint === 'string' &&
    typeof state.altitude === 'number' &&
    Array.isArray(state.history) &&
    Array.isArray(state.seen) &&
    isRecord(state.marks) &&
    isRecord(state.ledger)
  );
}
