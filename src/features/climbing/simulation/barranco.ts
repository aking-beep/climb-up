import type { ClimbInput, ClimbWorld } from './types';

/** A short fictional scramble. It is not the real Barranco Wall and not instruction. */
export const WORLD_W = 1120;
export const WORLD_H = 320;
export const PLAYER_W = 28;
export const PLAYER_H = 52;

export const PLATFORMS = [
  { x: 0, y: 220, w: 440, h: 100 },
  { x: 460, y: 160, w: 290, h: 160 },
  { x: 770, y: 96, w: 350, h: 224 },
] as const;

export const SCRAMBLES = [
  { id: 'lower-ledge', x: 360, y: 120, w: 110, h: 140, destX: 490, destY: 160 - PLAYER_H },
  { id: 'upper-ledge', x: 680, y: 70, w: 110, h: 140, destX: 800, destY: 96 - PLAYER_H },
] as const;

export const CHECKPOINTS = [40, 500, 820] as const;
const WIND = { x: 520, w: 150 };
const LOOSE = { x: 860, w: 70 };
const MARCO_X = 610;
const GOAL_X = 1000;
const FALL_Y = 340;

type Rect = { x: number; y: number; w: number; h: number };

function body(x: number, y: number): Rect {
  return { x, y, w: PLAYER_W, h: PLAYER_H };
}

function overlaps(a: Rect, b: Rect): boolean {
  return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;
}

export function groundTop(x: number): number {
  const under = PLATFORMS.filter((platform) => x >= platform.x && x <= platform.x + platform.w);
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
  const here = body(world.x, world.y);
  return SCRAMBLES.find((zone) => overlaps(here, zone)) ?? null;
}

function remember(hazards: string[], id: string): string[] {
  return hazards.includes(id) ? hazards : [...hazards, id];
}

export function stepClimb(world: ClimbWorld, input: ClimbInput, dt: number): ClimbWorld {
  if (world.finished || world.failed || world.retreated) return world;
  const step = Math.max(0, Math.min(dt, 1 / 30));
  if (step === 0) return world;

  if (input.retreat) {
    return { ...world, retreated: true, seconds: world.seconds + step, vx: 0, vy: 0 };
  }

  if (world.prompt) {
    if (!input.help && !input.continue && !input.rest) {
      return { ...world, seconds: world.seconds + step, vx: 0, action: 'help' };
    }
    const helped = input.help;
    const left = input.continue && !helped;
    return {
      ...world,
      seconds: world.seconds + step + (input.rest && !helped && !left ? 4 : 0),
      stamina: Math.max(0, Math.min(100, world.stamina + (helped ? -12 : input.rest ? 14 : 0))),
      hazards: remember(world.hazards, helped ? 'helped-marco' : left ? 'left-marco' : 'rested-with-marco'),
      prompt: false,
      vx: 0,
      action: helped ? 'help' : input.rest ? 'rest' : 'walk',
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
    stamina = Math.min(100, stamina + 12 * step);
    vx = 0;
  } else {
    if (input.left) {
      vx -= 900 * step;
      facing = -1;
    } else if (input.right) {
      vx += 900 * step;
      facing = 1;
    } else {
      vx *= Math.max(0, 1 - 10 * step);
    }
    const max = stamina <= 0 ? 36 : 150;
    vx = Math.max(-max, Math.min(max, vx));
  }

  const onHighLedge = y < 180;
  if (x > WIND.x && x < WIND.x + WIND.w && onHighLedge) vx -= 80 * step;

  x += vx * step;
  const midY = y + PLAYER_H * 0.5;
  for (const platform of PLATFORMS) {
    if (midY < platform.y) continue;
    const here = body(x, y);
    if (!overlaps(here, platform)) continue;
    x = vx > 0 || world.x <= platform.x ? platform.x - PLAYER_W : platform.x + platform.w;
    vx = 0;
  }

  const zone = SCRAMBLES.find((item) => overlaps(body(x, y), item));
  let scrambled = false;
  if (input.scramble && world.onGround && zone && stamina >= 8) {
    scrambled = true;
    x = zone.destX;
    y = zone.destY;
    vx = 0;
    vy = 0;
    stamina = Math.max(0, stamina - 8);
    onGround = true;
  } else {
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

  if (Math.abs(vx) > 12) stamina = Math.max(0, stamina - 7 * step);

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
  const action = prompt
    ? 'help'
    : input.rest && onGround
      ? 'rest'
      : scrambled
        ? 'scramble'
        : !onGround
          ? 'air'
          : Math.abs(vx) > 12
            ? 'walk'
            : 'idle';

  return {
    ...world,
    x,
    y,
    vx,
    vy,
    onGround,
    facing,
    action,
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
