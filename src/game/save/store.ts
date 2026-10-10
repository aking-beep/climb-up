import { createExpedition } from '@/game/engine';
import * as coordinator from '@/game/hybrid/coordinator';
import type { HybridExpedition } from '@/game/hybrid/coordinator';
import type { ChallengeOutcome, HybridSession, PendingChallenge, ResolveStatus } from '@/game/hybrid/types';
import type { Effect } from '@/game/types';

import { SAVE_KEY, deserializeSave, serializeSave, type LoadResult } from './schema';
import type { SaveStorage } from './storage';

export type GameStore = ReturnType<typeof createGameStore>;

/**
 * The one live expedition. Every change goes through the hybrid
 * coordinator and is written to storage in order, so an app that is
 * closed mid-climb comes back with its pending challenge intact.
 */
export function createGameStore(game: HybridExpedition, storage: SaveStorage, now: () => Date = () => new Date()) {
  let session: HybridSession | null = null;
  let hydrated = false;
  let writes: Promise<void> = Promise.resolve();
  let lastError: unknown = null;
  const listeners = new Set<() => void>();

  function emit() {
    for (const listener of listeners) listener();
  }

  function persist(next: HybridSession | null) {
    const value = next ? serializeSave(next, now()) : null;
    writes = writes
      .then(() => (value === null ? storage.remove(SAVE_KEY) : storage.write(SAVE_KEY, value)))
      .catch((error: unknown) => {
        lastError = error;
      });
  }

  function set(next: HybridSession | null) {
    if (next === session) return;
    session = next;
    persist(next);
    emit();
  }

  return {
    get: () => session,
    isHydrated: () => hydrated,
    lastError: () => lastError,
    subscribe(listener: () => void) {
      listeners.add(listener);
      return () => {
        listeners.delete(listener);
      };
    },

    /** Reads the save. A broken or newer save is left alone and play starts fresh. */
    async hydrate(): Promise<LoadResult> {
      let result: LoadResult;
      try {
        result = deserializeSave(await storage.read(SAVE_KEY));
      } catch (error) {
        lastError = error;
        result = { ok: false, reason: 'corrupt' };
      }
      if (result.ok && result.file.session.expeditionId === game.def.id) session = result.file.session;
      hydrated = true;
      emit();
      return result;
    },

    start(seed?: number) {
      const resolved = seed ?? (Math.floor(Math.random() * 1_000_000_000) || 1);
      set(coordinator.createSession(game, createExpedition(resolved, game.def)));
    },

    /** Returns the challenge to launch, if the choice was a playable one. */
    choose(index: number): PendingChallenge | null {
      if (!session) return null;
      const result = coordinator.choose(game, session, index);
      set(result.session);
      return result.launched;
    },

    play(effect: Effect | null) {
      if (!session) return;
      set(coordinator.play(game, session, effect));
    },

    resolve(outcome: ChallengeOutcome): ResolveStatus {
      if (!session) return 'stale';
      const result = coordinator.resolve(game, session, outcome);
      set(result.session);
      return result.status;
    },

    abandon(): ResolveStatus {
      if (!session) return 'stale';
      const result = coordinator.abandon(game, session);
      set(result.session);
      return result.status;
    },

    clear() {
      set(null);
    },

    /** Resolves once every queued write has reached storage. */
    flush: () => writes,
  };
}
