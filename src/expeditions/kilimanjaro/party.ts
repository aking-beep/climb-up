import type { Effect, ExpeditionState } from '@/game/types';
import { clamp } from '@/utils/number';

import { PARTY, dayPhase, expeditionHour, type PartyId, type Pose } from '@/components/world/scene';

/**
 * The four people are the party, in the HD-2D sense: each one can be
 * tapped, and each job changes the morning. Kilimanjaro's pace, water,
 * and head count are the jobs. This is game fiction, not a routine to copy.
 */
const BIAS: Record<PartyId, { health: number; energy: number; spirits: number }> = {
  you: { health: 0, energy: 0, spirits: 0 },
  lena: { health: 2, energy: 6, spirits: 8 },
  marco: { health: -6, energy: -12, spirits: -10 },
  jun: { health: 8, energy: -2, spirits: 2 },
};

const DUTY: Record<PartyId, string> = {
  lena: 'Guide. She sets pole pole, the slow pace this mountain is walked at.',
  jun: 'Doctor, in the game. He walks the tents and says if the day should wait.',
  marco: 'Climber. He feels the pace first. If he sits, the party sits.',
  you: 'Lead. The card below is still your decision.',
};

export type MemberView = {
  id: PartyId;
  name: string;
  role: string;
  duty: string;
  health: number;
  energy: number;
  spirits: number;
  pose: Pose;
  line: string;
};

export type RoutineId = 'pole-pole' | 'water' | 'head-count';

export type RoutineAction = {
  id: RoutineId;
  label: string;
  detail: string;
  done: boolean;
  enabled: boolean;
};

function tended(state: ExpeditionState, id: PartyId): boolean {
  return state.marks[`tend-${id}`] === true;
}

export function membersOf(state: ExpeditionState): MemberView[] {
  return PARTY.map((person) => {
    const bias = BIAS[person.id];
    const care = tended(state, person.id) ? 1 : 0;
    const health = clamp(state.health + bias.health + care * 4, 0, 100);
    const energy = clamp(state.energy + bias.energy + care * 8, 0, 100);
    const spirits = clamp(state.teamCondition + bias.spirits + care * 8, 0, 100);
    const pose: Pose = energy < 36 || spirits < 40 ? 'kneel' : energy < 56 || spirits < 62 ? 'lag' : 'walk';
    return {
      id: person.id,
      name: person.name,
      role: person.role,
      duty: DUTY[person.id],
      health,
      energy,
      spirits,
      pose,
      line: memberLine(person.id, pose, care === 1),
    };
  });
}

function memberLine(id: PartyId, pose: Pose, care: boolean): string {
  if (pose === 'kneel') return care ? 'Down, but someone stayed with them.' : 'Down. The day can wait.';
  if (pose === 'lag') return 'Off the pace.';
  if (id === 'lena') return 'Ready to set pole pole.';
  if (id === 'jun') return 'Ready to walk the tents.';
  if (id === 'marco') return care ? 'Back on his feet.' : 'Carrying his share.';
  return 'The decision is still yours.';
}

function night(state: ExpeditionState): boolean {
  return dayPhase(expeditionHour(state.elapsedHours)) === 'night';
}

export function routineActions(state: ExpeditionState): RoutineAction[] {
  const dark = night(state);
  const pole = state.marks[`pole-${state.checkpoint}`] === true;
  const water = state.marks[`water-${state.checkpoint}`] === true;
  const head = state.marks[`head-${state.checkpoint}`] === true;
  return [
    {
      id: 'pole-pole',
      label: dark ? 'Slow the first hour' : 'Pole pole',
      detail: dark ? 'Lena keeps the dark hour slow.' : 'Lena sets a slow pace before anyone leaves.',
      done: pole,
      enabled: !pole,
    },
    {
      id: 'water',
      label: dark ? 'Drink before the dark' : 'Put the water on',
      detail: state.supplies < 6 ? 'The stores are too thin.' : 'A camp beat. It spends a little of the stores.',
      done: water,
      enabled: !water && state.supplies >= 6,
    },
    {
      id: 'head-count',
      label: dark ? 'Check before anyone leaves' : 'Head count',
      detail: 'Jun walks the party. In this game, a quiet person stops the day. Not a diagnosis.',
      done: head,
      enabled: !head,
    },
  ];
}

export function routineEffect(state: ExpeditionState, id: RoutineId): Effect | null {
  const action = routineActions(state).find((item) => item.id === id);
  if (!action?.enabled) return null;
  if (id === 'pole-pole') {
    return {
      note: night(state)
        ? 'Lena keeps the first dark hour slow.'
        : 'Lena sets pole pole. The party will walk slowly.',
      hours: 1,
      move: 'hold',
      mark: `pole-${state.checkpoint}`,
      acclimatization: 3,
      energy: 2,
      teamCondition: 3,
      scores: {
        judgment: { label: 'You let Lena set pole pole', delta: 4, mark: 'pole-pole' },
      },
    };
  }
  if (id === 'water') {
    return {
      note: 'The water goes on. The stores pay for it.',
      hours: 1,
      move: 'hold',
      mark: `water-${state.checkpoint}`,
      supplies: -1,
      health: 1,
      energy: 1,
      scores: {
        preparation: { label: 'You treated water as part of camp', delta: 4, mark: 'camp-water' },
      },
    };
  }
  return {
    note: 'Jun walks the tents. In this game, that is a reason to notice the quiet one. Not a diagnosis.',
    hours: 1,
    move: 'hold',
    mark: `head-${state.checkpoint}`,
    teamCondition: 4,
    scores: {
      teamwork: { label: 'Jun counted the party before the trail', delta: 5, mark: 'head-count' },
    },
  };
}

export function tendEffect(state: ExpeditionState, id: PartyId): Effect | null {
  if (tended(state, id)) return null;
  const member = membersOf(state).find((person) => person.id === id);
  if (!member || member.pose === 'walk') return null;
  return {
    note: `You sit with ${member.name}. The party waits with you.`,
    hours: 1,
    move: 'hold',
    mark: `tend-${id}`,
    energy: 4,
    teamCondition: 5,
    scores: {
      teamwork: { label: `You sat with ${member.name}`, delta: 6, mark: `sit-${id}` },
    },
  };
}
