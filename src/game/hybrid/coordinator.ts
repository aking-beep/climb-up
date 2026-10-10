import { applyEffect, currentEvent, resolveDecision } from '@/game/engine';
import type { Effect, EventCard, ExpeditionDefinition, ExpeditionState } from '@/game/types';
import { hash } from '@/utils/number';

import { combineEffect, sanitizeOutcome } from './reconcile';
import type {
  ChallengeDefinition,
  ChallengeOutcome,
  HybridSession,
  PendingChallenge,
  ResolveStatus,
} from './types';

/** An expedition and the challenges that can be played inside it. */
export type HybridExpedition = {
  def: ExpeditionDefinition;
  challenges: readonly ChallengeDefinition[];
};

export function createSession(game: HybridExpedition, state: ExpeditionState): HybridSession {
  return { expeditionId: game.def.id, state, prior: null, pending: null, resolvedAttempts: [] };
}

/** The challenge a card choice launches, if it launches one. */
export function challengeFor(
  game: HybridExpedition,
  card: EventCard,
  index: number,
): ChallengeDefinition | null {
  const choice = card.choices[index];
  if (!choice) return null;
  return game.challenges.find((item) => item.eventId === card.id && item.choiceLabel === choice.label) ?? null;
}

/**
 * Same state, same card, same moment: same id. A restarted attempt keeps
 * its id, and a spent id never comes back because history only grows.
 */
export function attemptIdFor(expeditionId: string, state: ExpeditionState, eventId: string): string {
  return `${expeditionId}:${state.seed.toString(36)}:${eventId}:${state.history.length}`;
}

export type ChooseResult = { session: HybridSession; launched: PendingChallenge | null };

/**
 * A card choice. A plain choice is spent now. A playable choice becomes a
 * pending challenge and leaves the expedition state exactly as it was.
 */
export function choose(game: HybridExpedition, session: HybridSession, index: number): ChooseResult {
  const { state } = session;
  if (state.status !== 'active') return { session, launched: null };
  if (session.pending) return { session, launched: session.pending };
  const card = currentEvent(state, game.def);
  const challenge = challengeFor(game, card, index);
  if (challenge) {
    const pending: PendingChallenge = {
      attemptId: attemptIdFor(game.def.id, state, card.id),
      challengeId: challenge.id,
      expeditionId: game.def.id,
      eventId: card.id,
      choiceIndex: index,
      choiceLabel: card.choices[index].label,
      historyLength: state.history.length,
      seed: hash(state.seed, state.history.length, 0xc11b),
    };
    return { session: { ...session, pending }, launched: pending };
  }
  const next = resolveDecision(state, index, game.def);
  return { session: { ...session, state: next, prior: state }, launched: null };
}

/** A camp beat that does not spend the card. Blocked while a challenge is open. */
export function play(game: HybridExpedition, session: HybridSession, effect: Effect | null): HybridSession {
  if (!effect || session.pending || session.state.status !== 'active') return session;
  return { ...session, state: applyEffect(session.state, effect, game.def), prior: session.state };
}

/** True when the pending attempt still belongs to the state it was opened on. */
function stillCurrent(game: HybridExpedition, session: HybridSession, pending: PendingChallenge): boolean {
  const { state } = session;
  if (state.status !== 'active') return false;
  if (state.history.length !== pending.historyLength) return false;
  const card = currentEvent(state, game.def);
  if (card.id !== pending.eventId) return false;
  return card.choices[pending.choiceIndex]?.label === pending.choiceLabel;
}

export type ResolveResult = { session: HybridSession; status: ResolveStatus };

/**
 * Lands a challenge outcome exactly once. The card's own effect and the
 * bounded outcome modifier are combined into one effect and spent through
 * the same engine path as any other decision.
 */
export function resolve(
  game: HybridExpedition,
  session: HybridSession,
  rawOutcome: ChallengeOutcome,
): ResolveResult {
  const outcome = sanitizeOutcome(rawOutcome);
  if (!outcome) return { session, status: 'invalid' };
  if (session.resolvedAttempts.includes(outcome.attemptId)) return { session, status: 'duplicate' };
  const pending = session.pending;
  if (!pending || pending.attemptId !== outcome.attemptId) return { session, status: 'stale' };
  if (!stillCurrent(game, session, pending)) {
    return {
      session: { ...session, pending: null, resolvedAttempts: [...session.resolvedAttempts, pending.attemptId] },
      status: 'stale',
    };
  }
  const challenge = game.challenges.find((item) => item.id === pending.challengeId);
  if (!challenge || outcome.challengeId !== challenge.id) return { session, status: 'invalid' };

  const before = session.state;
  const next = resolveDecision(before, pending.choiceIndex, game.def, (base) =>
    combineEffect(base, challenge.modifier(outcome, base, before)),
  );
  return {
    session: {
      ...session,
      state: next,
      prior: before,
      pending: null,
      resolvedAttempts: [...session.resolvedAttempts, pending.attemptId],
    },
    status: 'applied',
  };
}

/** Leaving the challenge without finishing it counts as backing off. */
export function abandon(game: HybridExpedition, session: HybridSession): ResolveResult {
  const pending = session.pending;
  if (!pending) return { session, status: 'stale' };
  return resolve(game, session, {
    attemptId: pending.attemptId,
    challengeId: pending.challengeId,
    result: 'retreat',
    staminaLeft: 100,
    slips: 0,
    assisted: null,
    regrouped: false,
    seconds: 0,
  });
}
