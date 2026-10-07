import type { ExpeditionScore, ExpeditionState, LedgerNote, ScoreBucket, ScoreLine } from '@/game/types';
import { BUCKET_LABEL } from '@/game/types';
import { clamp } from '@/utils/number';

function sum(notes: LedgerNote[]): number {
  return notes.reduce((total, note) => total + note.delta, 0);
}

function bucket(notes: LedgerNote[], base: number): number {
  return clamp(Math.round(base + sum(notes)), 0, 100);
}

export function scoreExpedition(state: ExpeditionState): ExpeditionScore {
  const judgment = bucket(state.ledger.judgment, 52);
  const riskCore = bucket(state.ledger.riskManagement, 50);
  const teamCore = bucket(state.ledger.teamwork, 58);
  const prepCore = bucket(state.ledger.preparation, 56);

  const teamwork = clamp(Math.round(teamCore * 0.7 + state.teamCondition * 0.3), 0, 100);
  const preparation = clamp(
    Math.round(prepCore * 0.65 + state.supplies * 0.15 + state.oxygen * 0.2),
    0,
    100,
  );
  const riskManagement = riskCore;

  let overall =
    judgment * 0.34 + riskManagement * 0.28 + teamwork * 0.18 + preparation * 0.2;

  if (state.returnedSafely) overall += 6;
  else overall = Math.min(overall, 40);

  const strongReturn =
    state.summitReached &&
    state.returnedSafely &&
    judgment >= 68 &&
    state.teamCondition >= 35 &&
    state.health >= 25;

  if (strongReturn) overall += 12;
  if (state.summitReached && !state.returnedSafely) overall = Math.min(overall, 36);

  overall = clamp(Math.round(overall), 0, 100);

  const lines: ScoreLine[] = [];
  const buckets: ScoreBucket[] = ['judgment', 'riskManagement', 'teamwork', 'preparation'];
  for (const key of buckets) {
    for (const note of state.ledger[key]) {
      lines.push({ bucket: BUCKET_LABEL[key], label: note.label, delta: note.delta });
    }
  }

  return {
    highestAltitude: state.highestAltitude,
    summitReached: state.summitReached,
    returnedSafely: state.returnedSafely,
    successful: state.returnedSafely,
    judgment,
    riskManagement,
    teamwork,
    preparation,
    overall,
    explanation: explain(state, {
      judgment,
      riskManagement,
      teamwork,
      preparation,
      overall,
    }),
    lines,
  };
}

function explain(
  state: ExpeditionState,
  scores: {
    judgment: number;
    riskManagement: number;
    teamwork: number;
    preparation: number;
    overall: number;
  },
): string {
  const opening = openingLine(state);
  const parts = [
    opening,
    `Judgment ${scores.judgment}. Risk management ${scores.riskManagement}. Teamwork ${scores.teamwork}. Preparation ${scores.preparation}.`,
  ];
  const notes = [
    ...state.ledger.judgment,
    ...state.ledger.riskManagement,
    ...state.ledger.teamwork,
    ...state.ledger.preparation,
  ];
  const best = notes.reduce<LedgerNote | null>(
    (winner, note) => (winner === null || note.delta > winner.delta ? note : winner),
    null,
  );
  const worst = notes.reduce<LedgerNote | null>(
    (loser, note) => (loser === null || note.delta < loser.delta ? note : loser),
    null,
  );
  if (best && best.delta > 0) parts.push(best.label);
  if (worst && worst.delta < 0 && worst !== best) parts.push(worst.label);
  return parts.join(' ');
}

function openingLine(state: ExpeditionState): string {
  if (state.summitReached && state.returnedSafely) {
    return 'You stood on the summit and still brought the expedition down. That is the rare result.';
  }
  if (state.returnedSafely && !state.summitReached) {
    return 'You came back without the summit. How high you climbed is not how this is scored.';
  }
  if (state.summitReached && !state.returnedSafely) {
    return 'The summit is recorded. The expedition is not a success, because it did not come back.';
  }
  return 'The expedition ended on the mountain. Getting back was the result that counted.';
}
