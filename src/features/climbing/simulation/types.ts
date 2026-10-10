export type ClimbInput = {
  left: boolean;
  right: boolean;
  scramble: boolean;
  rest: boolean;
  help: boolean;
  continue: boolean;
  retreat: boolean;
};

export type ClimbWorld = {
  x: number;
  y: number;
  vx: number;
  vy: number;
  onGround: boolean;
  facing: 1 | -1;
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
