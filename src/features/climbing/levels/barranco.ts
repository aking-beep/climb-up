import { parseLevel } from '../level';

/**
 * The Barranco Wall, as a game level. Fictional: inspired by the place,
 * not a map of the real scramble. Read it bottom to top.
 *
 * 1. Barranco Camp, bottom left. Two boulders to scramble over.
 * 2. The first face on the right, to a small ledge (checkpoint).
 * 3. The second face, to the exposed step.
 * 4. The exposed step, right to left, under an overhang. Gusts cross it:
 *    stand still when the wind comes.
 * 5. The left face up to the high ledge. Rest spot, checkpoint, and Marco.
 * 6. The loose gully on the right to the top. Karanga is beyond the exit.
 */
export const BARRANCO_ROWS = [
  '......................',
  '......EEEE....ll......',
  '......EEEE....ll......',
  '....##########ll......',
  '..............ll......',
  '..............ll......',
  '..............ll......',
  '..............ll......',
  'SS.R.C....M...ll......',
  'SS.R.C....M...ll......',
  'SS##############......',
  'SS##############......',
  'SS....................',
  'SS....................',
  'SS....................',
  'SS..##############..SS',
  'SS..NNNNNNNNNNNNNNCCSS',
  'SS..NNNNNNNNNNNNNNCCSS',
  '####################SS',
  '....................SS',
  '....................SS',
  '....................SS',
  '....................SS',
  '..................CCSS',
  '..................CCSS',
  '.................###SS',
  '....................SS',
  '....................SS',
  '....................SS',
  '.........S..........SS',
  '.....S...S..........SS',
  '.P...S...S##...C....SS',
  '.P...S#..S##...C....SS',
  '######################',
] as const;

/** The cliff face behind the play space: open valley at the camp, sky over the top. */
const BACKDROP = [
  { x: -4, y: 9 },
  { x: 0, y: 7.4 },
  { x: 3.5, y: 4.2 },
  { x: 13.6, y: 3.6 },
  { x: 15.2, y: 0.6 },
  { x: 19, y: 1.4 },
  { x: 26, y: 0 },
  { x: 26, y: 40 },
  { x: 16.6, y: 40 },
  { x: 16.6, y: 27.5 },
  { x: 12, y: 26.4 },
  { x: 5, y: 25.9 },
  { x: -4, y: 26.2 },
];

export const BARRANCO_LEVEL = parseLevel('barranco-wall', 'The Barranco Wall', BARRANCO_ROWS, BACKDROP);
