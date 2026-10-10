import { clamp } from '@/utils/number';

/**
 * A camera in tile units. It follows the climber with a little lag, looks
 * ahead up the wall while climbing, and stays inside the level except for a
 * little open sky above its top.
 */
export type Camera = { x: number; y: number; shake: number };

/** Tiles of open sky the camera may show above the top of a level. */
const SKY_ABOVE = 3;

export type View = {
  /** Visible size in tiles. */
  width: number;
  height: number;
};

export function createCamera(target: { x: number; y: number }, view: View, level: View): Camera {
  return { ...bound(target.x, target.y - 1, view, level), shake: 0 };
}

function bound(x: number, y: number, view: View, level: View) {
  const halfW = view.width / 2;
  const halfH = view.height / 2;
  return {
    x: level.width <= view.width ? level.width / 2 : clamp(x, halfW, level.width - halfW),
    // Sky is allowed above the wall, so the top ledge clears the HUD.
    y: level.height <= view.height ? level.height / 2 : clamp(y, halfH - SKY_ABOVE, level.height - halfH),
  };
}

/**
 * Advances the camera by `dt` seconds toward the climber. Pass
 * reducedMotion to snap without shake.
 */
export function followCamera(
  camera: Camera,
  target: { x: number; y: number; climbing: boolean; facing: number },
  view: View,
  level: View,
  dt: number,
  reducedMotion: boolean,
): Camera {
  const lookX = target.x + target.facing * 1.2;
  const lookY = target.y - (target.climbing ? 3 : 1.5);
  const goal = bound(lookX, lookY, view, level);
  const ease = reducedMotion ? 1 : 1 - Math.exp(-dt * 4);
  return {
    x: camera.x + (goal.x - camera.x) * ease,
    y: camera.y + (goal.y - camera.y) * ease,
    shake: reducedMotion ? 0 : Math.max(0, camera.shake - dt * 2.5),
  };
}

export function kick(camera: Camera, amount: number, reducedMotion: boolean): Camera {
  return reducedMotion ? camera : { ...camera, shake: Math.min(1, camera.shake + amount) };
}

/** Parallax offset for a layer: 0 is fixed to the screen, 1 moves with the world. */
export function parallax(camera: Camera, factor: number, tile: number) {
  return { x: -camera.x * tile * factor, y: -camera.y * tile * factor };
}
