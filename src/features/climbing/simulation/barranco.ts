import type { ClimbInput, ClimbPhase, ClimbWorld, ScrambleStage } from './types';

/** A fictional scramble. It is not the real Barranco Wall and not instruction. */
export const WORLD_W = 1680;
export const WORLD_H = 320;
export const PLAYER_W = 28;
export const PLAYER_H = 52;

export const PLATFORMS = [
  { x: 0, y: 220, w: 440, h: 100 },
  { x: 460, y: 160, w: 290, h: 160 },
  { x: 770, y: 96, w: 280, h: 224 },
  { x: 1120, y: 64, w: 560, h: 256 },
] as const;

export const SCRAMBLES = [
  { id: 'lower-ledge', x: 360, y: 120, w: 110, h: 140, destX: 490, destY: 160 - PLAYER_H },
  { id: 'upper-ledge', x: 680, y: 70, w: 110, h: 140, destX: 800, destY: 96 - PLAYER_H },
  { id: 'crest', x: 980, y: 20, w: 160, h: 130, destX: 1160, destY: 64 - PLAYER_H },
] as const;

export const CHECKPOINTS = [40, 500, 820, 1200] as const;
const WIND = { x: 520, w: 150 };
const LOOSE = { x: 860, w: 70 };
const MARCO_X = 610;
const GOAL_X = 1500;
const FALL_Y = 340;
const STAGE_SECONDS: Record<ScrambleStage, number> = {
  approach: 0.24,
  grip: 0.18,
  climb: 0.48,
  mantle: 0.22,
  recover: 0.16,
};
const STAGE_ORDER: ScrambleStage[] = ['approach', 'grip', 'climb', 'mantle', 'recover'];

type Rect = { x: number; y: number; w: number; h: number };

function body(x: number, y: number): Rect {
  return { x, y, w: PLAYER_W, h: PLAYER_H };
}

function overlaps(a: Rect, b: Rect): boolean {
  return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
}

export function groundTop(x: number): number {
  const under = PLATFORMS.filter((platform) => x + PLAYER_W * 0.5 >= platform.x && x + PLAYER_W * 0.5 <= platform.x + platform.w);
  if (under.length === 0) return PLATFORMS[0].y;
  return Math.min(...under.map((platform) => platform.y));
}

export function createBarranco(stamina: number): ClimbWorld {
  const start = Math.max(0, Math.min(100, Math.round(stamina)));
  return {
    x: CHECKPOINTS[0],
    y: groundTop(CHECKPOINTS[0]) - PLAYER_H,
    vx: 0,
    vy: 0,
    onGround: true,
    facing: 1,
    action: 'idle',
    phase: { kind: 'free' },
    stamina: start,
    staminaStart: start,
    seconds: 0,
    falls: 0,
    hazards: [],
    checkpoint: 0,
    prompt: false,
    finished: false,
    failed: false,
    retreated: false,
  };
}

export function activeScramble(world: ClimbWorld): (typeof SCRAMBLES)[number] | null {
  if (world.phase.kind !== 'free') return null;
  const here = body(world.x, world.y);
  return SCRAMBLES.find((zone) => overlaps(here, zone)) ?? null;
}

function remember(hazards: string[], id: string): string[] {
  return hazards.includes(id) ? hazards : [...hazards, id];
}

function recover(stamina: number, cap: number, step: number): number {
  const rate = stamina < 45 ? 8 : stamina < 75 ? 3 : 1;
  return Math.min(cap, stamina + rate * step);
}

function scramblePoint(phase: Extract<ClimbPhase, { kind: 'scramble' }>, stage: ScrambleStage, elapsed: number) {
  if (stage === 'approach' || stage === 'grip') return { x: phase.fromX, y: phase.fromY };
  if (stage === 'recover') return { x: phase.toX, y: phase.toY };
  const span = STAGE_SECONDS.climb + STAGE_SECONDS.mantle;
  const into = stage === 'climb' ? elapsed : STAGE_SECONDS.climb + elapsed;
  const t = Math.max(0, Math.min(1, into / span));
  return {
    x: phase.fromX + (phase.toX - phase.fromX) * t,
    y: phase.fromY + (phase.toY - phase.fromY) * t,
  };
}

function advanceScramble(world: ClimbWorld, step: number): ClimbWorld {
  const phase = world.phase;
  if (phase.kind !== 'scramble') return world;
  let stage = phase.stage;
  let elapsed = phase.elapsed + step;
  let spent = phase.spent;
  let stamina = world.stamina;
  while (elapsed >= STAGE_SECONDS[stage]) {
    elapsed -= STAGE_SECONDS[stage];
    const index = STAGE_ORDER.indexOf(stage);
    if (index === STAGE_ORDER.length - 1) {
      return {
        ...world,
        x: phase.toX,
        y: phase.toY,
        vx: 0,
        vy: 0,
        onGround: true,
        action: 'idle',
        phase: { kind: 'free' },
        stamina,
        seconds: world.seconds + step,
        facing: phase.toX >= phase.fromX ? 1 : -1,
      };
    }
    stage = STAGE_ORDER[index + 1];
    if (stage === 'grip' && !spent) {
      stamina = Math.max(0, stamina - 8);
      spent = true;
    }
  }
  const point = scramblePoint(phase, stage, elapsed);
  return {
    ...world,
    x: point.x,
    y: point.y,
    vx: 0,
    vy: 0,
    onGround: stage !== 'climb',
    facing: phase.toX >= phase.fromX ? 1 : -1,
    action: stage,
    phase: { ...phase, stage, elapsed, spent },
    stamina,
    seconds: world.seconds + step,
  };
}

function advanceSlip(world: ClimbWorld, step: number): ClimbWorld {
  const phase = world.phase;
  if (phase.kind !== 'slip') return world;
  const elapsed = phase.elapsed + step;
  if (elapsed >= 0.35) {
    return { ...world, action: 'idle', phase: { kind: 'free' }, seconds: world.seconds + step, vx: 0 };
  }
  return { ...world, action: 'slip', phase: { kind: 'slip', elapsed }, seconds: world.seconds + step, vx: 0, vy: 0 };
}

function advanceBeat(world: ClimbWorld, step: number): ClimbWorld {
  const phase = world.phase;
  if (phase.kind !== 'beat') return world;
  const elapsed = phase.elapsed + step;
  if (elapsed >= 0.4) {
    return { ...world, action: 'idle', phase: { kind: 'free' }, seconds: world.seconds + step, vx: 0 };
  }
  return { ...world, action: phase.action, phase: { kind: 'beat', elapsed, action: phase.action }, seconds: world.seconds + step, vx: 0 };
}

export function stepClimb(world: ClimbWorld, input: ClimbInput, dt: number): ClimbWorld {
  if (world.finished || world.failed || world.retreated) return world;
  const step = Math.max(0, Math.min(dt, 1 / 30));
  if (step === 0) return world;

  if (input.retreat) {
    return { ...world, retreated: true, seconds: world.seconds + step, vx: 0, vy: 0 };
  }

  if (world.phase.kind === 'scramble') return advanceScramble(world, step);
  if (world.phase.kind === 'slip') return advanceSlip(world, step);
  if (world.phase.kind === 'beat') return advanceBeat(world, step);

  if (world.prompt) {
    if (!input.help && !input.continue && !input.rest) {
      return { ...world, seconds: world.seconds + step, vx: 0, action: 'help' };
    }
    const helped = input.help;
    const left = input.continue && !helped;
    return {
      ...world,
      seconds: world.seconds + step + (input.rest && !helped && !left ? 4 : 0),
      stamina: Math.max(0, Math.min(world.staminaStart, world.stamina + (helped ? -12 : input.rest ? 14 : 0))),
      hazards: remember(world.hazards, helped ? 'helped-marco' : left ? 'left-marco' : 'rested-with-marco'),
      prompt: false,
      vx: 0,
      action: helped ? 'help' : input.rest ? 'rest' : 'walk',
      phase: { kind: 'beat', elapsed: 0, action: helped ? 'help' : input.rest ? 'rest' : 'walk' },
    };
  }

  const zone = SCRAMBLES.find((item) => overlaps(body(world.x, world.y), item));
  if (input.scramble && world.onGround && zone) {
    if (world.stamina < 8) {
      return { ...world, vx: 0, vy: 0, action: 'slip', phase: { kind: 'slip', elapsed: 0 }, seconds: world.seconds + step };
    }
    return {
      ...world,
      vx: 0,
      vy: 0,
      action: 'approach',
      facing: zone.destX >= world.x ? 1 : -1,
      phase: {
        kind: 'scramble',
        zoneId: zone.id,
        stage: 'approach',
        elapsed: 0,
        fromX: world.x,
        fromY: world.y,
        toX: zone.destX,
        toY: zone.destY,
        spent: false,
      },
      seconds: world.seconds + step,
    };
  }

  let vx = world.vx;
  let vy = world.vy;
  let x = world.x;
  let y = world.y;
  let facing = world.facing;
  let stamina = world.stamina;
  let onGround = false;

  if (input.rest && world.onGround) {
    stamina = recover(stamina, world.staminaStart, step);
    vx = 0;
  } else {
    if (input.left) {
      vx -= 720 * step;
      facing = -1;
    } else if (input.right) {
      vx += 720 * step;
      facing = 1;
    } else {
      vx *= Math.max(0, 1 - 8 * step);
    }
    const tired = stamina < 22;
    const max = stamina <= 0 ? 28 : tired ? 78 : 112;
    vx = Math.max(-max, Math.min(max, vx));
  }

  const onHighLedge = y < 180;
  if (x > WIND.x && x < WIND.x + WIND.w && onHighLedge) vx -= 70 * step;

  x += vx * step;
  const midY = y + PLAYER_H * 0.5;
  for (const platform of PLATFORMS) {
    if (midY < platform.y) continue;
    const here = body(x, y);
    if (!overlaps(here, platform)) continue;
    x = vx > 0 || world.x <= platform.x ? platform.x - PLAYER_W : platform.x + platform.w;
    vx = 0;
  }

  const prevFeet = y + PLAYER_H;
  vy = Math.min(720, vy + 1600 * step);
  y += vy * step;
  for (const platform of PLATFORMS) {
    const within = x + PLAYER_W > platform.x + 6 && x < platform.x + platform.w - 6;
    if (!within || vy < 0) continue;
    const feet = y + PLAYER_H;
    if (prevFeet <= platform.y + 2 && feet >= platform.y) {
      y = platform.y - PLAYER_H;
      vy = 0;
      onGround = true;
    }
  }

  let hazards = world.hazards;
  if (x > WIND.x && x < WIND.x + WIND.w && y < 180) hazards = remember(hazards, 'wind');
  if (x > LOOSE.x && x < LOOSE.x + LOOSE.w && onGround) {
    if (!hazards.includes('loose-stone')) {
      hazards = remember(hazards, 'loose-stone');
      vx = 0;
      stamina = Math.max(0, stamina - 4);
    }
  }

  if (Math.abs(vx) > 12 && !input.rest) stamina = Math.max(0, stamina - 7 * step);

  let checkpoint = world.checkpoint;
  CHECKPOINTS.forEach((mark, index) => {
    if (x >= mark - 8 && onGround) checkpoint = Math.max(checkpoint, index);
  });

  let prompt = false;
  const marcoSettled = hazards.some((hazard) => hazard.endsWith('marco'));
  if (!marcoSettled && x >= MARCO_X && onGround && y < 170) {
    prompt = true;
    vx = 0;
  }

  let falls = world.falls;
  let failed = false;
  if (y > FALL_Y) {
    falls += 1;
    stamina = Math.max(0, stamina - 8);
    const spot = CHECKPOINTS[checkpoint];
    x = spot;
    y = groundTop(spot + 4) - PLAYER_H;
    vx = 0;
    vy = 0;
    onGround = true;
    failed = falls >= 3;
  }

  x = Math.max(0, Math.min(WORLD_W - PLAYER_W, x));
  const finished = x >= GOAL_X && onGround && !prompt && !failed;
  const action = prompt ? 'help' : input.rest && onGround ? 'rest' : !onGround ? 'air' : Math.abs(vx) > 12 ? 'walk' : 'idle';

  return {
    ...world,
    x,
    y,
    vx,
    vy,
    onGround,
    facing,
    action,
    phase: { kind: 'free' },
    stamina,
    seconds: world.seconds + step,
    falls,
    hazards,
    checkpoint,
    prompt,
    finished,
    failed,
  };
}
