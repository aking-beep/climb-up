import { Canvas, Group, Image, LinearGradient, Rect, useImage, vec } from '@shopify/react-native-skia';

import { presentPose } from '@/features/climbing/animation/poses';
import {
  PLATFORMS,
  PLAYER_H,
  PLAYER_W,
  groundTop,
} from '@/features/climbing/simulation/barranco';
import type { ClimbWorld } from '@/features/climbing/simulation/types';

import { backdrop, cameraFor, cloudBands, rockCrop } from './camera';

const FAR = require('../../../../assets/world/far-mountains.png');
const VALLEY = require('../../../../assets/world/diorama-desert.jpg');
const ROCK = require('../../../../assets/world/ground-rock.png');
const CLOUDS = require('../../../../assets/world/clouds.png');
const YOU = require('../../../../assets/world/pixel-you.png');
const LENA = require('../../../../assets/world/pixel-lena.png');
const MARCO = require('../../../../assets/world/pixel-marco.png');
const TENT = require('../../../../assets/world/pixel-tent.png');

/**
 * Native layered drawing. The pictures are the same single images the web view uses.
 * Offsets come from presentPose, which is not a sprite sheet.
 */
export function SkiaScene({
  world,
  width,
  height,
  reduced = false,
}: {
  world: ClimbWorld;
  width: number;
  height: number;
  reduced?: boolean;
}) {
  const far = useImage(FAR);
  const valley = useImage(VALLEY);
  const rock = useImage(ROCK);
  const clouds = useImage(CLOUDS);
  const you = useImage(YOU);
  const lena = useImage(LENA);
  const marco = useImage(MARCO);
  const tent = useImage(TENT);
  const { scale, cam, sx } = cameraFor(world.x, width, height);
  const pose = presentPose(world);
  const bob = reduced ? 0 : pose.dy;
  const marcoGone = world.hazards.some((hazard) => hazard.endsWith('marco'));
  const bands = cloudBands(world.seconds, cam, width, reduced);
  const layers = backdrop(width, height, cam, scale);

  return (
    <Canvas style={{ width, height }}>
      <Rect x={0} y={0} width={width} height={height}>
        <LinearGradient
          start={vec(0, 0)}
          end={vec(0, height)}
          colors={['#f0ddc0', '#d7c4a2', '#8ea8ab', '#314047']}
        />
      </Rect>
      {far ? (
        <Image
          image={far}
          x={layers.range.left}
          y={layers.range.top}
          width={layers.range.width}
          height={layers.range.height}
          fit="fill"
        />
      ) : null}
      {clouds
        ? bands.map((band, index) => (
            <Image
              key={index}
              image={clouds}
              x={band.left}
              y={band.top}
              width={band.width}
              height={band.width * 0.28}
              fit="contain"
              opacity={band.opacity}
            />
          ))
        : null}
      {valley ? (
        <Image
          image={valley}
          x={layers.valley.left}
          y={layers.valley.top}
          width={layers.valley.width}
          height={layers.valley.height}
          fit="cover"
          opacity={0.94}
        />
      ) : null}
      <Rect x={0} y={height * 0.34} width={width} height={height * 0.22}>
        <LinearGradient
          start={vec(0, height * 0.34)}
          end={vec(0, height * 0.56)}
          colors={['rgba(240,221,192,0)', 'rgba(49,64,71,0.25)']}
        />
      </Rect>
      {PLATFORMS.map((platform) => {
        const faceH = Math.min(platform.h * scale, height * 0.62);
        const crop = rockCrop(faceH);
        const left = sx(platform.x);
        const top = platform.y * scale;
        const faceW = platform.w * scale;
        return (
          <Group key={`${platform.x}-${platform.y}`} clip={{ x: left, y: top, width: faceW, height: faceH }}>
            <Rect x={left} y={top} width={faceW} height={faceH} color="#6d6458" />
            {rock ? (
              <Image
                image={rock}
                x={left - ((platform.x * 0.2) % 120)}
                y={top + crop.top}
                width={faceW * 1.6}
                height={crop.imageH}
                fit="fill"
              />
            ) : null}
            <Rect x={left} y={top} width={faceW} height={faceH}>
              <LinearGradient
                start={vec(left, top)}
                end={vec(left, top + faceH)}
                colors={['rgba(28,22,16,0)', 'rgba(28,22,16,0.4)']}
              />
            </Rect>
            <Rect x={left} y={top} width={faceW} height={Math.max(5, 7 * scale)} color="#d9c4a4" />
          </Group>
        );
      })}
      {tent ? (
        <Image image={tent} x={sx(78)} y={(groundTop(80) - 34) * scale} width={54} height={34} fit="contain" />
      ) : null}
      {tent ? (
        <Image
          image={tent}
          x={sx(126)}
          y={(groundTop(130) - 30) * scale}
          width={54}
          height={34}
          fit="contain"
          opacity={0.92}
        />
      ) : null}
      {!marcoGone && marco ? (
        <Image
          image={marco}
          x={sx(636)}
          y={(160 - PLAYER_H) * scale}
          width={PLAYER_W * scale}
          height={PLAYER_H * scale}
          fit="fill"
        />
      ) : null}
      {lena ? (
        <Image
          image={lena}
          x={sx(world.x - 34)}
          y={(world.y + 8 + bob) * scale}
          width={PLAYER_W * scale * 0.86}
          height={PLAYER_H * scale * 0.86 * pose.squash}
          fit="fill"
        />
      ) : null}
      {you ? (
        <Image
          image={you}
          x={sx(world.x)}
          y={(world.y + bob) * scale}
          width={PLAYER_W * scale}
          height={PLAYER_H * scale * pose.squash}
          fit="fill"
        />
      ) : null}
      {!reduced && world.hazards.includes('wind') && world.y < 180
        ? [0, 1, 2, 3].map((index) => (
            <Rect
              key={index}
              x={((world.seconds * 80 + index * 70) % width) - 20}
              y={height * (0.28 + index * 0.08)}
              width={46}
              height={2}
              color="rgba(255,255,255,0.35)"
            />
          ))
        : null}
      {!reduced && rock ? (
        <Group clip={{ x: 0, y: height * 0.86, width, height: height * 0.14 }}>
          <Image
            image={rock}
            x={-cam * scale * 1.15}
            y={height * 0.86 + rockCrop(height * 0.14).top}
            width={width * 1.8}
            height={rockCrop(height * 0.14).imageH}
            fit="fill"
          />
        </Group>
      ) : null}
    </Canvas>
  );
}
