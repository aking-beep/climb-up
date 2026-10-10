import { parseLevel } from '../level';

/**
 * Summit night, as a game level. Fictional: frozen switchbacks from Barafu
 * to the crater rim, climbed by headlamp. Read it bottom to top.
 *
 * 1. Barafu, bottom left. Walk right to the first scree gully.
 * 2. Five switchbacks, alternating loose scree and short rock steps, each
 *    with a cairn. The cold slows how fast your arms come back.
 * 3. On the fourth, a rest stone and Jun, whose hands have gone numb.
 * 4. The crater rim: open to the wind. Stand still in gusts.
 * 5. A last rock step to Stella Point.
 */
export const SUMMIT_NIGHT_ROWS = [
  '......................',
  'SS...EE...............',
  'SS...EE...............',
  'SS###########.........',
  'SS....................',
  'SS....................',
  'SS....................',
  'SS..NNNNNNNNNNNNNN..ll',
  'SS..NNNNNNNNNNNNNN..ll',
  '####################ll',
  '....................ll',
  '....................ll',
  '....................ll',
  'SS....R...M......CC.ll',
  'SS....R...M......CC.ll',
  'SS####################',
  'SS....................',
  'SS....................',
  'SS....................',
  'SS.CC...............SS',
  'SS.CC...............SS',
  '####################SS',
  '....................SS',
  '....................SS',
  '....................SS',
  'll................CCSS',
  'll................CCSS',
  'll####################',
  'll....................',
  'll....................',
  'll....................',
  'll.CC...............ll',
  'll.CC...............ll',
  '####################ll',
  '....................ll',
  '....................ll',
  '....................ll',
  '..P.................ll',
  '..P.................ll',
  '######################',
] as const;

/** The mountain's flank behind the switchbacks; open sky above the rim. */
const BACKDROP = [
  { x: -4, y: 8.6 },
  { x: 0, y: 6.8 },
  { x: 2, y: 3.6 },
  { x: 13, y: 3.4 },
  { x: 16, y: 6.6 },
  { x: 26, y: 6.2 },
  { x: 26, y: 46 },
  { x: -4, y: 46 },
];

export const SUMMIT_NIGHT_LEVEL = parseLevel('summit-night', 'Summit night', SUMMIT_NIGHT_ROWS, BACKDROP);
