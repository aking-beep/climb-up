// Barranco Wall prototype layout. World px, 915 wide, H tall, y down.
// Prototype values only: in Godot the wall stays barranco.txt and the
// existing ClimbLevel rules; hold-choice faces are a proposed layer on top.

export type RockHold = 'jug' | 'crimp' | 'sloper' | 'pocket' | 'ledge' | 'loose' | 'top'
export interface Hold { x: number; y: number; type: RockHold }

export const WALL_H = 1240

export const HOLDS: Hold[] = [
  { x: 430, y: 1205, type: 'ledge' }, { x: 478, y: 1205, type: 'ledge' },
  { x: 420, y: 1105, type: 'jug' }, { x: 482, y: 1100, type: 'jug' },
  // the boulders
  { x: 455, y: 1048, type: 'jug' }, { x: 392, y: 1040, type: 'crimp' }, { x: 512, y: 1010, type: 'pocket' },
  { x: 440, y: 975, type: 'jug' }, { x: 515, y: 950, type: 'crimp' },
  { x: 475, y: 920, type: 'ledge' }, { x: 425, y: 922, type: 'ledge' },
  // the exposed traverse (gust band)
  { x: 540, y: 862, type: 'jug' }, { x: 482, y: 850, type: 'crimp' }, { x: 592, y: 822, type: 'sloper' },
  { x: 556, y: 790, type: 'jug' }, { x: 618, y: 770, type: 'loose' }, { x: 644, y: 744, type: 'crimp' },
  { x: 596, y: 720, type: 'pocket' }, { x: 664, y: 692, type: 'jug' },
  { x: 622, y: 665, type: 'ledge' }, { x: 672, y: 665, type: 'ledge' },
  // the loose gully (stone column)
  { x: 575, y: 602, type: 'jug' }, { x: 650, y: 590, type: 'crimp' }, { x: 604, y: 560, type: 'loose' },
  { x: 684, y: 540, type: 'jug' }, { x: 628, y: 510, type: 'pocket' }, { x: 702, y: 482, type: 'crimp' },
  { x: 562, y: 470, type: 'jug' }, { x: 652, y: 446, type: 'sloper' },
  { x: 622, y: 410, type: 'ledge' }, { x: 568, y: 412, type: 'ledge' },
  // the last face
  { x: 662, y: 352, type: 'crimp' }, { x: 592, y: 340, type: 'jug' }, { x: 640, y: 302, type: 'loose' },
  { x: 560, y: 290, type: 'pocket' }, { x: 612, y: 255, type: 'crimp' }, { x: 680, y: 250, type: 'jug' },
  { x: 582, y: 212, type: 'sloper' }, { x: 642, y: 180, type: 'jug' }, { x: 592, y: 150, type: 'crimp' },
  { x: 615, y: 95, type: 'top' },
]

export const TOP = HOLDS.length - 1

/** Ledges that act as cairns: rest here, respawn here. [feetL, feetR, handL, handR]. */
export const CHECKPOINTS: { name: string; limbs: [number, number, number, number]; y: number }[] = [
  { name: 'Foot of the wall', limbs: [0, 1, 2, 3], y: 1205 },
  { name: 'First ledge', limbs: [10, 9, 12, 11], y: 921 },
  { name: 'The exposed ledge', limbs: [19, 20, 21, 22], y: 665 },
  { name: 'Gully ledge', limbs: [30, 29, 32, 31], y: 411 },
]

export const COST: Record<RockHold, number> = { jug: 4, ledge: 2, crimp: 8, sloper: 9, pocket: 6, loose: 5, top: 3 }
/** Stamina per second while hanging from a hold (sum of both hands, halved). */
export const DRAIN: Record<RockHold, number> = { jug: 0.5, ledge: 0, crimp: 1.5, sloper: 1.8, pocket: 1.1, loose: 0.8, top: 0 }

export const GUST_BAND: [number, number] = [640, 905]
export const GULLY_BAND: [number, number] = [380, 660]
export const GULLY_X: [number, number] = [528, 594]
export const METERS: [number, number] = [3960, 4200]
