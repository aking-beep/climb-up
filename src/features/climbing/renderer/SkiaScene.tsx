import { Canvas, Group, Image, Rect, useImage } from '@shopify/react-native-skia';

import {
  PLATFORMS,
  PLAYER_H,
  PLAYER_W,
  WORLD_H,
  WORLD_W,
} from '@/features/climbing/simulation/barranco';
import type { ClimbWorld } from '@/features/climbing/simulation/types';

const YOU = require('../../../../assets/world/pixel-you.png');
const LENA = require('../../../../assets/world/pixel-lena.png');

/** Native drawing path. Web keeps the layered view scene, which Expo Go can also show. */
export function SkiaScene({ world, width, height }: { world: ClimbWorld; width: number; height: number }) {
  const you = useImage(YOU);
  const lena = useImage(LENA);
  const scale = height / WORLD_H;
  const viewWorld = width / scale;
  const cam = Math.max(0, Math.min(Math.max(0, WORLD_W - viewWorld), world.x - viewWorld * 0.36));
  const sx = (x: number) => (x - cam) * scale;

  return (
    <Canvas style={{ width, height }}>
      <Rect x={0} y={0} width={width} height={height} color="#9eb0ac" />
      <Group>
        {PLATFORMS.map((platform) => (
          <Rect
            key={`${platform.x}-${platform.y}`}
            x={sx(platform.x)}
            y={platform.y * scale}
            width={platform.w * scale}
            height={platform.h * scale}
            color="#3c332c"
          />
        ))}
        {lena ? (
          <Image
            image={lena}
            x={sx(world.x - 34)}
            y={world.y * scale}
            width={PLAYER_W * scale * 0.86}
            height={PLAYER_H * scale * 0.86}
            fit="fill"
          />
        ) : null}
        {you ? (
          <Image
            image={you}
            x={sx(world.x)}
            y={world.y * scale}
            width={PLAYER_W * scale}
            height={PLAYER_H * scale}
            fit="fill"
          />
        ) : null}
      </Group>
    </Canvas>
  );
}
