import type { SaveStorage } from './storage';

export const SETTINGS_KEY = 'climb-up/settings';

export type Settings = {
  /** No camera shake, no drifting cloud or particles. */
  reducedMotion: boolean;
  /** Renders at 30 fps with fewer particles. The simulation still runs at 60 Hz. */
  lowPower: boolean;
  /** Movement pad on the right, action on the left. */
  leftHanded: boolean;
  /** Held actions (helping a teammate) become a tap to start and a tap to stop. */
  holdAsToggle: boolean;
};

export const DEFAULT_SETTINGS: Settings = {
  reducedMotion: false,
  lowPower: false,
  leftHanded: false,
  holdAsToggle: false,
};

export function parseSettings(raw: string | null): Settings {
  if (!raw) return DEFAULT_SETTINGS;
  try {
    const parsed: unknown = JSON.parse(raw);
    if (typeof parsed !== 'object' || parsed === null) return DEFAULT_SETTINGS;
    const record = parsed as Record<string, unknown>;
    const out = { ...DEFAULT_SETTINGS };
    for (const key of Object.keys(DEFAULT_SETTINGS) as (keyof Settings)[]) {
      if (typeof record[key] === 'boolean') out[key] = record[key];
    }
    return out;
  } catch {
    return DEFAULT_SETTINGS;
  }
}

export function createSettingsStore(storage: SaveStorage) {
  let settings = DEFAULT_SETTINGS;
  const listeners = new Set<() => void>();
  return {
    get: () => settings,
    subscribe(listener: () => void) {
      listeners.add(listener);
      return () => {
        listeners.delete(listener);
      };
    },
    async hydrate() {
      try {
        settings = parseSettings(await storage.read(SETTINGS_KEY));
      } catch {
        settings = DEFAULT_SETTINGS;
      }
      for (const listener of listeners) listener();
    },
    update(patch: Partial<Settings>) {
      settings = { ...settings, ...patch };
      void storage.write(SETTINGS_KEY, JSON.stringify(settings)).catch(() => undefined);
      for (const listener of listeners) listener();
    },
  };
}
