import type { ChallengeOutcome, ChallengeId, ChallengeResult } from '@/game/hybrid/types';
import { clamp } from '@/utils/number';

import { Tile, isClimbable, isSolid, tileAt, type Level, type Point } from './level';

/**
 * Deterministic climbing simulation. One call to `step` is one 60 Hz tick.
 * Same level, same seed, same inputs: same result, on any device. Units are
 * tiles; y grows downward; (x, y) is the climber's feet.
 */
export const HZ = 60;
export const STEP = 1 / HZ;

export const TUNING = {
  width: 0.6,
  height: 1.4,
  walk: 3,
  tiredWalk: 2,
  exposedWalk: 1.3,
  accel: 22,
  gravity: 34,
  maxFall: 16,
  climbUp: 2,
  climbSide: 1.5,
  /** Stamina per second. */
  drainClimbing: 6,
  drainHanging: 2,
  looseFactor: 1.6,
  regenStill: 10,
  regenWalking: 3,
  regenRest: 26,
  tired: 30,
  /** A fall longer than this, in tiles, is a slip. */
  safeFall: 3.2,
  slipTicks: 54,
  maxSlips: 3,
  helpTicks: 72,
  helpCost: 15,
  gustWarnTicks: 90,
  gustBlowTicks: 66,
} as const;

export type ClimbInput = {
  /** -1 left … 1 right. */
  x: number;
  /** -1 down … 1 up. */
  y: number;
  /** Held context action (help a teammate). */
  act: boolean;
};

export const NO_INPUT: ClimbInput = { x: 0, y: 0, act: false };

export type Pose =
  | 'idle'
  | 'walk'
  | 'tired'
  | 'climb'
  | 'hang'
  | 'fall'
  | 'slip'
  | 'rest'
  | 'brace'
  | 'help'
  | 'celebrate';

/** play: moving. mate: with the teammate. decide: continue, regroup, or retreat. */
export type Mode = 'play' | 'mate' | 'decide' | 'done';
export type MateState = 'waiting' | 'helped' | 'left';
export type Gust = 'calm' | 'warn' | 'blow';
export type SimEvent = 'slip' | 'checkpoint' | 'gust-warn' | 'gust' | 'mate' | 'helped' | 'complete' | 'fail' | 'retreat';

export type Command =
  | { type: 'leave-mate' }
  | { type: 'step-back' }
  | { type: 'continue' }
  | { type: 'regroup' }
  | { type: 'retreat' };

export type ClimbSim = {
  level: Level;
  seed: number;
  maxStamina: number;
  gustPeriod: number;
  tick: number;
  /** Ticks the party spent off the clock (regrouping). */
  extraTicks: number;
  x: number;
  y: number;
  vx: number;
  vy: number;
  facing: 1 | -1;
  grounded: boolean;
  climbing: boolean;
  fallFrom: number | null;
  stamina: number;
  slips: number;
  slipTicks: number;
  checkpoint: number;
  mode: Mode;
  mate: { state: MateState; x: number; y: number; cooldown: boolean };
  helpTicks: number;
  regrouped: boolean;
  result: ChallengeResult | null;
  pose: Pose;
  /** Ticks spent in the current pose, for animation. */
  poseTicks: number;
  gust: Gust;
  events: SimEvent[];
  trail: Point[];
};

export type SimOptions = {
  level: Level;
  seed: number;
  /** Expedition energy, 0–100. Sets the size of the stamina bar. */
  energy: number;
  /** Expedition weather risk, 0–100. More weather, more frequent gusts. */
  weatherRisk: number;
};

const EPS = 1e-3;

export function maxStaminaFor(energy: number): number {
  return Math.round(clamp(55 + energy * 0.45, 55, 100));
}

export function createSim({ level, seed, energy, weatherRisk }: SimOptions): ClimbSim {
  const maxStamina = maxStaminaFor(energy);
  return {
    level,
    seed: seed >>> 0,
    maxStamina,
    gustPeriod: Math.round(clamp(330 - weatherRisk * 1.2, 210, 330)),
    tick: 0,
    extraTicks: 0,
    x: level.start.x,
    y: level.start.y,
    vx: 0,
    vy: 0,
    facing: 1,
    grounded: true,
    climbing: false,
    fallFrom: null,
    stamina: maxStamina,
    slips: 0,
    slipTicks: 0,
    checkpoint: 0,
    mode: 'play',
    mate: level.mate
      ? { state: 'waiting', x: level.mate.x, y: level.mate.y, cooldown: false }
      : { state: 'left', x: 0, y: 0, cooldown: false },
    helpTicks: 0,
    regrouped: false,
    result: null,
    pose: 'idle',
    poseTicks: 0,
    gust: 'calm',
    events: [],
    trail: [],
  };
}

/** Wind on the exposed step: a warning, then a gust, then calm. */
export function gustAt(sim: Pick<ClimbSim, 'seed' | 'gustPeriod'>, tick: number): Gust {
  const phase = (tick + (sim.seed % sim.gustPeriod)) % sim.gustPeriod;
  if (phase < TUNING.gustWarnTicks) return 'warn';
  if (phase < TUNING.gustWarnTicks + TUNING.gustBlowTicks) return 'blow';
  return 'calm';
}

function bodyTiles(sim: ClimbSim, x: number, y: number, visit: (tile: Tile, tx: number, ty: number) => boolean): boolean {
  const left = Math.floor(x - TUNING.width / 2 + EPS);
  const right = Math.floor(x + TUNING.width / 2 - EPS);
  const top = Math.floor(y - TUNING.height + EPS);
  const bottom = Math.floor(y - EPS);
  for (let ty = top; ty <= bottom; ty += 1) {
    for (let tx = left; tx <= right; tx += 1) {
      if (visit(tileAt(sim.level, tx, ty), tx, ty)) return true;
    }
  }
  return false;
}

function touches(sim: ClimbSim, test: (tile: Tile) => boolean): boolean {
  return bodyTiles(sim, sim.x, sim.y, (tile) => test(tile));
}

function onGround(sim: ClimbSim): boolean {
  const left = Math.floor(sim.x - TUNING.width / 2 + EPS);
  const right = Math.floor(sim.x + TUNING.width / 2 - EPS);
  const below = Math.floor(sim.y + 0.01);
  for (let tx = left; tx <= right; tx += 1) {
    if (isSolid(tileAt(sim.level, tx, below))) return true;
  }
  return false;
}

function moveX(sim: ClimbSim, dx: number): boolean {
  if (dx === 0) return false;
  sim.x = clamp(sim.x + dx, TUNING.width / 2, sim.level.width - TUNING.width / 2);
  let hit: number | null = null;
  bodyTiles(sim, sim.x, sim.y, (tile, tx) => {
    if (!isSolid(tile)) return false;
    hit = hit === null ? tx : dx > 0 ? Math.min(hit, tx) : Math.max(hit, tx);
    return false;
  });
  if (hit === null) return false;
  sim.x = dx > 0 ? hit - TUNING.width / 2 : hit + 1 + TUNING.width / 2;
  sim.vx = 0;
  return true;
}

function moveY(sim: ClimbSim, dy: number): boolean {
  if (dy === 0) return false;
  sim.y += dy;
  let hit: number | null = null;
  bodyTiles(sim, sim.x, sim.y, (tile, _tx, ty) => {
    if (!isSolid(tile)) return false;
    hit = hit === null ? ty : dy > 0 ? Math.min(hit, ty) : Math.max(hit, ty);
    return false;
  });
  if (hit === null) return false;
  sim.y = dy > 0 ? hit : hit + 1 + TUNING.height;
  sim.vy = 0;
  return true;
}

function approach(value: number, target: number, amount: number): number {
  if (value < target) return Math.min(target, value + amount);
  return Math.max(target, value - amount);
}

function slip(sim: ClimbSim) {
  if (sim.slipTicks > 0) return;
  sim.slips += 1;
  sim.slipTicks = TUNING.slipTicks;
  sim.climbing = false;
  sim.vx = 0;
  sim.vy = 0;
  sim.events.push('slip');
}

function finish(sim: ClimbSim, result: ChallengeResult) {
  sim.mode = 'done';
  sim.result = result;
  sim.events.push(result === 'complete' ? 'complete' : result === 'fail' ? 'fail' : 'retreat');
}

function settleSlip(sim: ClimbSim) {
  sim.slipTicks -= 1;
  if (sim.slipTicks > 0) return;
  if (sim.slips >= TUNING.maxSlips) {
    finish(sim, 'fail');
    return;
  }
  const spot = sim.level.checkpoints[sim.checkpoint];
  sim.x = spot.x;
  sim.y = spot.y;
  sim.vx = 0;
  sim.vy = 0;
  sim.grounded = true;
  sim.fallFrom = null;
  sim.stamina = Math.max(sim.stamina, sim.maxStamina * 0.5);
}

function stepMate(sim: ClimbSim, input: ClimbInput) {
  const able = sim.stamina >= TUNING.helpCost;
  if (input.act && able) sim.helpTicks += 1;
  else sim.helpTicks = Math.max(0, sim.helpTicks - 2);
  if (sim.helpTicks >= TUNING.helpTicks) {
    sim.stamina -= TUNING.helpCost;
    sim.mate.state = 'helped';
    sim.mode = 'decide';
    sim.helpTicks = 0;
    sim.events.push('helped');
  }
}

/**
 * Corner correction. A climber whose shoulder catches the edge of a lip
 * is nudged sideways along the face instead of hanging stuck under it.
 */
function slideAroundLip(sim: ClimbSim) {
  const reach = TUNING.width;
  for (let nudge = 0.05; nudge <= reach + EPS; nudge += 0.05) {
    for (const side of [1, -1]) {
      const x = sim.x + nudge * side;
      if (x < TUNING.width / 2 || x > sim.level.width - TUNING.width / 2) continue;
      const above = sim.y - 0.05;
      const blocked = bodyTiles(sim, x, above, (tile) => isSolid(tile));
      const holds = bodyTiles(sim, x, sim.y, (tile) => isClimbable(tile));
      const next = sim.x + side * Math.min(nudge, 0.06);
      if (!blocked && holds && !bodyTiles(sim, next, sim.y, (tile) => isSolid(tile))) {
        sim.x = next;
        return;
      }
    }
  }
}

function stepClimbing(sim: ClimbSim, input: ClimbInput) {
  const loose = touches(sim, (tile) => tile === Tile.Loose);
  const moving = Math.abs(input.x) > 0.2 || Math.abs(input.y) > 0.2;
  sim.vx = input.x * TUNING.climbSide;
  sim.vy = -input.y * TUNING.climbUp;
  sim.stamina -= (moving ? TUNING.drainClimbing : TUNING.drainHanging) * (loose ? TUNING.looseFactor : 1) * STEP;

  moveX(sim, sim.vx * STEP);
  if (!touches(sim, isClimbable)) {
    // Stepped off the face sideways. Gravity takes over next tick.
    sim.climbing = false;
    sim.vy = 0;
    sim.fallFrom = sim.y;
    return;
  }
  const before = sim.y;
  const bumped = moveY(sim, sim.vy * STEP);
  if (bumped && input.y > 0.3) slideAroundLip(sim);
  if (!touches(sim, isClimbable)) {
    // The top of the face: hands have nothing above. Stay put.
    sim.y = before;
    sim.vy = 0;
  }
  sim.grounded = onGround(sim);
  if (sim.grounded && input.y < -0.3) sim.climbing = false;
  if (sim.stamina <= 0) {
    sim.stamina = 0;
    slip(sim);
  }
}

function stepWalking(sim: ClimbSim, input: ClimbInput) {
  const exposed = touches(sim, (tile) => tile === Tile.Exposed);
  const limit = exposed ? TUNING.exposedWalk : sim.stamina < TUNING.tired ? TUNING.tiredWalk : TUNING.walk;
  sim.vx = approach(sim.vx, input.x * limit, TUNING.accel * STEP);
  sim.vy = Math.min(sim.vy + TUNING.gravity * STEP, TUNING.maxFall);
  moveX(sim, sim.vx * STEP);
  moveY(sim, sim.vy * STEP);
  sim.grounded = onGround(sim);
  if (sim.grounded) {
    sim.vy = 0;
    if (sim.fallFrom !== null && sim.y - sim.fallFrom > TUNING.safeFall) slip(sim);
    sim.fallFrom = null;
  } else if (sim.fallFrom === null) {
    sim.fallFrom = sim.y;
  }
  if (sim.grounded) {
    const rest = touches(sim, (tile) => tile === Tile.Rest);
    const still = Math.abs(sim.vx) < 0.2;
    sim.stamina += (rest && still ? TUNING.regenRest : still ? TUNING.regenStill : TUNING.regenWalking) * STEP;
  }
  if (exposed && sim.gust === 'blow' && (Math.abs(input.x) > 0.2 || Math.abs(sim.vx) > 0.3)) slip(sim);
}

function poseOf(sim: ClimbSim, input: ClimbInput): Pose {
  if (sim.slipTicks > 0) return 'slip';
  if (sim.result === 'complete') return 'celebrate';
  if (sim.mode === 'mate') return input.act && sim.stamina >= TUNING.helpCost ? 'help' : 'idle';
  if (sim.mode !== 'play') return 'idle';
  if (sim.climbing) return Math.abs(input.x) > 0.2 || Math.abs(input.y) > 0.2 ? 'climb' : 'hang';
  if (!sim.grounded) return 'fall';
  const still = Math.abs(sim.vx) < 0.2;
  if (still && sim.gust !== 'calm' && touches(sim, (tile) => tile === Tile.Exposed)) return 'brace';
  if (!still) return sim.stamina < TUNING.tired ? 'tired' : 'walk';
  if (touches(sim, (tile) => tile === Tile.Rest)) return 'rest';
  return 'idle';
}

function arrive(sim: ClimbSim) {
  const { checkpoints, mate } = sim.level;
  for (let index = sim.checkpoint + 1; index < checkpoints.length; index += 1) {
    const spot = checkpoints[index];
    if (sim.grounded && Math.abs(sim.x - spot.x) < 1.2 && Math.abs(sim.y - spot.y) < 0.6) {
      sim.checkpoint = index;
      sim.events.push('checkpoint');
    }
  }
  if (mate && sim.mate.state === 'waiting') {
    const near = Math.abs(sim.x - mate.x) < 1.4 && Math.abs(sim.y - mate.y) < 0.6;
    if (!near && Math.abs(sim.x - mate.x) > 2.5) sim.mate.cooldown = false;
    if (near && sim.grounded && !sim.mate.cooldown) {
      sim.mode = 'mate';
      sim.vx = 0;
      sim.helpTicks = 0;
      sim.events.push('mate');
    }
  }
  if (touches(sim, (tile) => tile === Tile.Exit)) finish(sim, 'complete');
}

function follow(sim: ClimbSim) {
  sim.trail.push({ x: sim.x, y: sim.y });
  if (sim.trail.length > 40) sim.trail.shift();
  if (sim.mate.state !== 'helped') return;
  const behind = sim.trail[0];
  sim.mate.x = behind.x - sim.facing * 0.4;
  sim.mate.y = behind.y;
}

export function step(sim: ClimbSim, raw: ClimbInput): ClimbSim {
  sim.events = [];
  if (sim.mode === 'done') return sim;
  const input: ClimbInput = { x: clamp(raw.x, -1, 1), y: clamp(raw.y, -1, 1), act: raw.act };
  sim.tick += 1;

  const gust = gustAt(sim, sim.tick);
  if (gust !== sim.gust) {
    if (gust === 'warn') sim.events.push('gust-warn');
    if (gust === 'blow') sim.events.push('gust');
    sim.gust = gust;
  }

  if (sim.slipTicks > 0) {
    settleSlip(sim);
  } else if (sim.mode === 'mate') {
    stepMate(sim, input);
  } else if (sim.mode === 'play') {
    const onFace = touches(sim, isClimbable);
    if (!sim.climbing && onFace && input.y > 0.3) {
      sim.climbing = true;
      sim.fallFrom = null;
    }
    if (sim.climbing) stepClimbing(sim, input);
    else stepWalking(sim, input);
    if (input.x > 0.2) sim.facing = 1;
    if (input.x < -0.2) sim.facing = -1;
    sim.stamina = clamp(sim.stamina, 0, sim.maxStamina);
    if (sim.slipTicks === 0) arrive(sim);
  }
  follow(sim);

  const pose = poseOf(sim, input);
  sim.poseTicks = pose === sim.pose ? sim.poseTicks + 1 : 0;
  sim.pose = pose;
  return sim;
}

export function command(sim: ClimbSim, order: Command): ClimbSim {
  sim.events = [];
  if (sim.mode === 'done') return sim;
  if (order.type === 'retreat') {
    finish(sim, 'retreat');
    return sim;
  }
  if (sim.mode === 'mate') {
    if (order.type === 'leave-mate') {
      sim.mate.state = 'left';
      sim.mode = 'decide';
    }
    if (order.type === 'step-back') {
      sim.mate.cooldown = true;
      sim.mode = 'play';
    }
    return sim;
  }
  if (sim.mode === 'decide') {
    if (order.type === 'continue') sim.mode = 'play';
    if (order.type === 'regroup') {
      // Lena, Jun, and Marco catch up. Arms and lungs come back; daylight goes.
      sim.stamina = sim.maxStamina;
      sim.regrouped = true;
      sim.extraTicks += 30 * 60 * HZ;
      sim.mode = 'play';
    }
  }
  return sim;
}

export function outcomeOf(sim: ClimbSim, attemptId: string, challengeId: ChallengeId): ChallengeOutcome | null {
  if (sim.mode !== 'done' || sim.result === null) return null;
  return {
    attemptId,
    challengeId,
    result: sim.result,
    staminaLeft: Math.round((sim.stamina / sim.maxStamina) * 100),
    slips: sim.slips,
    assisted: sim.mate.state === 'helped' ? true : sim.mate.state === 'left' && sim.level.mate ? false : null,
    regrouped: sim.regrouped,
    seconds: Math.round((sim.tick + sim.extraTicks) / HZ),
  };
}
