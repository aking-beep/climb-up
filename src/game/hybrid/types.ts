import type { Effect, ExpeditionState, LedgerNote, ScoreBucket, StatKey } from '@/game/types';

export type ChallengeId = 'barranco-wall';

export type ChallengeResult = 'complete' | 'retreat' | 'fail';

/** What a played challenge reports back. Plain data, so it can be saved. */
export type ChallengeOutcome = {
  attemptId: string;
  challengeId: ChallengeId;
  result: ChallengeResult;
  /** Stamina left at the end, 0–100. */
  staminaLeft: number;
  /** Times the climber slipped back to a checkpoint. */
  slips: number;
  /** true: helped the teammate. false: left them. null: never reached them. */
  assisted: boolean | null;
  regrouped: boolean;
  /** Seconds of play. Informational; never scored. */
  seconds: number;
};

/**
 * A card choice that has been made but not yet spent. The expedition state
 * is untouched until the outcome lands; `historyLength` and `eventId` pin
 * the exact moment the attempt belongs to.
 */
export type PendingChallenge = {
  attemptId: string;
  challengeId: ChallengeId;
  expeditionId: string;
  eventId: string;
  choiceIndex: number;
  choiceLabel: string;
  historyLength: number;
  /** Seeds the challenge simulation, so a restarted attempt plays the same. */
  seed: number;
};

/**
 * The bounded change a challenge outcome may make on top of the card's own
 * effect. The coordinator clamps every field before it is combined.
 */
export type OutcomeModifier = {
  note: string;
  stats?: Partial<Record<StatKey, number>>;
  /** Extra hours on top of the card's hours. */
  hours?: number;
  /** A challenge can only take height away, never add it. */
  move?: 'hold';
  /** false drops the card's own score notes (a retreat did not earn them). */
  keepBaseScores: boolean;
  scores?: Partial<Record<ScoreBucket, LedgerNote>>;
};

export type ChallengeDefinition = {
  id: ChallengeId;
  title: string;
  /** The card and the choice that launch this challenge. */
  eventId: string;
  choiceLabel: string;
  modifier: (outcome: ChallengeOutcome, base: Effect, state: ExpeditionState) => OutcomeModifier;
};

export type HybridSession = {
  expeditionId: string;
  state: ExpeditionState;
  /** The state before the last decision, for the field-note delta. */
  prior: ExpeditionState | null;
  pending: PendingChallenge | null;
  /** Every attempt that has been spent. An outcome for one of these is ignored. */
  resolvedAttempts: string[];
};

export type ResolveStatus = 'applied' | 'duplicate' | 'stale' | 'invalid';
