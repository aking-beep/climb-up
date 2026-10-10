import { parseLevel } from '../level';

/**
 * The Lava Tower, as a game level. Fictional: a volcanic plug on the
 * plateau, scrambled to its top and left again. Read it bottom to top.
 *
 * 1. Shira 2, bottom left. Two scree benches.
 * 2. A long loose gully up the tower's flank (heavy on the arms).
 * 3. A windy ledge under the overhang, right to left. Stand still in gusts.
 * 4. A rock face up the left side to the rest ledge.
 * 5. The chimney on the right, to the top block. Touch the top.
 */
export const LAVA_TOWER_ROWS = [
  '....................',
  '.........EE...S.....',
  '.........EE...S.....',
  '........######S.....',
  '..............S.....',
  '..............S.....',
  '..............S.....',
  '..............S.....',
  'SS.R..C.......S.....',
  'SS.R..C.......S.....',
  'SS##############....',
  'SS##############....',
  'SS..................',
  'SS..................',
  'SS..................',
  'SS..................',
  'SS.............ll...',
  'SS.##########..ll...',
  'SS.NNNNNNNNNNCCll...',
  'SS.NNNNNNNNNNCCll...',
  '###############ll...',
  '...............ll...',
  '...............ll...',
  '...............ll...',
  '...............ll...',
  '........l......ll...',
  '....l...l......ll...',
  '....l...l##.C..ll...',
  '.P..l#..l##.C..ll...',
  '####################',
] as const;

/** The tower's mass behind the play space; open plateau at the bottom left. */
const BACKDROP = [
  { x: 5.5, y: 3.2 },
  { x: 8, y: 0.4 },
  { x: 14, y: -0.4 },
  { x: 17.5, y: 2 },
  { x: 24, y: 6 },
  { x: 24, y: 36 },
  { x: 17.5, y: 36 },
  { x: 17.5, y: 24 },
  { x: 13.5, y: 21.5 },
  { x: 3, y: 21 },
  { x: -4, y: 21.4 },
  { x: -4, y: 8 },
  { x: 1.5, y: 6.5 },
];

export const LAVA_TOWER_LEVEL = parseLevel('lava-tower', 'The Lava Tower', LAVA_TOWER_ROWS, BACKDROP);
