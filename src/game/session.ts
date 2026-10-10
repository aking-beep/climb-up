import { useSyncExternalStore } from 'react';

import { kilimanjaroHybrid } from '@/expeditions/kilimanjaro/challenges';

import { deviceStorage } from './save/device';
import { createSettingsStore } from './save/settings';
import { createGameStore } from './save/store';

/** The app's one expedition and its settings, saved on the device. */
export const gameStore = createGameStore(kilimanjaroHybrid, deviceStorage);
export const settingsStore = createSettingsStore(deviceStorage);

export function hydrateGame(): Promise<unknown> {
  return Promise.all([gameStore.hydrate(), settingsStore.hydrate()]);
}

export function useGameSession() {
  return useSyncExternalStore(gameStore.subscribe, gameStore.get, gameStore.get);
}

export function useSettings() {
  return useSyncExternalStore(settingsStore.subscribe, settingsStore.get, settingsStore.get);
}
