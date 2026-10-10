import { Skia, rect, type SkPath, type SkPathBuilder } from '@shopify/react-native-skia';

import { hash } from '@/utils/number';

import { Tile, isSolid, tileAt, type Level } from '../level';

/**
 * The level baked into a handful of paths, once per level and tile size.
 * Drawing a few paths per frame is far cheaper than a node per tile.
 */
export type LevelGeometry = {
  backdrop: SkPath;
  strata: SkPath;
  rock: SkPath;
  rockLight: SkPath;
  rockShade: SkPath;
  rockGrain: SkPath;
  face: SkPath;
  faceHolds: SkPath;
  loose: SkPath;
  looseStones: SkPath;
  lip: SkPath;
  cairns: SkPath;
  rest: SkPath;
  exit: SkPath;
};

const GEOMETRY_KEYS = [
  'backdrop',
  'strata',
  'rock',
  'rockLight',
  'rockShade',
  'rockGrain',
  'face',
  'faceHolds',
  'loose',
  'looseStones',
  'lip',
  'cairns',
  'rest',
  'exit',
] as const satisfies readonly (keyof LevelGeometry)[];

export function buildGeometry(level: Level, tile: number): LevelGeometry {
  const g = {} as Record<keyof LevelGeometry, SkPathBuilder>;
  for (const key of GEOMETRY_KEYS) g[key] = Skia.PathBuilder.Make();
  const px = (n: number) => Math.round(n * tile);
  const seen = new Set<string>();

  level.backdrop.forEach((point, index) => {
    if (index === 0) g.backdrop.moveTo(point.x * tile, point.y * tile);
    else g.backdrop.lineTo(point.x * tile, point.y * tile);
  });
  if (level.backdrop.length > 0) g.backdrop.close();
  // Faint tilted bands in the cliff, like layered lava flows.
  for (let i = 0; i < level.height * 1.4; i += 1) {
    const n = hash(i, 404);
    const y = (i / 1.4) * tile + (n % tile);
    const x = ((n >> 6) % (level.width * tile)) - tile * 4;
    const w = tile * (3 + ((n >> 12) % 6));
    g.strata.addRect(rect(x, y, w, Math.max(1, tile * 0.08)));
    g.strata.addRect(rect(x + w * 0.2, y + tile * 0.08, w * 0.7, Math.max(1, tile * 0.05)));
  }

  for (let y = 0; y < level.height; y += 1) {
    for (let x = 0; x < level.width; x += 1) {
      const kind = tileAt(level, x, y);
      const left = px(x);
      const top = px(y);
      const size = px(x + 1) - left;
      const sizeY = px(y + 1) - top;
      const noise = hash(x, y, 77);
      if (isSolid(kind)) {
        g.rock.addRect(rect(left, top, size, sizeY));
        // Light from the upper left: lit tops, shaded undersides.
        if (!isSolid(tileAt(level, x, y - 1))) g.rockLight.addRect(rect(left, top, size, Math.max(2, tile * 0.16)));
        if (!isSolid(tileAt(level, x, y + 1)) && y + 1 < level.height) {
          g.rockShade.addRect(rect(left, top + sizeY - Math.max(2, tile * 0.22), size, Math.max(2, tile * 0.22)));
        }
        if (!isSolid(tileAt(level, x - 1, y))) g.rockLight.addRect(rect(left, top, Math.max(1, tile * 0.08), sizeY));
        for (let i = 0; i < 3; i += 1) {
          const n = hash(x, y, i, 5);
          g.rockGrain.addRect(rect(left + (n % size), top + ((n >> 8) % sizeY), Math.max(1, tile * 0.1), Math.max(1, tile * 0.06)));
        }
        continue;
      }
      if (kind === Tile.Face || kind === Tile.Loose) {
        const path = kind === Tile.Face ? g.face : g.loose;
        path.addRect(rect(left, top, size, sizeY));
        const dots = kind === Tile.Face ? g.faceHolds : g.looseStones;
        const count = kind === Tile.Face ? 2 : 4;
        for (let i = 0; i < count; i += 1) {
          const n = hash(x, y, i, 11);
          const r = kind === Tile.Face ? tile * 0.09 : tile * (0.05 + ((n >> 16) % 4) * 0.02);
          dots.addCircle(left + tile * 0.2 + (n % Math.max(1, size * 0.6)), top + tile * 0.2 + ((n >> 8) % Math.max(1, sizeY * 0.6)), r);
        }
        continue;
      }
      if (kind === Tile.Exposed && isSolid(tileAt(level, x, y + 1))) {
        g.lip.addRect(rect(left, top + sizeY - Math.max(2, tile * 0.1), size, Math.max(2, tile * 0.1)));
      }
      if (kind === Tile.Rest && isSolid(tileAt(level, x, y + 1))) {
        // A sitting stone.
        g.rest.addRRect(Skia.RRectXY(rect(left + tile * 0.1, top + sizeY - tile * 0.32, tile * 0.8, tile * 0.32), tile * 0.12, tile * 0.12));
      }
      const key = `${kind}`;
      if (kind === Tile.Checkpoint && isSolid(tileAt(level, x, y + 1)) && noise % 2 === 0) {
        // A small cairn: three stacked stones.
        const cx = left + size / 2;
        const base = top + sizeY;
        g.cairns.addOval(rect(cx - tile * 0.32, base - tile * 0.24, tile * 0.64, tile * 0.24));
        g.cairns.addOval(rect(cx - tile * 0.24, base - tile * 0.44, tile * 0.48, tile * 0.22));
        g.cairns.addOval(rect(cx - tile * 0.15, base - tile * 0.6, tile * 0.3, tile * 0.18));
      }
      if (kind === Tile.Exit && !seen.has(key) && isSolid(tileAt(level, x, y + 2))) {
        seen.add(key);
        // A post and a marker board toward Karanga.
        g.exit.addRect(rect(left + tile * 0.45, top - tile * 0.1, tile * 0.1, tile * 2.1));
        g.exit.addRect(rect(left + tile * 0.1, top + tile * 0.05, tile * 0.9, tile * 0.35));
      }
    }
  }
  const built = {} as LevelGeometry;
  for (const key of GEOMETRY_KEYS) built[key] = g[key].build();
  return built;
}
