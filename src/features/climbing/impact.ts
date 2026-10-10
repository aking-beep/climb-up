import type { OutcomeModifier } from '@/game/hybrid/types';
import { BUCKET_LABEL, STAT_KEYS, type ScoreBucket, type StatKey } from '@/game/types';

const STAT_LABEL: Record<StatKey, string> = {
  health: 'Health',
  energy: 'Energy',
  acclimatization: 'Acclimatization',
  oxygen: 'Oxygen',
  supplies: 'Supplies',
  weatherRisk: 'Weather risk',
  objectiveRisk: 'Objective risk',
  teamCondition: 'Team',
};

const BUCKETS = Object.keys(BUCKET_LABEL) as ScoreBucket[];

function signed(value: number): string {
  return value > 0 ? `+${value}` : `${value}`;
}

/**
 * What a climb did to the expedition, in words a player can read at a
 * glance: "Team +5", "Teamwork +6: You stopped for Marco on the wall".
 */
export function describeImpact(modifier: OutcomeModifier | null): string[] {
  if (!modifier) return [];
  const lines: string[] = [];
  const stats = STAT_KEYS.filter((key) => (modifier.stats?.[key] ?? 0) !== 0).map(
    (key) => `${STAT_LABEL[key]} ${signed(modifier.stats![key]!)}`,
  );
  if (stats.length > 0) lines.push(stats.join(' · '));
  for (const bucket of BUCKETS) {
    const note = modifier.scores?.[bucket];
    if (note && note.delta !== 0) lines.push(`${BUCKET_LABEL[bucket]} ${signed(note.delta)}: ${note.label}`);
  }
  return lines;
}

/** Just the named stat and score deltas, for a one-line comparison. */
export function stakesLine(modifier: OutcomeModifier | null, stat: StatKey, bucket: ScoreBucket): string {
  if (!modifier) return '';
  const parts: string[] = [];
  const value = modifier.stats?.[stat] ?? 0;
  if (value !== 0) parts.push(`${STAT_LABEL[stat]} ${signed(value)}`);
  const note = modifier.scores?.[bucket];
  if (note && note.delta !== 0) parts.push(`${BUCKET_LABEL[bucket]} ${signed(note.delta)}`);
  return parts.join(', ');
}
