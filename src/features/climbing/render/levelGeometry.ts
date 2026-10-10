import { Skia, type SkPath } from '@shopify/react-native-skia';

import type { Level } from '../level';

/** The authored outline of the cliff behind the play space, in points. */
export function buildBackdrop(level: Level, tile: number): SkPath {
  const path = Skia.PathBuilder.Make();
  level.backdrop.forEach((point, index) => {
    if (index === 0) path.moveTo(point.x * tile, point.y * tile);
    else path.lineTo(point.x * tile, point.y * tile);
  });
  if (level.backdrop.length > 0) path.close();
  return path.build();
}
