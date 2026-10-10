import Storage from 'expo-sqlite/kv-store';

import type { SaveStorage } from './storage';

/** expo-sqlite's key-value store: one SQLite table, survives app restarts. */
export const deviceStorage: SaveStorage = {
  read: (key) => Storage.getItemAsync(key),
  write: (key, value) => Storage.setItemAsync(key, value),
  async remove(key) {
    await Storage.removeItemAsync(key);
  },
};
