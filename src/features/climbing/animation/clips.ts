import type { ClimbAction } from '@/features/climbing/simulation/types';

export type ClipId = ClimbAction | 'fatigue' | 'fall';

/**
 * Animation backlog. Every clip is one picture until a sheet is drawn.
 * `art: 'missing'` means the game must not describe this as a finished sprite sheet.
 */
export type Clip = {
  id: ClipId;
  frames: 1;
  frameMs: number;
  loop: boolean;
  art: 'missing';
};

export const CLIMB_CLIPS: Record<ClipId, Clip> = {
  idle: { id: 'idle', frames: 1, frameMs: 180, loop: true, art: 'missing' },
  walk: { id: 'walk', frames: 1, frameMs: 120, loop: true, art: 'missing' },
  approach: { id: 'approach', frames: 1, frameMs: 120, loop: false, art: 'missing' },
  grip: { id: 'grip', frames: 1, frameMs: 90, loop: false, art: 'missing' },
  climb: { id: 'climb', frames: 1, frameMs: 110, loop: true, art: 'missing' },
  mantle: { id: 'mantle', frames: 1, frameMs: 110, loop: false, art: 'missing' },
  recover: { id: 'recover', frames: 1, frameMs: 140, loop: false, art: 'missing' },
  rest: { id: 'rest', frames: 1, frameMs: 200, loop: true, art: 'missing' },
  fatigue: { id: 'fatigue', frames: 1, frameMs: 160, loop: true, art: 'missing' },
  slip: { id: 'slip', frames: 1, frameMs: 80, loop: false, art: 'missing' },
  fall: { id: 'fall', frames: 1, frameMs: 80, loop: false, art: 'missing' },
  air: { id: 'air', frames: 1, frameMs: 80, loop: true, art: 'missing' },
  help: { id: 'help', frames: 1, frameMs: 160, loop: false, art: 'missing' },
};
