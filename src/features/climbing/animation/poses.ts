import type { ClimbAction, ClimbWorld } from '@/features/climbing/simulation/types';

import { CLIMB_CLIPS, type ClipId } from './clips';

export type PoseId = ClimbAction | 'fatigue';

/**
 * How a climber is drawn this frame.
 * Clips report one frame and missing sheet art. Offsets move that single picture.
 */
export type PresentedPose = {
  id: PoseId;
  dy: number;
  squash: number;
  lean: number;
  frameCount: 1;
  frame: 0;
  fallback: 'single-image';
  art: 'missing';
};

export function presentPose(world: Pick<ClimbWorld, 'action' | 'stamina' | 'seconds'>): PresentedPose {
  const tired = world.stamina < 22 && world.action === 'walk';
  const id: PoseId = tired ? 'fatigue' : world.action;
  const clip = CLIMB_CLIPS[id as ClipId];
  const bob = id === 'walk' || id === 'fatigue' ? Math.sin(world.seconds * (tired ? 7 : 12)) * (tired ? 1.5 : 3) : 0;
  const dy =
    id === 'climb' || id === 'grip'
      ? 6
      : id === 'approach' || id === 'mantle'
        ? 3
        : id === 'rest' || id === 'help'
          ? 3
          : id === 'slip'
            ? 5
            : id === 'air'
              ? -3
              : bob;
  return {
    id,
    dy,
    squash: id === 'climb' || id === 'grip' || id === 'slip' ? 0.88 : id === 'fatigue' ? 0.94 : 1,
    lean: id === 'air' ? 10 : id === 'slip' ? 12 : id === 'climb' || id === 'grip' ? -6 : 0,
    frameCount: clip.frames,
    frame: 0,
    fallback: 'single-image',
    art: clip.art,
  };
}
