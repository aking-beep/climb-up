import type { ClimbAction, ClimbWorld } from '@/features/climbing/simulation/types';

export type PoseId = ClimbAction | 'fatigue';

/**
 * How a climber is drawn this frame.
 * `frameCount: 1` means the source picture does not change.
 * Offsets are not a sprite sheet.
 */
export type PresentedPose = {
  id: PoseId;
  dy: number;
  squash: number;
  lean: number;
  frameCount: 1;
  frame: 0;
  fallback: 'single-image';
};

export function presentPose(world: Pick<ClimbWorld, 'action' | 'stamina' | 'seconds'>): PresentedPose {
  const tired = world.stamina < 22 && world.action === 'walk';
  const id: PoseId = tired ? 'fatigue' : world.action;
  const bob =
    id === 'walk' || id === 'fatigue' ? Math.sin(world.seconds * (tired ? 7 : 12)) * (tired ? 1.5 : 3) : 0;
  return {
    id,
    dy: id === 'scramble' ? 6 : id === 'rest' ? 3 : id === 'air' ? -3 : bob,
    squash: id === 'scramble' ? 0.88 : id === 'fatigue' ? 0.94 : 1,
    lean: id === 'air' ? 10 : id === 'scramble' ? -6 : 0,
    frameCount: 1,
    frame: 0,
    fallback: 'single-image',
  };
}
