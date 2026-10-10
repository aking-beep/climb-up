import { useSyncExternalStore } from 'react';

import { startKilimanjaro } from '@/expeditions/kilimanjaro';
import type { PendingChallenge } from '@/game/hybrid/types';
import type { ExpeditionState } from '@/game/types';

import { clearSave, writeSave, type SaveFile } from './persistence';

export type Session = {
  state: ExpeditionState;
  pending: PendingChallenge | null;
  booted: boolean;
};

let snapshot: Session = {
  state: startKilimanjaro(1),
  pending: null,
  booted: false,
};

const listeners = new Set<() => void>();

function emit() {
  for (const listener of listeners) listener();
}

function persist() {
  void writeSave({ version: 1, state: snapshot.state, pending: snapshot.pending });
}

export function getSession(): Session {
  return snapshot;
}

export function subscribeSession(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function useSession(): Session {
  return useSyncExternalStore(subscribeSession, getSession, getSession);
}

export function startExpedition(seed?: number) {
  snapshot = { state: startKilimanjaro(seed), pending: null, booted: true };
  emit();
  persist();
}

export function resumeExpedition(file: SaveFile) {
  snapshot = { state: file.state, pending: file.pending, booted: true };
  emit();
}

export function ensureBoot(seed: number | undefined) {
  if (snapshot.booted && (seed === undefined || snapshot.state.seed === seed)) return;
  snapshot = { state: startKilimanjaro(seed), pending: null, booted: true };
  emit();
}

export function updateSession(next: { state: ExpeditionState; pending: PendingChallenge | null }) {
  snapshot = { state: next.state, pending: next.pending, booted: true };
  emit();
  persist();
}

export function abandonExpedition() {
  snapshot = { state: startKilimanjaro(1), pending: null, booted: false };
  emit();
  void clearSave();
}
