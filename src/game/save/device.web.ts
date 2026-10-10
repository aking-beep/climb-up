import type { SaveStorage } from './storage';

/** On web the save lives in localStorage. expo-sqlite on web needs extra wasm setup this project does not use. */
export const deviceStorage: SaveStorage = {
  async read(key) {
    return globalThis.localStorage?.getItem(key) ?? null;
  },
  async write(key, value) {
    globalThis.localStorage?.setItem(key, value);
  },
  async remove(key) {
    globalThis.localStorage?.removeItem(key);
  },
};
