/**
 * Levels are authored as text, one character per tile. Rows run top to
 * bottom; y grows downward. Everything the simulation collides with or
 * reacts to is in the map, so a level can be read, diffed, and tested.
 *
 *   #  rock (solid)
 *   .  air
 *   S  scramble face: climbable, the rock behind the climber
 *   l  loose face: climbable, costs more stamina
 *   N  exposed ledge: air above a narrow step; wind gusts matter here
 *   C  checkpoint (air); a connected group is one checkpoint
 *   R  rest spot (air); stamina comes back faster standing here
 *   M  teammate who needs help (air)
 *   P  start (air)
 *   E  exit (air); reaching it completes the level
 */
export const Tile = {
  Air: 0,
  Rock: 1,
  Face: 2,
  Loose: 3,
  Exposed: 4,
  Checkpoint: 5,
  Rest: 6,
  Mate: 7,
  Start: 8,
  Exit: 9,
} as const;

export type TileCode = (typeof Tile)[keyof typeof Tile];

const CODES: Record<string, TileCode> = {
  '.': Tile.Air,
  '#': Tile.Rock,
  S: Tile.Face,
  l: Tile.Loose,
  N: Tile.Exposed,
  C: Tile.Checkpoint,
  R: Tile.Rest,
  M: Tile.Mate,
  P: Tile.Start,
  E: Tile.Exit,
};

export type Point = { x: number; y: number };

export type Level = {
  id: string;
  title: string;
  width: number;
  height: number;
  tiles: TileCode[];
  /** Feet position: centre of the tile column, bottom of the lowest tile. */
  start: Point;
  checkpoints: Point[];
  mate: Point | null;
  /** Outline, in tiles, of the cliff behind the play space. Visual only. */
  backdrop: readonly Point[];
};

export function tileAt(level: Level, x: number, y: number): TileCode {
  const tx = Math.floor(x);
  const ty = Math.floor(y);
  if (tx < 0 || tx >= level.width) return Tile.Rock;
  if (ty >= level.height) return Tile.Rock;
  if (ty < 0) return Tile.Air;
  return level.tiles[ty * level.width + tx];
}

export function isSolid(tile: TileCode): boolean {
  return tile === Tile.Rock;
}

export function isClimbable(tile: TileCode): boolean {
  return tile === Tile.Face || tile === Tile.Loose;
}

/** Feet point of a group of marker tiles: middle column, bottom row. */
function feetOf(cells: Point[]): Point {
  const xs = cells.map((cell) => cell.x);
  const bottom = Math.max(...cells.map((cell) => cell.y));
  return { x: (Math.min(...xs) + Math.max(...xs) + 1) / 2, y: bottom + 1 };
}

function groups(width: number, height: number, tiles: TileCode[], kind: TileCode): Point[][] {
  const seen = new Set<number>();
  const out: Point[][] = [];
  for (let i = 0; i < tiles.length; i += 1) {
    if (tiles[i] !== kind || seen.has(i)) continue;
    const cells: Point[] = [];
    const stack = [i];
    seen.add(i);
    while (stack.length > 0) {
      const at = stack.pop()!;
      const x = at % width;
      const y = Math.floor(at / width);
      cells.push({ x, y });
      for (const [dx, dy] of [
        [1, 0],
        [-1, 0],
        [0, 1],
        [0, -1],
      ]) {
        const nx = x + dx;
        const ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
        const next = ny * width + nx;
        if (tiles[next] === kind && !seen.has(next)) {
          seen.add(next);
          stack.push(next);
        }
      }
    }
    out.push(cells);
  }
  return out;
}

export function parseLevel(
  id: string,
  title: string,
  rows: readonly string[],
  backdrop: readonly Point[] = [],
): Level {
  const width = rows[0]?.length ?? 0;
  if (width === 0) throw new Error(`Level ${id} is empty.`);
  const tiles: TileCode[] = [];
  rows.forEach((row, y) => {
    if (row.length !== width) throw new Error(`Level ${id} row ${y} is ${row.length} wide, expected ${width}.`);
    for (const char of row) {
      const tile = CODES[char];
      if (tile === undefined) throw new Error(`Level ${id} has an unknown tile "${char}" on row ${y}.`);
      tiles.push(tile);
    }
  });
  const height = rows.length;
  const starts = groups(width, height, tiles, Tile.Start);
  if (starts.length !== 1) throw new Error(`Level ${id} needs exactly one start.`);
  if (!tiles.includes(Tile.Exit)) throw new Error(`Level ${id} has no exit.`);
  const mates = groups(width, height, tiles, Tile.Mate);
  const start = feetOf(starts[0]);
  // Checkpoints in climbing order: lowest (largest y) first.
  const checkpoints = groups(width, height, tiles, Tile.Checkpoint)
    .map(feetOf)
    .sort((a, b) => b.y - a.y || a.x - b.x);
  return {
    id,
    title,
    width,
    height,
    tiles,
    start,
    checkpoints: [start, ...checkpoints],
    mate: mates.length > 0 ? feetOf(mates[0]) : null,
    backdrop,
  };
}
