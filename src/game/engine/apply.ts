import type { Effect, ExpeditionDefinition, ExpeditionState, Move, ScoreBucket } from '@/game/types';
import { hash } from '@/utils/number';

import { altitudeStrain, boundAltitude, boundStat, pressure } from './rules';

const BUCKETS: ScoreBucket[] = ['judgment', 'riskManagement', 'teamwork', 'preparation'];

function emptyLedger(): ExpeditionState['ledger'] {
  return { judgment: [], riskManagement: [], teamwork: [], preparation: [] };
}

function cloneState(state: ExpeditionState): ExpeditionState {
  return {
    ...state,
    history: state.history.map((entry) => ({ ...entry })),
    seen: [...state.seen],
    marks: { ...state.marks },
    ledger: {
      judgment: state.ledger.judgment.map((note) => ({ ...note })),
      riskManagement: state.ledger.riskManagement.map((note) => ({ ...note })),
      teamwork: state.ledger.teamwork.map((note) => ({ ...note })),
      preparation: state.ledger.preparation.map((note) => ({ ...note })),
    },
  };
}

function clampStats(state: ExpeditionState) {
  state.health = boundStat(state.health);
  state.energy = boundStat(state.energy);
  state.acclimatization = boundStat(state.acclimatization);
  state.oxygen = boundStat(state.oxygen);
  state.supplies = boundStat(state.supplies);
  state.weatherRisk = boundStat(state.weatherRisk);
  state.objectiveRisk = boundStat(state.objectiveRisk);
  state.teamCondition = boundStat(state.teamCondition);
  state.altitude = boundAltitude(state.altitude);
  if (state.altitude > state.highestAltitude) state.highestAltitude = state.altitude;
}

function homeMeters(def: ExpeditionDefinition): number {
  return def.descentLadder[def.descentLadder.length - 1] ?? def.route[0].meters;
}

function finish(state: ExpeditionState, def: ExpeditionDefinition) {
  state.checkpoint = 'complete';
  state.altitude = Math.min(state.altitude, homeMeters(def));
  if (state.health > 0 && state.teamCondition > 0) {
    state.returnedSafely = true;
    state.status = 'complete';
  } else {
    state.returnedSafely = false;
    state.status = 'failed';
  }
}

function fail(state: ExpeditionState) {
  state.returnedSafely = false;
  state.status = 'failed';
}

function stepUp(state: ExpeditionState, def: ExpeditionDefinition, notes: string[]) {
  if (state.retreating) return;
  const index = def.route.findIndex((stop) => stop.id === state.checkpoint);
  const next = def.route[index + 1];
  if (!next) return;
  state.checkpoint = next.id;
  state.altitude = next.meters;
  if (next.meters > state.highestAltitude) state.highestAltitude = next.meters;
  if (next.id === 'summit') state.summitReached = true;
  const strain = altitudeStrain(state.acclimatization, next.meters);
  if (strain.health !== 0) {
    state.health += strain.health;
    state.energy += strain.energy;
    notes.push('Inside this game, the air arrives before the body does.');
  }
  if (next.id === 'camp1') state.objectiveRisk += 8;
  if (next.id === 'camp3') state.objectiveRisk += 6;
  if (next.id === 'camp4') state.weatherRisk += 8;
  if (next.id === 'summit') state.objectiveRisk += 10;
}

function stepDown(state: ExpeditionState, def: ExpeditionDefinition) {
  state.retreating = true;
  const lower = def.descentLadder.find((meters) => meters < state.altitude - 30);
  if (lower === undefined) {
    finish(state, def);
    return;
  }
  state.altitude = lower;
  if (lower <= homeMeters(def) + 1) finish(state, def);
  else state.checkpoint = 'descent';
}

function resolveMove(state: ExpeditionState, move: Move, def: ExpeditionDefinition, notes: string[]) {
  if (move === 'summit' || move === 'up') {
    stepUp(state, def, notes);
    return;
  }
  if (move === 'retreat' || move === 'down') {
    stepDown(state, def);
    return;
  }
  // Camp rest. A challenge failure uses `wait` so it cannot collect this gift.
  if (move === 'hold' && state.altitude >= 3000) {
    state.acclimatization += 8;
    state.energy += 5;
    notes.push('The rest is spent letting the expedition catch the altitude.');
  }
}

function advanceTime(state: ExpeditionState, hours: number, notes: string[]) {
  const span = Math.max(0, hours);
  state.elapsedHours += span;
  state.supplies -= Math.round(span / 8) * 2;
  state.energy -= Math.round(span / 10);
  if (state.altitude >= 7200 && state.oxygen < 30) {
    state.health -= 4;
    state.energy -= 4;
    notes.push('The oxygen reserve is thin for this height, in the game’s terms.');
  }
  if (state.supplies <= 0) {
    state.health -= 5;
    state.teamCondition -= 5;
    notes.push('The supplies are gone. The team starts spending itself.');
  }
  const drift = (hash(state.seed, state.elapsedHours, 3) % 5) - 2;
  state.weatherRisk += drift;
  if (state.weatherRisk >= 75 && state.altitude >= 6400) state.objectiveRisk += 4;
}

function applyPressure(state: ExpeditionState, notes: string[]) {
  const level = pressure(state);
  if (level <= 40) return;
  const roll = hash(state.seed, state.elapsedHours, state.altitude, state.history.length) % 100;
  if (roll < level - 35) {
    const hit = 3 + Math.floor((level - 35) / 20);
    state.health -= hit;
    state.energy -= 2;
    notes.push('Conditions take a piece of the team’s margin.');
  }
}

function addScores(state: ExpeditionState, effect: Effect) {
  if (!effect.scores) return;
  for (const bucket of BUCKETS) {
    const note = effect.scores[bucket];
    if (!note) continue;
    if (note.mark && state.marks[note.mark]) continue;
    if (note.mark) state.marks[note.mark] = true;
    state.ledger[bucket].push({ label: note.label, delta: note.delta, mark: note.mark });
  }
}

function evaluate(state: ExpeditionState, def: ExpeditionDefinition) {
  if (state.status !== 'active') return;
  if (state.health <= 0 || state.teamCondition <= 0) {
    fail(state);
    return;
  }
  if (state.elapsedHours >= 24 * 36) {
    if (state.altitude <= 3600 && state.health > 0 && state.teamCondition > 0) finish(state, def);
    else fail(state);
  }
}

export function applyEffect(
  state: ExpeditionState,
  effect: Effect,
  def: ExpeditionDefinition,
): ExpeditionState {
  if (state.status !== 'active') return state;
  const next = cloneState(state);
  if (next.ledger.judgment === undefined) next.ledger = emptyLedger();
  const notes: string[] = [];
  if (effect.note) notes.push(effect.note);

  next.health += effect.health ?? 0;
  next.energy += effect.energy ?? 0;
  next.acclimatization += effect.acclimatization ?? 0;
  next.oxygen += effect.oxygen ?? 0;
  next.supplies += effect.supplies ?? 0;
  next.weatherRisk += effect.weatherRisk ?? 0;
  next.objectiveRisk += effect.objectiveRisk ?? 0;
  next.teamCondition += effect.teamCondition ?? 0;

  resolveMove(next, effect.move ?? 'hold', def, notes);
  if (effect.visitMeters !== undefined) {
    const visited = boundAltitude(effect.visitMeters);
    if (visited > next.highestAltitude) next.highestAltitude = visited;
  }
  advanceTime(next, effect.hours ?? 6, notes);
  applyPressure(next, notes);
  addScores(next, effect);
  if (effect.mark) next.marks[effect.mark] = true;
  clampStats(next);
  evaluate(next, def);

  const text = notes.filter(Boolean).join(' ');
  next.lastNote = text;
  next.history = [
    ...next.history,
    { checkpoint: state.checkpoint, hours: next.elapsedHours, choice: effect.note, note: text },
  ];
  return next;
}

export function effectOf(choiceEffect: Effect | ((state: ExpeditionState) => Effect), state: ExpeditionState): Effect {
  return typeof choiceEffect === 'function' ? choiceEffect(state) : choiceEffect;
}
