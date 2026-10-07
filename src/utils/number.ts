export function clamp(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) return min;
  return Math.min(max, Math.max(min, value));
}

export function hash(...nums: number[]): number {
  let h = 2166136261;
  for (const n of nums) {
    h ^= n | 0;
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

export function formatMeters(meters: number): string {
  return Math.round(meters)
    .toString()
    .replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

export function formatSeed(seed: number): string {
  return (seed >>> 0).toString(36).toUpperCase();
}

export function parseSeed(code: string | undefined): number | undefined {
  if (!code) return undefined;
  const trimmed = code.trim();
  if (!/^[0-9a-z]+$/i.test(trimmed)) return undefined;
  const n = Number.parseInt(trimmed, 36);
  if (!Number.isFinite(n) || n <= 0) return undefined;
  return n >>> 0;
}

export function formatElapsed(hours: number): string {
  const safe = Math.max(0, Math.floor(hours));
  const day = Math.floor(safe / 24) + 1;
  const hour = safe % 24;
  return `Day ${day} · ${hour} h`;
}
