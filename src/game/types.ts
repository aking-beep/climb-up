export type CheckpointId =
  | 'briefing'
  | 'approach'
  | 'ebc'
  | 'camp1'
  | 'camp2'
  | 'camp3'
  | 'camp4'
  | 'summit'
  | 'descent'
  | 'complete';

export type ExpeditionStatus = 'active' | 'complete' | 'failed';

export type Move = 'up' | 'down' | 'hold' | 'wait' | 'retreat' | 'summit';

export type ScoreBucket = 'judgment' | 'riskManagement' | 'teamwork' | 'preparation';

export type LedgerNote = {
  label: string;
  delta: number;
  mark?: string;
};

export type Effect = {
  note: string;
  hours?: number;
  health?: number;
  energy?: number;
  acclimatization?: number;
  oxygen?: number;
  supplies?: number;
  weatherRisk?: number;
  objectiveRisk?: number;
  teamCondition?: number;
  move?: Move;
  /** A height the team touches and leaves. Raises the highest mark only. */
  visitMeters?: number;
  scores?: Partial<Record<ScoreBucket, LedgerNote>>;
  mark?: string;
};

export type Choice = {
  /** Stable id for a playable challenge. Display labels can change. */
  id?: string;
  label: string;
  detail: string;
  effect: Effect | ((state: ExpeditionState) => Effect);
};

export type ReviewFlag = 'sme';

export type EventCard = {
  id: string;
  title: string;
  text: string;
  choices: Choice[];
  category: string;
  checkpoints?: CheckpointId[];
  phase?: 'up' | 'down' | 'any';
  weight?: number;
  urgent?: boolean;
  repeat?: 'day';
  ephemeral?: boolean;
  when?: (state: ExpeditionState) => boolean;
  /** Safety-sensitive scene. Game fiction only; needs specialist review. */
  review?: ReviewFlag;
};

export type HistoryEntry = {
  checkpoint: CheckpointId;
  hours: number;
  choice: string;
  note: string;
};

export type ExpeditionState = {
  seed: number;
  checkpoint: CheckpointId;
  altitude: number;
  highestAltitude: number;
  health: number;
  energy: number;
  acclimatization: number;
  oxygen: number;
  supplies: number;
  weatherRisk: number;
  objectiveRisk: number;
  teamCondition: number;
  elapsedHours: number;
  summitReached: boolean;
  retreating: boolean;
  returnedSafely: boolean;
  status: ExpeditionStatus;
  history: HistoryEntry[];
  seen: string[];
  marks: Record<string, number | boolean>;
  lastNote: string;
  ledger: Record<ScoreBucket, LedgerNote[]>;
};

export type RouteStop = {
  id: CheckpointId;
  name: string;
  meters: number;
};

export type ExpeditionDefinition = {
  id: string;
  title: string;
  routeName: string;
  disclaimer: string;
  route: readonly RouteStop[];
  descentLadder: readonly number[];
  events: readonly EventCard[];
};

export type ScoreLine = {
  bucket: string;
  label: string;
  delta: number;
};

export type ExpeditionScore = {
  highestAltitude: number;
  summitReached: boolean;
  returnedSafely: boolean;
  successful: boolean;
  judgment: number;
  riskManagement: number;
  teamwork: number;
  preparation: number;
  overall: number;
  explanation: string;
  lines: ScoreLine[];
};

export const STAT_KEYS = [
  'health',
  'energy',
  'acclimatization',
  'oxygen',
  'supplies',
  'weatherRisk',
  'objectiveRisk',
  'teamCondition',
] as const;

export type StatKey = (typeof STAT_KEYS)[number];

export const BUCKET_LABEL: Record<ScoreBucket, string> = {
  judgment: 'Judgment',
  riskManagement: 'Risk management',
  teamwork: 'Teamwork',
  preparation: 'Preparation',
};
