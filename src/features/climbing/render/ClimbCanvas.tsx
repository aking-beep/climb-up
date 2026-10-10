import {
  Atlas,
  Blur,
  Canvas,
  Circle,
  FilterMode,
  Group,
  Image,
  ImageShader,
  Line,
  LinearGradient,
  MipmapMode,
  Oval,
  Path,
  RadialGradient,
  Rect,
  rect,
  useImage,
  vec,
  type SkImage,
} from '@shopify/react-native-skia';
import { useMemo } from 'react';

import { skyColors, type DayPhase } from '@/components/world/scene';
import { hash } from '@/utils/number';

import type { Camera } from '../camera';
import type { ClimbSim, Pose } from '../sim';
import { SHEETS, frameAt, frameRect, type SpriteSheet } from '../sprites';
import { buildBackdrop } from './levelGeometry';
import { TILE_PX, buildTileBatch } from './tileset';

const PIXEL = { filter: FilterMode.Nearest, mipmap: MipmapMode.None } as const;

const KIBO = require('../../../../assets/hd2d/scenery/barranco-kibo.png');
const VALLEY = require('../../../../assets/hd2d/scenery/barranco-valley.png');
const CLIFF = require('../../../../assets/hd2d/scenery/barranco-cliff.png');
const FOREGROUND = require('../../../../assets/hd2d/scenery/barranco-foreground.png');
const CLOUDS = require('../../../../assets/world/clouds.png');
const TILES = require('../../../../assets/hd2d/terrain/barranco-tiles.png');
const TENT = require('../../../../assets/world/pixel-tent.png');

type Props = {
  sim: ClimbSim;
  camera: Camera;
  width: number;
  height: number;
  /** Height of the playfield above the touch controls. The camera centres here. */
  playHeight: number;
  /** Points per tile. A multiple of 16 keeps the pixel art on whole points. */
  tile: number;
  timeMs: number;
  phase: DayPhase;
  weatherRisk: number;
  reducedMotion: boolean;
  lowPower: boolean;
};

/** Barranco Camp: the rest of the party waits by the tents. World tiles. */
const CAMP = {
  tent: { x: 0.1, y: 33, width: 3 },
  jun: { x: 3.3, y: 33, pose: 'rest' as Pose, facing: 1 },
  lena: { x: 4.3, y: 33, pose: 'idle' as Pose, facing: 1 },
};

function Sprite({
  image,
  sheet,
  frame,
  feetX,
  feetY,
  scale,
  facing,
}: {
  image: SkImage | null;
  sheet: SpriteSheet;
  frame: number;
  feetX: number;
  feetY: number;
  scale: number;
  facing: number;
}) {
  if (!image) return null;
  const src = frameRect(sheet, frame);
  const left = Math.round(feetX - sheet.anchor.x * scale);
  const top = Math.round(feetY - sheet.anchor.y * scale);
  const w = sheet.frameWidth * scale;
  const h = sheet.frameHeight * scale;
  return (
    <Group origin={vec(Math.round(feetX), 0)} transform={facing < 0 ? [{ scaleX: -1 }] : []}>
      <Group clip={rect(left, top, w, h)}>
        <Image
          image={image}
          x={left - src.x * scale}
          y={top - src.y * scale}
          width={image.width() * scale}
          height={image.height() * scale}
          fit="fill"
          sampling={PIXEL}
        />
      </Group>
    </Group>
  );
}

function Shadow({ x, y, tile, strength = 0.35 }: { x: number; y: number; tile: number; strength?: number }) {
  return <Oval x={x * tile - tile * 0.4} y={y * tile - tile * 0.09} width={tile * 0.8} height={tile * 0.18} color={`rgba(12,8,6,${strength})`} />;
}

export function ClimbCanvas({ sim, camera, width, height, playHeight, tile, timeMs, phase, weatherRisk, reducedMotion, lowPower }: Props) {
  const level = sim.level;
  const backdrop = useMemo(() => buildBackdrop(level, tile), [level, tile]);
  const batch = useMemo(() => buildTileBatch(level, tile), [level, tile]);
  const kibo = useImage(KIBO);
  const valley = useImage(VALLEY);
  const cliff = useImage(CLIFF);
  const foreground = useImage(FOREGROUND);
  const clouds = useImage(CLOUDS);
  const tiles = useImage(TILES);
  const tent = useImage(TENT);
  const you = useImage(SHEETS.you.source);
  const marco = useImage(SHEETS.marco.source);
  const lena = useImage(SHEETS.lena.source);
  const jun = useImage(SHEETS.jun.source);

  const sky = skyColors(phase);
  const t = reducedMotion ? 0 : timeMs;
  const depthBlur = !lowPower;
  const shakeX = camera.shake > 0 ? Math.sin(timeMs * 0.09) * camera.shake * 5 : 0;
  const shakeY = camera.shake > 0 ? Math.cos(timeMs * 0.11) * camera.shake * 3 : 0;
  const worldX = Math.round(width / 2 - camera.x * tile + shakeX);
  const worldY = Math.round(playHeight / 2 - camera.y * tile + shakeY);
  // How far up the wall the camera is, 0 at the bottom, 1 at the top.
  const climb = 1 - camera.y / level.height;
  const horizon = height * (0.48 + climb * 0.2);
  const px = tile / TILE_PX; // one art pixel, in points
  const mist = Math.min(0.5, 0.06 + weatherRisk / 240);

  const playerFrame = frameAt(SHEETS.you.clips[sim.pose], (sim.poseTicks * 1000) / 60);
  const marcoPose: Pose =
    sim.mate.state === 'helped' ? (sim.pose === 'climb' || sim.pose === 'hang' ? sim.pose : sim.pose === 'walk' || sim.pose === 'tired' ? 'walk' : 'idle') : sim.mode === 'mate' ? 'help' : 'rest';
  const marcoFrame = frameAt(SHEETS.marco.clips[marcoPose], timeMs);

  // Background layers, sized from the screen and moved by the camera at their own rate.
  const kiboW = width * 2.1;
  const kiboH = (kiboW * 560) / 1400;
  const kiboX = width / 2 - kiboW * 0.55 - camera.x * tile * 0.03;
  const kiboY = horizon - kiboH * 0.92 + (camera.y - level.height) * tile * 0.05;
  const cloudW = width * 1.4;
  const cloudH = (cloudW * 286) / 1139;
  const cloudSpan = cloudW + width;
  const cloudX = (((t * 0.008 - camera.x * tile * 0.1) % cloudSpan) + cloudSpan) % cloudSpan - cloudW;
  const valleyW = width * 1.9;
  const valleyH = (valleyW * 520) / 1400;
  const valleyX = width / 2 - valleyW * 0.5 - camera.x * tile * 0.2;
  const valleyY = horizon - valleyH * 0.42 + (level.height - camera.y) * tile * 0.1;
  const fgW = width * 1.5;
  const fgH = (fgW * 420) / 1400;
  const fgX = width / 2 - fgW * 0.5 - (camera.x - level.width / 2) * tile * 0.35 + shakeX;
  const fgY = height - fgH * 0.62 + (level.height - camera.y - 9) * tile * 0.3;
  const cliffScale = (tile * 8) / 256; // one cliff texture tile covers 8 world tiles

  const particles = reducedMotion ? 0 : lowPower ? 10 : 24;
  const gustAlpha = sim.gust === 'blow' ? 0.75 : sim.gust === 'warn' ? 0.3 : 0;
  // A slow cloud shadow crossing the wall.
  const shadowX = ((t * 0.012) % (level.width * tile * 2)) - level.width * tile * 0.5;

  return (
    <Canvas style={{ width, height }}>
      {/* 1. Sky, sun, and its glow */}
      <Rect x={0} y={0} width={width} height={height}>
        <LinearGradient start={vec(0, 0)} end={vec(0, height)} colors={[sky[0], sky[1], sky[2]]} />
      </Rect>
      <Circle cx={width * 0.82} cy={height * 0.1} r={width * 0.6}>
        <RadialGradient c={vec(width * 0.82, height * 0.1)} r={width * 0.6} colors={['rgba(255,240,205,0.6)', 'rgba(255,240,205,0)']} />
      </Circle>

      {/* 2. Kibo, far above */}
      {kibo ? (
        <Image image={kibo} x={kiboX} y={kiboY} width={kiboW} height={kiboH} fit="fill">
          {depthBlur ? <Blur blur={0.6} /> : null}
        </Image>
      ) : null}

      {/* 3. Clouds and the haze band */}
      {clouds ? <Image image={clouds} x={cloudX} y={height * 0.05 + climb * 40} width={cloudW} height={cloudH} fit="fill" opacity={0.8} /> : null}
      <Rect x={0} y={horizon - height * 0.16} width={width} height={height * 0.32}>
        <LinearGradient
          start={vec(0, horizon - height * 0.16)}
          end={vec(0, horizon + height * 0.16)}
          colors={['rgba(236,232,222,0)', 'rgba(236,232,222,0.5)', 'rgba(236,232,222,0)']}
        />
      </Rect>

      {/* 4. The Barranco valley and its groundsels */}
      {valley ? (
        <Image image={valley} x={valleyX} y={valleyY} width={valleyW} height={valleyH} fit="fill">
          {depthBlur ? <Blur blur={0.7} /> : null}
        </Image>
      ) : null}

      {/* Sun shafts across the far air */}
      {!lowPower
        ? [0, 1, 2].map((i) => (
            <Path
              key={`ray-${i}`}
              path={`M ${width * (0.95 - i * 0.12)} 0 L ${width * (0.99 - i * 0.12)} 0 L ${width * (0.35 - i * 0.2)} ${height} L ${width * (0.18 - i * 0.2)} ${height} Z`}
              opacity={0.07 + (reducedMotion ? 0 : Math.sin(t * 0.0004 + i) * 0.02)}
            >
              <LinearGradient start={vec(width, 0)} end={vec(0, height)} colors={['rgba(255,244,214,0.9)', 'rgba(255,244,214,0)']} />
            </Path>
          ))
        : null}

      {/* 5–7. The wall, its people, and their marks */}
      <Group transform={[{ translateX: worldX }, { translateY: worldY }]}>
        {/* The cliff behind the play space: layered lava, darker at its foot. */}
        {cliff ? (
          <Path path={backdrop}>
            <ImageShader image={cliff} tx="repeat" ty="repeat" fit="none" transform={[{ scale: cliffScale }]} />
          </Path>
        ) : null}
        <Group clip={backdrop}>
          <Rect x={-width} y={-height} width={level.width * tile + width * 2} height={level.height * tile + height * 2}>
            <LinearGradient
              start={vec(0, 0)}
              end={vec(0, level.height * tile)}
              colors={['rgba(255,236,206,0.10)', 'rgba(20,14,10,0.25)', 'rgba(14,10,8,0.55)']}
            />
          </Rect>
          {/* The face falls away into shade on the right. */}
          <Rect x={level.width * tile * 0.55} y={-height} width={level.width * tile} height={level.height * tile + height * 2}>
            <LinearGradient
              start={vec(level.width * tile * 0.55, 0)}
              end={vec(level.width * tile * 1.2, 0)}
              colors={['rgba(14,10,8,0)', 'rgba(14,10,8,0.35)']}
            />
          </Rect>
        </Group>
        <Rect x={-width} y={level.height * tile} width={level.width * tile + width * 2} height={height * 2} color="#1d1714" />

        {/* Barranco Camp */}
        {tent ? (
          <Image
            image={tent}
            x={CAMP.tent.x * tile}
            y={CAMP.tent.y * tile - (CAMP.tent.width * tile * 60) / 96}
            width={CAMP.tent.width * tile}
            height={(CAMP.tent.width * tile * 60) / 96}
            fit="fill"
            sampling={PIXEL}
          />
        ) : null}
        <Shadow x={CAMP.jun.x} y={CAMP.jun.y} tile={tile} strength={0.3} />
        <Sprite image={jun} sheet={SHEETS.jun} frame={frameAt(SHEETS.jun.clips[CAMP.jun.pose], timeMs + 400)} feetX={CAMP.jun.x * tile} feetY={CAMP.jun.y * tile} scale={px} facing={CAMP.jun.facing} />
        <Shadow x={CAMP.lena.x} y={CAMP.lena.y} tile={tile} strength={0.3} />
        <Sprite image={lena} sheet={SHEETS.lena} frame={frameAt(SHEETS.lena.clips[CAMP.lena.pose], timeMs)} feetX={CAMP.lena.x * tile} feetY={CAMP.lena.y * tile} scale={px} facing={CAMP.lena.facing} />

        {/* The tiles: rock, faces, scree, edges, shade, cairns, the marker post. */}
        {tiles ? <Atlas image={tiles} sprites={batch.sprites} transforms={batch.transforms} sampling={PIXEL} /> : null}

        {/* A slow cloud shadow crossing the wall. */}
        {!lowPower ? (
          <Oval x={shadowX} y={level.height * tile * 0.25} width={level.width * tile * 0.9} height={level.height * tile * 0.5} color="rgba(12,10,14,0.10)">
            <Blur blur={tile} />
          </Oval>
        ) : null}

        {gustAlpha > 0
          ? Array.from({ length: 8 }, (_, i) => {
              const y = (15.5 + (i % 3) * 0.6) * tile;
              const span = level.width * tile;
              const x = (((t * 0.45 + i * 97) % span) + span) % span;
              return <Line key={`gust-${i}`} p1={vec(x, y)} p2={vec(x - tile * (1.6 + (i % 2)), y + px)} color={`rgba(245,240,230,${gustAlpha})`} strokeWidth={px} />;
            })
          : null}

        {level.mate ? (
          <>
            <Shadow x={sim.mate.x} y={sim.mate.y} tile={tile} strength={0.3} />
            <Sprite
              image={marco}
              sheet={SHEETS.marco}
              frame={marcoFrame}
              feetX={sim.mate.x * tile}
              feetY={sim.mate.y * tile}
              scale={px}
              facing={sim.mate.state === 'helped' ? sim.facing : -1}
            />
            {sim.mate.state === 'waiting' ? (
              <Group transform={[{ translateY: reducedMotion ? 0 : Math.sin(t * 0.005) * px * 1.5 }]}>
                <Path
                  path={`M ${sim.mate.x * tile} ${(sim.mate.y - 2.55) * tile} l ${-px * 3} ${-px * 4} l ${px * 6} 0 Z`}
                  color="#f2c14e"
                />
              </Group>
            ) : null}
          </>
        ) : null}

        {sim.grounded ? <Shadow x={sim.x} y={sim.y} tile={tile} /> : null}
        <Sprite image={you} sheet={SHEETS.you} frame={playerFrame} feetX={sim.x * tile} feetY={sim.y * tile} scale={px} facing={sim.facing} />
      </Group>

      {/* 8. Foreground plants and rock, out of focus */}
      {foreground ? (
        <Image image={foreground} x={fgX} y={fgY} width={fgW} height={fgH} fit="fill" opacity={0.95}>
          {depthBlur ? <Blur blur={4} /> : null}
        </Image>
      ) : null}

      {/* 9. Weather: mist and drifting dust */}
      {[0, 1, 2].map((band) => {
        const y = ((band * 0.33 + climb * 0.4) % 1) * height;
        const x = ((t * (0.004 + band * 0.002)) % width) - width;
        return (
          <Rect key={`mist-${band}`} x={x} y={y} width={width * 3} height={height * 0.18} opacity={mist}>
            <LinearGradient start={vec(0, y)} end={vec(0, y + height * 0.18)} colors={['rgba(236,231,222,0)', 'rgba(236,231,222,0.9)', 'rgba(236,231,222,0)']} />
          </Rect>
        );
      })}
      {Array.from({ length: particles }, (_, i) => {
        const n = hash(i, 31);
        const speed = 0.015 + (n % 7) * 0.005;
        const x = ((n % 1000) / 1000) * width + Math.sin(t * 0.001 + i) * 10 + (sim.gust === 'blow' ? -t * 0.05 : 0);
        const y = (((n >> 10) % 1000) / 1000) * height + t * speed;
        return (
          <Rect
            key={`p-${i}`}
            x={Math.round(((x % width) + width) % width)}
            y={Math.round(y % height)}
            width={n % 3 === 0 ? 2 : 1.5}
            height={n % 3 === 0 ? 2 : 1.5}
            color="rgba(250,244,230,0.6)"
          />
        );
      })}

      {/* 10. Grade: warm morning light from above, vignette at the edges */}
      <Rect x={0} y={0} width={width} height={height}>
        <LinearGradient start={vec(0, 0)} end={vec(0, height)} colors={['rgba(255,214,160,0.10)', 'rgba(255,214,160,0)', 'rgba(30,20,40,0.12)']} />
      </Rect>
      <Rect x={0} y={0} width={width} height={height}>
        <RadialGradient
          c={vec(width / 2, height * 0.42)}
          r={Math.max(width, height) * 0.72}
          colors={['rgba(0,0,0,0)', phase === 'dusk' ? 'rgba(60,20,10,0.42)' : 'rgba(18,12,8,0.38)']}
        />
      </Rect>
    </Canvas>
  );
}
