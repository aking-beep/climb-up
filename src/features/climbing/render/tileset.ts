import { Skia, rect, type SkRSXform, type SkRect } from '@shopify/react-native-skia';

import { hash } from '@/utils/number';

import { Tile, isSolid, tileAt, type Level } from '../level';

/**
 * The Barranco tileset (tools/art/tiles.py). 16 px tiles, 8 columns. These
 * indices must match the order that script writes.
 */
export const TILE_PX = 16;
const COLUMNS = 8;

export const TILE = {
  rock: [0, 1, 2, 3],
  face: [4, 5, 6, 7],
  loose: [8, 9, 10, 11],
  lip: [12, 13],
  shade: 14,
  exposedLip: 15,
  edgeLeft: 16,
  edgeRight: 17,
  cairn: 18,
  rest: 19,
  signTop: 20,
  signBottom: 21,
  underShade: 22,
} as const;

function source(index: number): SkRect {
  return rect((index % COLUMNS) * TILE_PX, Math.floor(index / COLUMNS) * TILE_PX, TILE_PX, TILE_PX);
}

export type AtlasBatch = { sprites: SkRect[]; transforms: SkRSXform[] };

/**
 * Every tile of a level as one Atlas batch: base tiles first, then edge and
 * shade overlays, then props, so a single draw call paints the whole wall.
 * `tile` is the on-screen tile size in points; it should be a multiple of 16
 * so pixels land on whole points.
 */
export function buildTileBatch(level: Level, tile: number): AtlasBatch {
  const scale = tile / TILE_PX;
  const base: AtlasBatch = { sprites: [], transforms: [] };
  const over: AtlasBatch = { sprites: [], transforms: [] };
  const props: AtlasBatch = { sprites: [], transforms: [] };
  const put = (batch: AtlasBatch, index: number, x: number, y: number) => {
    batch.sprites.push(source(index));
    batch.transforms.push(Skia.RSXform(scale, 0, x * tile, y * tile));
  };
  const pick = (list: readonly number[], x: number, y: number) => list[hash(x, y, 17) % list.length];

  for (let y = 0; y < level.height; y += 1) {
    for (let x = 0; x < level.width; x += 1) {
      const kind = tileAt(level, x, y);
      if (isSolid(kind)) {
        put(base, pick(TILE.rock, x, y), x, y);
        if (!isSolid(tileAt(level, x, y - 1))) put(over, pick(TILE.lip, x, y), x, y);
        if (y + 1 < level.height && !isSolid(tileAt(level, x, y + 1))) put(over, TILE.shade, x, y);
        if (x > 0 && !isSolid(tileAt(level, x - 1, y))) put(over, TILE.edgeLeft, x, y);
        if (x + 1 < level.width && !isSolid(tileAt(level, x + 1, y))) put(over, TILE.edgeRight, x, y);
        continue;
      }
      if (kind === Tile.Face) put(base, pick(TILE.face, x, y), x, y);
      if (kind === Tile.Loose) put(base, pick(TILE.loose, x, y), x, y);
      if (y > 0 && isSolid(tileAt(level, x, y - 1))) put(over, TILE.underShade, x, y);
      if (kind === Tile.Rest && isSolid(tileAt(level, x, y + 1))) put(props, TILE.rest, x, y);
    }
  }

  // One cairn per checkpoint (not the start), beside where the climber stands.
  for (const spot of level.checkpoints.slice(1)) put(props, TILE.cairn, Math.floor(spot.x) - 1, spot.y - 1);

  // A marker post at the exit, on the ledge under its left edge.
  const exit = firstExit(level);
  if (exit) {
    put(props, TILE.signTop, exit.x, exit.y - 2);
    put(props, TILE.signBottom, exit.x, exit.y - 1);
  }

  return {
    sprites: [...base.sprites, ...over.sprites, ...props.sprites],
    transforms: [...base.transforms, ...over.transforms, ...props.transforms],
  };
}

function firstExit(level: Level): { x: number; y: number } | null {
  for (let x = 0; x < level.width; x += 1) {
    for (let y = 0; y < level.height; y += 1) {
      if (tileAt(level, x, y) === Tile.Exit) {
        let floor = y;
        while (floor < level.height && tileAt(level, x, floor) === Tile.Exit) floor += 1;
        return { x, y: floor };
      }
    }
  }
  return null;
}
