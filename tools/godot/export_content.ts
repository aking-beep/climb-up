/**
 * Exports the Expo game's Kilimanjaro expedition for the Godot port:
 *
 *   godot/modes/expedition/data/kilimanjaro.json   route, cards, party
 *   godot/tests/fixtures/expeditions.json           scripted playthroughs,
 *       run through the real TypeScript coordinator, with the full state
 *       after every step, so the GDScript engine can be checked against it
 *
 *   node --experimental-strip-types --no-warnings --import ./tools/godot/register.mjs tools/godot/export_content.ts
 *
 * Card conditions (`when`) are functions in TypeScript. Mark checks are
 * recorded by probing them; the three stat checks are encoded by hand and
 * verified here against the original functions.
 */
import { writeFileSync, mkdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { PARTY } from '@/components/world/scene';
import { kilimanjaro, startKilimanjaro, currentKilimanjaroEvent } from '@/expeditions/kilimanjaro';
import { KILI_CHALLENGES, kilimanjaroHybrid } from '@/expeditions/kilimanjaro/challenges';
import { KILI_PROGRESS, KILI_GATE, KILI_SUMMIT } from '@/expeditions/kilimanjaro/route';
import { routineEffect, routineActions, tendEffect, membersOf } from '@/expeditions/kilimanjaro/party';
import { choose, createSession, play, resolve, challengeFor } from '@/game/hybrid/coordinator';
import type { ChallengeOutcome, HybridSession } from '@/game/hybrid/types';
import type { EventCard, ExpeditionState } from '@/game/types';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

type Condition = { mark: string } | { stat: string; lt?: number; gt?: number };

const STAT_CONDITIONS: Record<string, Condition> = {};

function encodeWhen(card: EventCard): Condition | null {
  if (!card.when) return null;
  const marks: string[] = [];
  const stats: string[] = [];
  const probe = new Proxy({} as Record<string, unknown>, {
    get(_t, key: string) {
      if (key === 'marks') {
        return new Proxy({}, { get(_m, mark: string) { marks.push(mark); return true; } });
      }
      stats.push(key);
      return 50;
    },
  });
  card.when(probe as unknown as ExpeditionState);
  if (marks.length === 1 && stats.length === 0) return { mark: marks[0] };
  if (stats.length === 1 && marks.length === 0) {
    const stat = stats[0];
    // Find the threshold by scanning, then confirm the encoding everywhere.
    let condition: Condition | null = null;
    for (let v = 0; v <= 101 && !condition; v += 1) {
      const a = card.when({ [stat]: v } as unknown as ExpeditionState);
      const b = card.when({ [stat]: v + 1 } as unknown as ExpeditionState);
      if (a && !b) condition = { stat, lt: v + 1 };
      if (!a && b) condition = { stat, gt: v };
    }
    if (!condition) throw new Error(`No threshold for ${card.id}`);
    for (let v = -5; v <= 110; v += 1) {
      const want = card.when({ [stat]: v } as unknown as ExpeditionState);
      const got = 'lt' in condition && condition.lt !== undefined ? v < condition.lt : v > (condition as { gt: number }).gt;
      if (want !== got) throw new Error(`Condition mismatch for ${card.id} at ${v}`);
    }
    STAT_CONDITIONS[card.id] = condition;
    return condition;
  }
  throw new Error(`Cannot encode the condition on ${card.id}`);
}

function cardJson(card: EventCard) {
  const { when: _when, ...rest } = card;
  const choices = card.choices.map((choice) => {
    if (typeof choice.effect === 'function') throw new Error(`Function effect on ${card.id}`);
    return choice;
  });
  return { ...rest, choices, when: encodeWhen(card) };
}

const content = {
  id: kilimanjaro.id,
  title: kilimanjaro.title,
  routeName: kilimanjaro.routeName,
  disclaimer: kilimanjaro.disclaimer,
  route: kilimanjaro.route,
  progress: KILI_PROGRESS,
  descentLadder: kilimanjaro.descentLadder,
  gate: KILI_GATE,
  summit: KILI_SUMMIT,
  party: PARTY,
  challenges: KILI_CHALLENGES.map((c) => ({ id: c.id, title: c.title, gate: c.gate })),
  events: kilimanjaro.events.map(cardJson),
};

// --- Scripted playthroughs -------------------------------------------------

const CAREFUL = [
  'Walk the forest and set camp',
  'Sleep under the trees',
  'Break camp and keep a patient pace',
  'Stake the tents and sleep',
  'Cross the plateau and pitch at Shira 2',
  'Sleep before the tower',
  'Tag the tower, then sleep low',
  'Sleep and leave the wall for morning',
  'Climb the wall and camp at Karanga',
  'Lie down in the valley',
  'Take the extra day',
  'Break camp for Barafu',
  'Lie down on the ridge',
  'Rest the day',
  'Keep the pace through the dark',
];

type Step =
  | { kind: 'choose'; index: number; label: string }
  | { kind: 'climb'; outcome: Omit<ChallengeOutcome, 'attemptId'> }
  | { kind: 'routine'; id: string }
  | { kind: 'tend'; id: string };

function snapshot(session: HybridSession) {
  const s = session.state;
  const card = s.status === 'active' ? currentKilimanjaroEvent(s) : null;
  return {
    state: JSON.parse(JSON.stringify(s)),
    card: card ? { id: card.id, title: card.title, choices: card.choices.map((c) => c.label) } : null,
    pending: session.pending ? { challengeId: session.pending.challengeId, attemptId: session.pending.attemptId } : null,
    playable: card ? card.choices.map((_c, i) => challengeFor(kilimanjaroHybrid, s, card, i)?.id ?? null) : [],
    members: membersOf(s).map((m) => ({ id: m.id, pose: m.pose, health: m.health, energy: m.energy, spirits: m.spirits })),
    routines: routineActions(s).map((r) => ({ id: r.id, label: r.label, enabled: r.enabled })),
  };
}

type Policy = {
  name: string;
  seed: number;
  pick: (card: EventCard, s: ExpeditionState, step: number) => number;
  climb: (challengeId: string, attempt: number) => Omit<ChallengeOutcome, 'attemptId'>;
  beats?: (s: ExpeditionState, step: number) => Step | null;
};

const ok = (challengeId: string, patch: Partial<ChallengeOutcome> = {}) => ({
  challengeId: challengeId as ChallengeOutcome['challengeId'],
  result: 'complete' as const,
  staminaLeft: 60,
  slips: 0,
  assisted: challengeId === 'lava-tower' ? null : true,
  regrouped: false,
  seconds: 150,
  ...patch,
});

function careful(card: EventCard): number {
  const i = card.choices.findIndex((c) => CAREFUL.includes(c.label));
  return i >= 0 ? i : 0;
}

const POLICIES: Policy[] = [
  { name: 'careful-7', seed: 7, pick: careful, climb: (id) => ok(id) },
  { name: 'careful-11-slips', seed: 11, pick: careful, climb: (id) => ok(id, { slips: 2, staminaLeft: 18, assisted: id === 'lava-tower' ? null : false }) },
  {
    name: 'careful-23-beats',
    seed: 23,
    pick: careful,
    climb: (id) => ok(id, { regrouped: true }),
    beats: (s, step) => {
      const free = routineActions(s).find((r) => r.enabled);
      if (step % 2 === 0 && free) return { kind: 'routine', id: free.id };
      const down = membersOf(s).find((m) => m.pose !== 'walk' && tendEffect(s, m.id));
      return down ? { kind: 'tend', id: down.id } : null;
    },
  },
  {
    name: 'retreat-then-climb-5',
    seed: 5,
    pick: careful,
    climb: (id, attempt) => (attempt === 0 ? ok(id, { result: 'retreat' }) : attempt === 1 ? ok(id, { result: 'fail', slips: 3 }) : ok(id)),
  },
  { name: 'first-choice-3', seed: 3, pick: () => 0, climb: (id) => ok(id) },
  { name: 'last-choice-9', seed: 9, pick: (card) => card.choices.length - 1, climb: (id) => ok(id) },
  {
    name: 'turn-at-barranco-13',
    seed: 13,
    pick: (card, s) => {
      if (s.checkpoint === 'camp2' && !s.retreating) {
        const turn = card.choices.findIndex((c) => /turn|down|walk out/i.test(c.label));
        if (turn >= 0) return turn;
      }
      return careful(card);
    },
    climb: (id) => ok(id),
  },
];

function play_(policy: Policy) {
  let session = createSession(kilimanjaroHybrid, startKilimanjaro(policy.seed));
  const steps: { action: Step; after: ReturnType<typeof snapshot> }[] = [];
  const attempts: Record<string, number> = {};
  const start = snapshot(session);
  for (let n = 0; n < 120 && session.state.status === 'active'; n += 1) {
    const beat = policy.beats?.(session.state, n);
    if (beat) {
      if (beat.kind !== 'routine' && beat.kind !== 'tend') throw new Error('beats are routines or tending');
      const effect = beat.kind === 'routine'
        ? routineEffect(session.state, beat.id as never)
        : tendEffect(session.state, beat.id as never);
      session = play(kilimanjaroHybrid, session, effect);
      steps.push({ action: beat, after: snapshot(session) });
      continue;
    }
    const card = currentKilimanjaroEvent(session.state);
    const index = policy.pick(card, session.state, n);
    const result = choose(kilimanjaroHybrid, session, index);
    session = result.session;
    steps.push({ action: { kind: 'choose', index, label: card.choices[index].label }, after: snapshot(session) });
    if (result.launched) {
      const id = result.launched.challengeId;
      const outcome = policy.climb(id, attempts[id] ?? 0);
      attempts[id] = (attempts[id] ?? 0) + 1;
      const r = resolve(kilimanjaroHybrid, session, { ...outcome, attemptId: result.launched.attemptId });
      if (r.status !== 'applied') throw new Error(`${policy.name}: ${r.status}`);
      session = r.session;
      steps.push({ action: { kind: 'climb', outcome }, after: snapshot(session) });
    }
  }
  return { name: policy.name, seed: policy.seed, start, steps };
}

const fixtures = POLICIES.map(play_);

mkdirSync(path.join(ROOT, 'godot/modes/expedition/data'), { recursive: true });
mkdirSync(path.join(ROOT, 'godot/tests/fixtures'), { recursive: true });
writeFileSync(path.join(ROOT, 'godot/modes/expedition/data/kilimanjaro.json'), JSON.stringify(content, null, 1));
writeFileSync(path.join(ROOT, 'godot/tests/fixtures/expeditions.json'), JSON.stringify(fixtures));
console.log(`cards ${content.events.length}, stat conditions ${JSON.stringify(STAT_CONDITIONS)}`);
for (const f of fixtures) {
  const last = f.steps[f.steps.length - 1].after.state;
  console.log(`${f.name}: ${f.steps.length} steps, ${last.status}, summit ${last.summitReached}, home ${last.returnedSafely}, day ${Math.floor(last.elapsedHours / 24)}`);
}
