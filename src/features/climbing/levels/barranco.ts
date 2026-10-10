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

export const BARRANCO_LEVEL = parseLevel('barranco-wall', 'The Barranco Wall', BARRANCO_ROWS);
