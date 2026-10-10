import type { ChallengeId } from '@/game/hybrid/types';

import type { Level } from './level';
import { BARRANCO_LEVEL } from './levels/barranco';
import { LAVA_TOWER_LEVEL } from './levels/lavaTower';
import { SUMMIT_NIGHT_LEVEL } from './levels/summitNight';
import type { Pose } from './sim';

export type PartyMember = 'you' | 'marco' | 'lena' | 'jun';

/** How a climb looks. Images are the painted layers from tools/art/scenery.py. */
export type SceneTheme = {
  /** Night: headlamp light, stars, and a dawn that comes as you climb. */
  night: boolean;
  far: number;
  /** Width-relative scale and vertical anchor for the far layer. */
  farScale: number;
  mid: number;
  cliff: number;
  foreground: number;
  /** Multiplies the rock tiles: red for the tower, cold blue at night. */
  tileTint: string | null;
  snow: boolean;
  particles: 'dust' | 'snow';
  clouds: boolean;
  sunShafts: boolean;
};

export type CampFigure = { who: PartyMember; x: number; y: number; pose: Pose; facing: 1 | -1 };

export type ClimbScene = {
  id: ChallengeId;
  level: Level;
  /** Fraction of normal stamina recovery. */
  recovery: number;
  theme: SceneTheme;
  /** Tents and the rest of the party at the start. World tiles. */
  camp: { tent: { x: number; y: number } | null; figures: CampFigure[] };
  mate: PartyMember | null;
  copy: {
    hud: string;
    kicker: string;
    title: string;
    brief: string;
    backOff: string;
    mateTitle: string;
    mateBody: string;
    decideTitleHelped: string;
    decideTitleLeft: string;
    decideBody: string;
    doneComplete: string;
    doneRetreat: string;
    doneFail: string;
    returnTo: string;
  };
};

const BARRANCO: ClimbScene = {
  id: 'barranco-wall',
  level: BARRANCO_LEVEL,
  recovery: 1,
  theme: {
    night: false,
    far: require('../../../assets/hd2d/scenery/barranco-kibo.png'),
    farScale: 2.1,
    mid: require('../../../assets/hd2d/scenery/barranco-valley.png'),
    cliff: require('../../../assets/hd2d/scenery/barranco-cliff.png'),
    foreground: require('../../../assets/hd2d/scenery/barranco-foreground.png'),
    tileTint: null,
    snow: false,
    particles: 'dust',
    clouds: true,
    sunShafts: true,
  },
  camp: {
    tent: { x: 0.1, y: 33 },
    figures: [
      { who: 'jun', x: 3.3, y: 33, pose: 'rest', facing: 1 },
      { who: 'lena', x: 4.3, y: 33, pose: 'idle', facing: 1 },
    ],
  },
  mate: 'marco',
  copy: {
    hud: 'Barranco Wall',
    kicker: 'Barranco Camp · morning',
    title: 'The Barranco Wall',
    brief:
      'A steep morning scramble, played. Hold up on the rock to climb. Ledges and cairns are where you breathe. On the exposed step, stop when the wind comes. Marco is somewhere above you.',
    backOff: 'Back off and stay at Barranco',
    mateTitle: 'Marco is stuck on the step',
    mateBody: 'He has the pack wedged and no footing.',
    decideTitleHelped: 'Marco is up. Now what?',
    decideTitleLeft: 'Lena has Marco. Now what?',
    decideBody: 'The loose gully above is the last of the wall.',
    doneComplete: 'Karanga is over the rise',
    doneRetreat: 'Back down to Barranco',
    doneFail: 'The wall said no today',
    returnTo: 'Barranco',
  },
};

const LAVA: ClimbScene = {
  id: 'lava-tower',
  level: LAVA_TOWER_LEVEL,
  recovery: 0.9,
  theme: {
    night: false,
    far: require('../../../assets/hd2d/scenery/barranco-kibo.png'),
    farScale: 2.8,
    mid: require('../../../assets/hd2d/scenery/plateau.png'),
    cliff: require('../../../assets/hd2d/scenery/lava-cliff.png'),
    foreground: require('../../../assets/hd2d/scenery/lava-foreground.png'),
    tileTint: '#f0c4ae',
    snow: false,
    particles: 'dust',
    clouds: true,
    sunShafts: true,
  },
  camp: {
    tent: { x: 0.1, y: 29 },
    figures: [{ who: 'marco', x: 3.2, y: 29, pose: 'idle', facing: 1 }],
  },
  mate: null,
  copy: {
    hud: 'Lava Tower',
    kicker: 'Shira 2 · climb high',
    title: 'The Lava Tower',
    brief:
      'Climb high, sleep low. The tower is loose red scree and a chimney of old lava. Scree eats your arms, so breathe on the benches. The plateau wind crosses the ledge under the overhang: stand still when it comes. Touch the top, then the party drops to Barranco.',
    backOff: 'Back off and stay at Shira 2',
    mateTitle: '',
    mateBody: '',
    decideTitleHelped: '',
    decideTitleLeft: '',
    decideBody: '',
    doneComplete: 'You touched the top of the tower',
    doneRetreat: 'Back down to Shira 2',
    doneFail: 'The scree said no today',
    returnTo: 'Shira 2',
  },
};

const SUMMIT: ClimbScene = {
  id: 'summit-night',
  level: SUMMIT_NIGHT_LEVEL,
  recovery: 0.55,
  theme: {
    night: true,
    far: require('../../../assets/hd2d/scenery/summit-sea.png'),
    farScale: 1.9,
    mid: require('../../../assets/hd2d/scenery/summit-sea.png'),
    cliff: require('../../../assets/hd2d/scenery/summit-cliff.png'),
    foreground: require('../../../assets/hd2d/scenery/summit-foreground.png'),
    tileTint: '#b4c0d8',
    snow: true,
    particles: 'snow',
    clouds: false,
    sunShafts: false,
  },
  camp: {
    tent: { x: 6.5, y: 39 },
    figures: [
      { who: 'lena', x: 4.2, y: 39, pose: 'idle', facing: 1 },
      { who: 'marco', x: 5.3, y: 39, pose: 'idle', facing: 1 },
    ],
  },
  mate: 'jun',
  copy: {
    hud: 'Summit night',
    kicker: 'Barafu · midnight',
    title: 'Summit night',
    brief:
      'Headlamps on. Frozen switchbacks of scree and rock to the crater rim, then Stella Point at first light. The cold slows how fast your arms come back, so rest at every cairn. The rim is open to the wind. Jun is somewhere on the zigzags.',
    backOff: 'Turn the headlamps around',
    mateTitle: 'Jun has stopped on the switchback',
    mateBody: 'His hands have gone numb and he has dropped a glove on the scree.',
    decideTitleHelped: 'Jun is moving again. Now what?',
    decideTitleLeft: 'Lena is with Jun. Now what?',
    decideBody: 'The crater rim is above, open to the wind. Stella Point is beyond it.',
    doneComplete: 'Stella Point, as the sky goes pale',
    doneRetreat: 'Back down to Barafu',
    doneFail: 'The mountain kept the summit tonight',
    returnTo: 'Barafu',
  },
};

export const SCENES: Record<ChallengeId, ClimbScene> = {
  'lava-tower': LAVA,
  'barranco-wall': BARRANCO,
  'summit-night': SUMMIT,
};
