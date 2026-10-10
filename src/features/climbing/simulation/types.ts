export type ClimbInput = {
  left: boolean;
  right: boolean;
  scramble: boolean;
  rest: boolean;
  help: boolean;
  continue: boolean;
  retreat: boolean;
};

export type ClimbAction =
  | 'idle'
  | 'walk'
  | 'approach'
  | 'grip'
  | 'climb'
  | 'mantle'
  | 'recover'
  | 'rest'
  | 'slip'
  | 'air'
  | 'help';

export type ScrambleStage = 'approach' | 'grip' | 'climb' | 'mantle' | 'recover';

export type ClimbPhase =
  | { kind: 'free' }
  | { kind: 'slip'; elapsed: number }
  | { kind: 'beat'; elapsed: number; action: 'help' | 'rest' | 'walk' }
  | {
      kind: 'scramble';
      zoneId: string;
      stage: ScrambleStage;
      elapsed: number;
      fromX: number;
      fromY: number;
      toX: number;
      toY: number;
      spent: boolean;
    };

export type ClimbWorld = {
  x: number;
  y: number;
  vx: number;
  vy: number;
  onGround: boolean;
  facing: 1 | -1;
  action: ClimbAction;
  phase: ClimbPhase;
  stamina: number;
  staminaStart: number;
  seconds: number;
  falls: number;
  hazards: string[];
  checkpoint: number;
  prompt: boolean;
  finished: boolean;
  failed: boolean;
  retreated: boolean;
};

export const EMPTY_INPUT: ClimbInput = {
  left: false,
  right: false,
  scramble: false,
  rest: false,
  help: false,
  continue: false,
  retreat: false,
};
