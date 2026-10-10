import type { Effect, LedgerNote, ScoreBucket, StatKey } from '@/game/types';
import { STAT_KEYS } from '@/game/types';
import { clamp } from '@/utils/number';

import type { ChallengeOutcome, OutcomeModifier } from './types';

/**
 * The limits on what a played challenge can do to the expedition. A
 * challenge can cost a lot and reward a little: the card already carries
 * the reward for the decision, the play only shades it.
 */
export const MODIFIER_LIMITS = {
  statMin: -12,
  statMax: 6,
  hoursMax: 12,
  scoreMin: -8,
  scoreMax: 8,
} as const;

const BUCKETS: ScoreBucket[] = ['judgment', 'riskManagement', 'teamwork', 'preparation'];

export function boundModifier(modifier: OutcomeModifier): OutcomeModifier {
  const stats: Partial<Record<StatKey, number>> = {};
  for (const key of STAT_KEYS) {
    const value = modifier.stats?.[key];
    if (value === undefined) continue;
    stats[key] = Math.round(clamp(value, MODIFIER_LIMITS.statMin, MODIFIER_LIMITS.statMax));
  }
  const scores: Partial<Record<ScoreBucket, LedgerNote>> = {};
  for (const bucket of BUCKETS) {
    const note = modifier.scores?.[bucket];
    if (!note) continue;
    // Unmarked notes could be earned twice; every challenge note carries a mark.
    if (!note.mark) continue;
    scores[bucket] = {
      label: note.label,
      mark: note.mark,
      delta: Math.round(clamp(note.delta, MODIFIER_LIMITS.scoreMin, MODIFIER_LIMITS.scoreMax)),
    };
  }
  return {
    note: modifier.note,
    stats,
    hours: Math.round(clamp(modifier.hours ?? 0, 0, MODIFIER_LIMITS.hoursMax)),
    move: modifier.move === 'wait' ? 'wait' : undefined,
    keepBaseScores: modifier.keepBaseScores,
    scores,
  };
}

/** The card's effect with the bounded challenge modifier laid on top. */
export function combineEffect(base: Effect, raw: OutcomeModifier): Effect {
  const modifier = boundModifier(raw);
  const combined: Effect = { ...base, note: modifier.note || base.note };
  for (const key of STAT_KEYS) {
    const extra = modifier.stats?.[key];
    if (extra === undefined) continue;
    combined[key] = (base[key] ?? 0) + extra;
  }
  combined.hours = (base.hours ?? 6) + (modifier.hours ?? 0);
  if (modifier.move === 'wait') {
    combined.move = 'wait';
    // A retreat off the wall touches no new height.
    delete combined.visitMeters;
  }
  const scores: NonNullable<Effect['scores']> = {};
  for (const bucket of BUCKETS) {
    const own = modifier.keepBaseScores ? base.scores?.[bucket] : undefined;
    const list: LedgerNote[] = own ? (Array.isArray(own) ? [...own] : [own as LedgerNote]) : [];
    const note = modifier.scores?.[bucket];
    if (note) list.push(note);
    if (list.length === 1) scores[bucket] = list[0];
    else if (list.length > 1) scores[bucket] = list;
  }
  combined.scores = Object.keys(scores).length > 0 ? scores : undefined;
  return combined;
}

/** Repairs an outcome that came back from the renderer or a save. */
export function sanitizeOutcome(outcome: ChallengeOutcome): ChallengeOutcome | null {
  if (!outcome || typeof outcome.attemptId !== 'string' || outcome.attemptId.length === 0) return null;
  if (outcome.result !== 'complete' && outcome.result !== 'retreat' && outcome.result !== 'fail') return null;
  return {
    attemptId: outcome.attemptId,
    challengeId: outcome.challengeId,
    result: outcome.result,
    staminaLeft: Math.round(clamp(outcome.staminaLeft, 0, 100)),
    slips: Math.round(clamp(outcome.slips, 0, 99)),
    assisted: outcome.assisted === true ? true : outcome.assisted === false ? false : null,
    regrouped: outcome.regrouped === true,
    seconds: Math.round(clamp(outcome.seconds, 0, 24 * 3600)),
  };
}
