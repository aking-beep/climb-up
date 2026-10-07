export type Weather = 'clear' | 'rising' | 'whiteout' | 'storm';

export type Tone = 'cautious' | 'bold' | 'reckless';

export type Move = 'up' | 'down' | 'back' | 'hold' | 'turn' | 'summit' | 'leave' | 'continue';

export type Phase = 'up' | 'down' | 'any';

export type Status = 'fit' | 'strained' | 'hurt' | 'critical' | 'dead';

export type ClimberId = 'you' | 'lena' | 'marco' | 'jun';

export type Climber = {
  id: ClimberId;
  name: string;
  role: string;
  strain: number;
};

export type Judgment = {
  label: string;
  delta: number;
  mark?: string;
};

export type Effect = {
  note: string;
  move?: Move;
  daylight?: number;
  food?: number;
  warmth?: number;
  morale?: number;
  rope?: number;
  acclimatization?: number;
  strain?: Partial<Record<ClimberId, number>>;
  strainAll?: number;
  relieve?: number;
  judgment?: Judgment;
  mark?: string;
  dugIn?: boolean;
};

export type Choice = {
  label: string;
  detail: string;
  tone: Tone;
  move: Move;
  apply: (state: GameState) => Effect;
};

export type Card = {
  id: string;
  title: string;
  text: string;
  choices: Choice[];
  bands?: string[];
  phase?: Phase;
  weather?: Weather[];
  weight?: number;
  urgent?: boolean;
  /** Shown again every day, at most once. */
  repeat?: 'day';
  /** Never stored in the seen list. */
  ephemeral?: boolean;
  when?: (state: GameState) => boolean;
};

export type LogLine = {
  day: number;
  text: string;
};

export type GameState = {
  seed: number;
  day: number;
  band: number;
  descending: boolean;
  summited: boolean;
  broughtHome: boolean;
  over: boolean;
  reason: 'home' | 'leader' | 'party' | 'time' | '';
  warmth: number;
  food: number;
  daylight: number;
  morale: number;
  rope: number;
  acclimatization: number;
  weather: Weather;
  forecast: Weather;
  party: Climber[];
  seen: string[];
  judgment: Judgment[];
  log: LogLine[];
  highPoint: number;
  marks: Record<string, boolean | number>;
  dugIn: boolean;
  lastNote: string;
};

export type ScoreLine = {
  label: string;
  delta: number;
};

export type Score = {
  total: number;
  lines: ScoreLine[];
  highPoint: number;
  highCamp: string;
  summited: boolean;
  broughtHome: boolean;
  highPointNote: string;
};

export type Ending = {
  title: string;
  text: string;
};

export type Band = {
  id: string;
  name: string;
  meters: number;
};

export const BANDS: readonly Band[] = [
  { id: 'road', name: 'Roadhead', meters: 2800 },
  { id: 'valley', name: 'Approach valley', meters: 3400 },
  { id: 'base', name: 'Base camp', meters: 4100 },
  { id: 'abc', name: 'Advanced camp', meters: 4800 },
  { id: 'ice', name: 'Icefall', meters: 5300 },
  { id: 'high', name: 'High camp', meters: 5800 },
  { id: 'ridge', name: 'Summit ridge', meters: 6200 },
  { id: 'summit', name: 'Summit', meters: 6420 },
];

/** How acclimatized the party must be before this camp is reasonable. */
export const ALTITUDE_NEED = [0, 6, 18, 32, 46, 58, 70, 80];

export const WEATHER_LABEL: Record<Weather, string> = {
  clear: 'Clear',
  rising: 'Building',
  whiteout: 'Whiteout',
  storm: 'Storm',
};

const WEATHER_CYCLE: readonly Weather[] = [
  'clear',
  'clear',
  'clear',
  'rising',
  'clear',
  'rising',
  'whiteout',
  'clear',
  'rising',
  'storm',
  'clear',
  'rising',
];

export const ROSTER: readonly Climber[] = [
  { id: 'you', name: 'You', role: 'Leader', strain: 0 },
  { id: 'lena', name: 'Lena Voss', role: 'Guide', strain: 0 },
  { id: 'marco', name: 'Marco Adeyemi', role: 'Climber', strain: 0 },
  { id: 'jun', name: 'Jun Park', role: 'Doctor', strain: 0 },
];

export function hash(...nums: number[]): number {
  let h = 2166136261;
  for (const n of nums) {
    h ^= n | 0;
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

export function clamp(n: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, n));
}

export function weatherOn(day: number, seed: number, _descending = false): Weather {
  const shift = seed % 3;
  return WEATHER_CYCLE[(day - 1 + shift) % WEATHER_CYCLE.length];
}

export function statusOf(strain: number): Status {
  if (strain <= 0) return 'fit';
  if (strain <= 2) return 'strained';
  if (strain <= 4) return 'hurt';
  if (strain <= 6) return 'critical';
  return 'dead';
}

export function isAlive(person: Climber): boolean {
  return person.strain < 7;
}

export function bandIndexForMeters(meters: number): number {
  let idx = 0;
  for (let i = 0; i < BANDS.length; i++) {
    if (BANDS[i].meters <= meters) idx = i;
  }
  return idx;
}

/** Strain added for going up before the party is used to the air. */
export function altitudeTax(acclimatization: number, band: number): number {
  const need = ALTITUDE_NEED[band] ?? 0;
  const gap = need - acclimatization;
  if (gap > 24) return 2;
  if (gap > 8) return 1;
  return 0;
}

export function formatMeters(meters: number): string {
  return meters.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

export function formatSeed(seed: number): string {
  return seed.toString(36).toUpperCase();
}

export function parseSeed(code: string | undefined): number | undefined {
  if (!code) return undefined;
  const trimmed = code.trim();
  if (!/^[0-9a-z]+$/i.test(trimmed)) return undefined;
  const n = Number.parseInt(trimmed, 36);
  if (!Number.isFinite(n) || n <= 0) return undefined;
  return n >>> 0;
}

export function turnJudgment(state: GameState): Judgment {
  return {
    label: 'You turned around while the way down still existed',
    delta: 80 + state.band * 70,
    mark: 'turned',
  };
}

export function subject(person: Climber): string {
  return person.id === 'you' ? 'You' : person.name;
}

export function worseLine(person: Climber, status: Status): string {
  if (status === 'dead') {
    return person.id === 'you' ? 'You are gone.' : `${person.name} is gone.`;
  }
  const verb = person.id === 'you' ? 'are' : 'is';
  return `${subject(person)} ${verb} ${status}.`;
}
