import type { Effect, EventCard, ExpeditionDefinition, ExpeditionState } from '@/game/types';
import { formatMeters, hash } from '@/utils/number';

import { applyEffect, effectOf } from './apply';

function dayOf(state: ExpeditionState): number {
  return Math.floor(state.elapsedHours / 24);
}

function available(card: EventCard, state: ExpeditionState): boolean {
  if (card.repeat === 'day' && state.marks[`day-${card.id}`] === dayOf(state)) return false;
  if (card.repeat !== 'day' && !card.ephemeral && state.seen.includes(card.id)) return false;
  if (card.phase === 'up' && state.retreating) return false;
  if (card.phase === 'down' && !state.retreating) return false;
  if (card.checkpoints && !card.checkpoints.includes(state.checkpoint)) return false;
  if (card.when && !card.when(state)) return false;
  return true;
}

function pick(list: EventCard[], state: ExpeditionState): EventCard {
  const total = list.reduce((sum, card) => sum + (card.weight ?? 1), 0);
  let roll =
    hash(state.seed, dayOf(state), state.altitude, state.seen.length, state.retreating ? 1 : 0) % total;
  for (const card of list) {
    roll -= card.weight ?? 1;
    if (roll < 0) return card;
  }
  return list[list.length - 1];
}

export function currentEvent(state: ExpeditionState, def: ExpeditionDefinition): EventCard {
  const matching = def.events.filter((card) => available(card, state));
  const urgent = matching.filter((card) => card.urgent);
  const pool = urgent.length > 0 ? urgent : matching;
  if (pool.length === 0) return routeEvent(state, def);
  return pick(pool, state);
}

export function applyDecision(
  state: ExpeditionState,
  index: number,
  def: ExpeditionDefinition,
): ExpeditionState {
  return resolveDecision(state, index, def);
}

/**
 * The one place a card is spent. `adjust` lets a caller reshape the
 * choice's effect before it lands (a played challenge does this), so the
 * card is marked seen and the history written exactly once either way.
 */
export function resolveDecision(
  state: ExpeditionState,
  index: number,
  def: ExpeditionDefinition,
  adjust?: (effect: Effect, card: EventCard) => Effect,
): ExpeditionState {
  if (state.status !== 'active') return state;
  const card = currentEvent(state, def);
  const choice = card.choices[index];
  if (!choice) throw new Error(`Choice ${index} is not on ${card.id}.`);
  const base = effectOf(choice.effect, state);
  const effect = adjust ? adjust(base, card) : base;
  const next = applyEffect(state, effect, def);
  if (card.repeat === 'day') next.marks[`day-${card.id}`] = dayOf(state);
  else if (!card.ephemeral) next.seen = [...next.seen, card.id];
  next.history = next.history.map((entry, entryIndex) =>
    entryIndex === next.history.length - 1 ? { ...entry, choice: choice.label } : entry,
  );
  return next;
}

function routeEvent(state: ExpeditionState, def: ExpeditionDefinition): EventCard {
  const here = def.route.find((stop) => stop.id === state.checkpoint);
  const place = here?.name ?? (state.checkpoint === 'descent' ? 'Descent' : 'The route');
  const next = def.route[def.route.findIndex((stop) => stop.id === state.checkpoint) + 1];

  if (state.retreating || state.checkpoint === 'descent') {
    return {
      id: `route-down-${state.altitude}`,
      title: 'The way down is the expedition',
      text: `You are at ${place}, ${formatMeters(state.altitude)} m on this simplified route. Down still has weather, fatigue, and a team attached to it.`,
      category: 'descent',
      ephemeral: true,
      choices: [
        {
          label: 'Continue down',
          detail: 'Lose height while the team can still move.',
          effect: {
            note: 'You keep the descent moving.',
            hours: 8,
            move: 'down',
            supplies: -2,
            energy: -4,
          },
        },
        {
          label: 'Stop and put the team back together',
          detail: 'Time and supplies, spent on people.',
          effect: {
            note: 'You stop. Water, food, and a quieter hour.',
            hours: 8,
            move: 'hold',
            energy: 6,
            supplies: -4,
            teamCondition: 6,
            scores: {
              teamwork: { label: 'You stopped the descent for the team', delta: 8, mark: 'descent-stop' },
            },
          },
        },
      ],
    };
  }

  const choices: EventCard['choices'] = [];
  if (next) {
    choices.push({
      label: next.id === 'summit' ? 'Go for the summit bid' : `Move on toward ${next.name}`,
      detail: 'Height, if the body and the weather still allow a return.',
      effect: {
        note: `You leave ${place} for ${next.name}.`,
        hours: 10,
        move: 'up',
        energy: -6,
        supplies: -3,
      },
    });
  }
  choices.push({
    label: 'Hold a day',
    detail: 'No height. Lungs, food, and a calmer team.',
    effect: {
      note: `You hold at ${place}.`,
      hours: 16,
      move: 'hold',
      supplies: -4,
      scores: {
        judgment: { label: 'You spent a day not going higher', delta: 4, mark: `hold-${state.checkpoint}` },
      },
    },
  });
  if (state.checkpoint !== 'briefing') {
    choices.push({
      label: 'Turn around',
      detail: 'The summit stays. The walk out starts.',
      effect: {
        note: `You turn the expedition around at ${place}.`,
        hours: 6,
        move: 'retreat',
        scores: {
          judgment: {
            label: 'You turned around while the way down still existed',
            delta: 14 + def.route.findIndex((stop) => stop.id === state.checkpoint) * 2,
            mark: 'turned',
          },
          riskManagement: {
            label: 'You left before the margin was gone',
            delta: 10,
            mark: 'turned-risk',
          },
        },
      },
    });
  }

  return {
    id: `route-${state.checkpoint}-${dayOf(state)}`,
    title: place,
    text: 'The route is open. This is a game beat, not a plan for a real mountain.',
    category: 'route',
    ephemeral: true,
    choices,
  };
}
