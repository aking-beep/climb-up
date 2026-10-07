import { CARDS, planCard, stormCard } from '@/game/cards';
import {
  BANDS,
  type Card,
  type Climber,
  type Ending,
  type GameState,
  type Move,
  ROSTER,
  type Score,
  type ScoreLine,
  altitudeTax,
  bandIndexForMeters,
  clamp,
  formatMeters,
  hash,
  isAlive,
  statusOf,
  weatherOn,
  worseLine,
} from '@/game/world';

const CAMP_BONUS = [0, 70, 160, 280, 420, 600, 820, 980];

export function createGame(seed = Math.floor(Math.random() * 1_000_000_000)): GameState {
  const safeSeed = seed >>> 0 || 1;
  return {
    seed: safeSeed,
    day: 1,
    band: 0,
    descending: false,
    summited: false,
    broughtHome: false,
    over: false,
    reason: '',
    warmth: 86,
    food: 88,
    daylight: 12,
    morale: 76,
    rope: 88,
    acclimatization: 20,
    weather: weatherOn(1, safeSeed),
    forecast: weatherOn(2, safeSeed),
    party: ROSTER.map((person) => ({ ...person })),
    seen: [],
    judgment: [],
    log: [],
    highPoint: BANDS[0].meters,
    marks: {},
    dugIn: false,
    lastNote: '',
  };
}

function cardAvailable(card: Card, state: GameState): boolean {
  if (card.repeat === 'day' && state.marks[`daylock-${card.id}`] === state.day) return false;
  if (card.repeat !== 'day' && !card.ephemeral && state.seen.includes(card.id)) return false;
  if (card.phase === 'up' && state.descending) return false;
  if (card.phase === 'down' && !state.descending) return false;
  if (card.bands && !card.bands.includes(BANDS[state.band].id)) return false;
  if (card.weather && !card.weather.includes(state.weather)) return false;
  if (card.when && !card.when(state)) return false;
  return true;
}

function pickWeighted(list: Card[], state: GameState): Card {
  const strain = state.party.reduce((sum, person) => sum + person.strain, 0);
  const total = list.reduce((sum, card) => sum + (card.weight ?? 1), 0);
  let roll =
    hash(state.seed, state.day, state.band, state.seen.length, state.descending ? 1 : 0, strain) %
    total;
  for (const card of list) {
    roll -= card.weight ?? 1;
    if (roll < 0) return card;
  }
  return list[list.length - 1];
}

export function currentCard(state: GameState): Card {
  const dynamic = state.weather === 'storm' ? [stormCard(state)] : [];
  const matching = [...dynamic, ...CARDS].filter((card) => cardAvailable(card, state));
  const urgent = matching.filter((card) => card.urgent);
  const pool = urgent.length > 0 ? urgent : matching;
  if (pool.length === 0) return planCard(state);
  return pickWeighted(pool, state);
}

function applyStrain(person: Climber, amount: number): string | null {
  if (!amount || person.strain >= 7) return null;
  const before = statusOf(person.strain);
  person.strain = Math.max(0, person.strain + amount);
  const after = statusOf(person.strain);
  if (amount < 0 || after === before) return null;
  return worseLine(person, after);
}

function strainAll(state: GameState, amount: number, notes: string[]) {
  if (!amount) return;
  const lines: string[] = [];
  for (const person of state.party) {
    const line = applyStrain(person, amount);
    if (line) lines.push(line);
  }
  const deaths = lines.filter((line) => line.endsWith('gone.'));
  const others = lines.filter((line) => !line.endsWith('gone.'));
  if (others.length >= 3) notes.push('The whole rope feels it.');
  else notes.push(...others);
  notes.push(...deaths);
}

function relieveAll(state: GameState, amount: number) {
  if (!amount) return;
  for (const person of state.party) {
    if (person.strain >= 7) continue;
    person.strain = Math.max(0, person.strain - amount);
  }
}

function leader(state: GameState): Climber {
  const you = state.party.find((person) => person.id === 'you');
  if (!you) throw new Error('The expedition has no leader.');
  return you;
}

function maybeHome(state: GameState) {
  if (
    state.descending &&
    state.band === 0 &&
    isAlive(leader(state)) &&
    state.highPoint > BANDS[0].meters
  ) {
    state.broughtHome = true;
    state.over = true;
    state.reason = 'home';
  }
}

function pickupCache(state: GameState, notes: string[]) {
  const here = BANDS[state.band].id;
  if (!state.descending || !state.marks.cache || state.marks.cacheTaken) return;
  if (here !== 'valley' && here !== 'road') return;
  state.marks.cacheTaken = true;
  state.food = clamp(state.food + 14, 0, 100);
  notes.push('The cache you buried is still there. The walk out gets a meal.');
}

function taxForClimb(state: GameState, notes: string[]) {
  const tax = altitudeTax(state.acclimatization, state.band);
  if (tax <= 0) return;
  notes.push('The altitude arrives before your blood does.');
  strainAll(state, tax, notes);
}

function markHighPoint(state: GameState) {
  const meters = BANDS[state.band].meters;
  if (meters > state.highPoint) state.highPoint = meters;
}

function stepUp(state: GameState, notes: string[]) {
  if (state.band < BANDS.length - 1) state.band += 1;
  if (state.band === BANDS.length - 1) state.summited = true;
  markHighPoint(state);
  taxForClimb(state, notes);
}

function stepDown(state: GameState, notes: string[]) {
  state.descending = true;
  if (state.band > 0) state.band -= 1;
  pickupCache(state, notes);
  maybeHome(state);
}

function resolveMove(state: GameState, move: Move, notes: string[]) {
  if (move === 'continue') {
    if (state.descending) stepDown(state, notes);
    else stepUp(state, notes);
    return;
  }
  if (move === 'summit') {
    state.band = BANDS.length - 1;
    state.summited = true;
    markHighPoint(state);
    taxForClimb(state, notes);
    return;
  }
  if (move === 'up') {
    stepUp(state, notes);
    return;
  }
  if (move === 'back') {
    if (state.band > 0) state.band -= 1;
    return;
  }
  if (move === 'turn' || move === 'down' || move === 'leave') {
    stepDown(state, notes);
  }
}

function resolveNight(state: GameState, notes: string[]) {
  const spent = state.weather;
  let warmthLoss = spent === 'clear' ? 3 : spent === 'rising' ? 6 : spent === 'whiteout' ? 10 : 14;
  if (state.dugIn) warmthLoss = Math.max(2, warmthLoss - 8);
  const foodLoss = 5 + (spent === 'storm' ? 2 : 0);
  state.warmth = clamp(state.warmth - warmthLoss, 0, 100);
  state.food = clamp(state.food - foodLoss, 0, 100);
  const acclimGain = spent === 'clear' ? 8 : spent === 'rising' ? 5 : 2;
  state.acclimatization = clamp(state.acclimatization + acclimGain, 0, 100);
  if (state.warmth <= 20) strainAll(state, 1, notes);
  if (state.food <= 0) strainAll(state, 1, notes);
  if (state.morale <= 12) strainAll(state, 1, notes);
  state.dugIn = false;
  state.day += 1;
  state.daylight = 12;
  state.weather = weatherOn(state.day, state.seed, state.descending);
  state.forecast = weatherOn(state.day + 1, state.seed, state.descending);
  notes.push(
    `Night at ${BANDS[state.band].name}. Day ${state.day} comes up ${state.weather}.`,
  );
  if (state.day >= 18 && !state.over) {
    state.over = true;
    state.reason = 'time';
    maybeHome(state);
  }
}

function checkTerminal(state: GameState) {
  if (state.over) return;
  if (!isAlive(leader(state))) {
    state.over = true;
    state.reason = 'leader';
    state.broughtHome = false;
    return;
  }
  if (state.party.every((person) => !isAlive(person))) {
    state.over = true;
    state.reason = 'party';
    state.broughtHome = false;
  }
}

export function applyChoice(state: GameState, index: number): { state: GameState; note: string } {
  if (state.over) return { state, note: state.lastNote };
  const card = currentCard(state);
  const choice = card.choices[index];
  if (!choice) throw new Error(`Choice ${index} is not on ${card.id}.`);

  const effect = choice.apply(state);
  const next: GameState = structuredClone(state);
  const notes: string[] = [];
  const day = state.day;

  next.daylight = clamp(next.daylight + (effect.daylight ?? -3), -6, 14);
  next.food = clamp(next.food + (effect.food ?? 0), 0, 100);
  next.warmth = clamp(next.warmth + (effect.warmth ?? 0), 0, 100);
  next.morale = clamp(next.morale + (effect.morale ?? 0), 0, 100);
  next.rope = clamp(next.rope + (effect.rope ?? 0), 0, 100);
  next.acclimatization = clamp(next.acclimatization + (effect.acclimatization ?? 0), 0, 100);

  if (effect.strain) {
    for (const person of next.party) {
      const amount = effect.strain[person.id];
      if (!amount) continue;
      if (amount < 0) {
        if (person.strain < 7) person.strain = Math.max(0, person.strain + amount);
        continue;
      }
      const line = applyStrain(person, amount);
      if (line) notes.push(line);
    }
  }
  strainAll(next, effect.strainAll ?? 0, notes);
  relieveAll(next, effect.relieve ?? 0);

  if (effect.note) notes.unshift(effect.note);
  resolveMove(next, effect.move ?? choice.move, notes);

  if (effect.judgment) {
    const mark = effect.judgment.mark;
    if (!mark || !next.marks[mark]) {
      if (mark) next.marks[mark] = true;
      next.judgment.push({ label: effect.judgment.label, delta: effect.judgment.delta });
    }
  }
  if (effect.mark) next.marks[effect.mark] = true;
  if (effect.dugIn) next.dugIn = true;

  if (card.repeat === 'day') next.marks[`daylock-${card.id}`] = day;
  else if (!card.ephemeral) next.seen.push(card.id);

  checkTerminal(next);
  if (!next.over && next.daylight <= 0) resolveNight(next, notes);
  checkTerminal(next);

  next.lastNote = notes.filter(Boolean).join(' ');
  next.log = [...next.log, { day, text: next.lastNote }];
  return { state: next, note: next.lastNote };
}

export function survivors(state: GameState): Climber[] {
  return state.party.filter(isAlive);
}

export function scoreGame(state: GameState): Score {
  const lines: ScoreLine[] = [];
  const living = survivors(state);
  const dead = state.party.filter((person) => !isAlive(person));
  const camp = bandIndexForMeters(state.highPoint);

  if (state.broughtHome) {
    lines.push({ label: `Brought home (${living.length})`, delta: living.length * 1000 });
    for (const person of living) {
      const status = statusOf(person.strain);
      const delta = status === 'fit' ? 180 : status === 'strained' ? 60 : status === 'hurt' ? -40 : -220;
      lines.push({ label: `${person.name} came down ${status}`, delta });
    }
    if (dead.length === 0) {
      lines.push({
        label: `Walked them down from ${BANDS[camp].name}`,
        delta: CAMP_BONUS[camp] ?? 0,
      });
    } else {
      lines.push({
        label: `Came down from ${BANDS[camp].name} short-handed`,
        delta: Math.round((CAMP_BONUS[camp] ?? 0) * 0.35),
      });
    }
  } else {
    lines.push({ label: 'The party did not come home', delta: 0 });
    lines.push({ label: 'Still breathing when it ended', delta: living.length * 80 });
  }

  for (const mark of state.judgment) {
    lines.push({ label: mark.label, delta: mark.delta });
  }

  const noneCritical = living.every((person) => person.strain <= 4);
  if (state.summited && state.broughtHome && dead.length === 0 && noneCritical) {
    lines.push({ label: 'Summit, with the people you started with', delta: 650 });
  } else if (state.summited && state.broughtHome && dead.length > 0) {
    lines.push({ label: 'They will say you summited', delta: -450 });
  } else if (state.summited && !state.broughtHome) {
    lines.push({ label: 'A high point that stayed there', delta: -500 });
  }

  for (const person of dead) {
    lines.push({
      label: `${person.name} did not come down`,
      delta: state.broughtHome ? -350 : -150,
    });
  }

  const total = lines.reduce((sum, line) => sum + line.delta, 0);
  return {
    total,
    lines,
    highPoint: state.highPoint,
    highCamp: BANDS[camp].name,
    summited: state.summited,
    broughtHome: state.broughtHome,
    highPointNote: `High point ${formatMeters(state.highPoint)} m. That number is not in the ledger.`,
  };
}

export function endingFor(state: GameState): Ending {
  const living = survivors(state);
  const dead = state.party.filter((person) => !isAlive(person));
  const youAlive = isAlive(leader(state));
  const allAlive = dead.length === 0;
  const anyCritical = living.some((person) => person.strain >= 5);
  const camp = bandIndexForMeters(state.highPoint);

  if (!youAlive) {
    return {
      title: 'The rope went slack',
      text: 'You were the decision. When you stopped making them, the mountain kept whatever plan was left.',
    };
  }
  if (!state.broughtHome && state.band === 0 && state.highPoint <= BANDS[0].meters) {
    return {
      title: 'You stayed at the road',
      text: 'The truck is still warm. So is everyone in it. Kharung did not get a vote, and neither did the climb.',
    };
  }
  if (!state.broughtHome) {
    return {
      title: 'Still on the mountain',
      text: 'The climb has a high point. The walk out does not. That is the whole game, and it ended before the road.',
    };
  }
  if (state.summited && allAlive && !anyCritical) {
    return {
      title: 'Everyone comes down',
      text: 'You stood on it, and then you did the part people forget to tell. Four of you are at the road.',
    };
  }
  if (state.summited && dead.length > 0) {
    return {
      title: 'The story they will tell wrong',
      text: 'The summit will be the first sentence. It should not be. Someone is missing from the roadhead.',
    };
  }
  if (state.summited && anyCritical) {
    return {
      title: 'Down, and not untouched',
      text: 'The top happened. So did the cost. You got them off the mountain, and one of them will not call it clean.',
    };
  }
  if (allAlive && camp >= 5) {
    return {
      title: 'The mountain keeps the rest',
      text: 'You turned around with the top still above you. Everyone who started is at the truck. That is a win.',
    };
  }
  if (allAlive) {
    return {
      title: 'You walked them out',
      text: 'No photograph from the top. Four people who can still tell you what the weather was doing.',
    };
  }
  return {
    title: 'Enough of you',
    text: 'The road has fewer voices than it started with. Coming down is still the only score that counts, and it is not a clean one.',
  };
}
