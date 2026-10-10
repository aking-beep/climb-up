import {
  Blur,
  Canvas,
  Circle,
  FilterMode,
  Group,
  Image,
  Line,
  LinearGradient,
  MipmapMode,
  Oval,
  Path,
  RadialGradient,
  Rect,
  Skia,
  rect,
  useImage,
  vec,
  type SkImage,
} from '@shopify/react-native-skia';
import { useMemo } from 'react';

import { skyColors, type DayPhase } from '@/components/world/scene';
import { hash } from '@/utils/number';

import type { Camera } from '../camera';
import type { ClimbSim } from '../sim';
import { SHEETS, frameAt, frameRect, type SpriteSheet } from '../sprites';
import { buildGeometry } from './levelGeometry';

const PIXEL = { filter: FilterMode.Nearest, mipmap: MipmapMode.None } as const;

const FAR = require('../../../../assets/world/far-mountains.png');
const CLOUDS = require('../../../../assets/world/clouds.png');
const MID = require('../../../../assets/world/ground-rock.png');

type Props = {
  sim: ClimbSim;
  camera: Camera;
  width: number;
  height: number;
  /** Height of the playfield above the touch controls. The camera centres here. */
  playHeight: number;
  /** Pixels per tile. */
  tile: number;
  timeMs: number;
  phase: DayPhase;
  weatherRisk: number;
  reducedMotion: boolean;
  lowPower: boolean;
};

const PALETTE = {
  rock: '#3e3732',
  rockGrain: '#4a423b',
  rockLight: '#9a8a74',
  rockShade: '#211c19',
  face: '#6a5d51',
  faceHolds: '#3f362f',
  loose: '#7c6a57',
  looseStones: '#a08b72',
  lip: '#b4a288',
  cairns: '#a49886',
  rest: '#7a6c5c',
  exit: '#5b3b22',
  ridge: '#6d6660',
  cliffHigh: '#6e6359',
  cliffLow: '#463d36',
  strata: 'rgba(30,24,20,0.28)',
  foreground: '#15110f',
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

/** A jagged ridge line, as a filled path, in a 0–1 box scaled to width × height. */
function ridgePath(width: number, height: number, seed: number, points: number) {
  const path = Skia.PathBuilder.Make().moveTo(0, height);
  for (let i = 0; i <= points; i += 1) {
    const n = hash(seed, i) % 1000;
    path.lineTo((i / points) * width, height * (0.15 + (n / 1000) * 0.55));
  }
  return path.lineTo(width, height).close().build();
}

export function ClimbCanvas({ sim, camera, width, height, playHeight, tile, timeMs, phase, weatherRisk, reducedMotion, lowPower }: Props) {
  const level = sim.level;
  const geometry = useMemo(() => buildGeometry(level, tile), [level, tile]);
  const ridge = useMemo(() => ridgePath(width * 2.4, height * 0.32, 3, 26), [width, height]);
  const foreground = useMemo(() => ridgePath(width * 1.6, height * 0.22, 9, 9), [width, height]);
  const far = useImage(FAR);
  const clouds = useImage(CLOUDS);
  const mid = useImage(MID);
  const you = useImage(SHEETS.you.source);
  const marco = useImage(SHEETS.marco.source);

  const sky = skyColors(phase);
  const t = reducedMotion ? 0 : timeMs;
  const depthBlur = lowPower ? 0 : 1;
  const shakeX = camera.shake > 0 ? Math.sin(timeMs * 0.09) * camera.shake * 5 : 0;
  const shakeY = camera.shake > 0 ? Math.cos(timeMs * 0.11) * camera.shake * 3 : 0;
  const worldX = Math.round(width / 2 - camera.x * tile + shakeX);
  const worldY = Math.round(playHeight / 2 - camera.y * tile + shakeY);
  // How far up the wall the camera is, 0 at the bottom, 1 at the top.
  const climb = 1 - camera.y / level.height;
  const horizon = height * (0.5 + climb * 0.18);
  const spriteScale = Math.max(1, Math.round((tile * 1.45) / 20));
  const mist = Math.min(0.5, 0.08 + weatherRisk / 220);

  const playerFrame = frameAt(SHEETS.you.clips[sim.pose], (sim.poseTicks * 1000) / 60);
  const marcoPose = sim.mate.state === 'helped' ? (sim.pose === 'climb' || sim.pose === 'hang' ? sim.pose : 'walk') : sim.mode === 'mate' ? 'help' : 'rest';
  const marcoFrame = frameAt(SHEETS.marco.clips[marcoPose], timeMs);

  const farW = width * 1.5;
  const farH = (farW * 540) / 960;
  const farX = -width * 0.25 - camera.x * tile * 0.04;
  const cloudW = width * 1.4;
  const cloudH = (cloudW * 286) / 1139;
  const cloudSpan = cloudW + width;
  const cloudX = (((t * 0.008 - camera.x * tile * 0.1) % cloudSpan) + cloudSpan) % cloudSpan - cloudW;
  const midW = width * 1.6;
  const midH = (midW * 540) / 960;
  const midX = -width * 0.3 - camera.x * tile * 0.18;
  const ridgeX = -width * 0.6 - camera.x * tile * 0.45;
  const ridgeY = horizon - height * 0.26 - (camera.y - level.height / 2) * tile * 0.3;
  const fgX = -width * 0.3 - camera.x * tile * 1.25 + shakeX;
  const fgY = height - height * 0.16 + (level.height - camera.y - 10) * tile * 0.25;

  const particles = reducedMotion ? 0 : lowPower ? 10 : 26;
  const gustAlpha = sim.gust === 'blow' ? 0.75 : sim.gust === 'warn' ? 0.3 : 0;

  return (
    <Canvas style={{ width, height }}>
      {/* 1. Sky and atmosphere */}
      <Rect x={0} y={0} width={width} height={height}>
        <LinearGradient start={vec(0, 0)} end={vec(0, height)} colors={[sky[0], sky[1], sky[2]]} />
      </Rect>
      <Circle cx={width * 0.78} cy={height * 0.14} r={width * 0.5}>
        <RadialGradient c={vec(width * 0.78, height * 0.14)} r={width * 0.5} colors={['rgba(255,244,214,0.55)', 'rgba(255,244,214,0)']} />
      </Circle>

      {/* 2. Distant range */}
      {far ? (
        <Image image={far} x={farX} y={horizon - farH * 0.92} width={farW} height={farH} fit="fill">
          {depthBlur ? <Blur blur={1.4} /> : null}
        </Image>
      ) : null}

      {/* 3. Clouds and haze */}
      {clouds ? <Image image={clouds} x={cloudX} y={height * 0.06 + climb * 30} width={cloudW} height={cloudH} fit="fill" opacity={0.85} /> : null}
      <Rect x={0} y={horizon - height * 0.2} width={width} height={height * 0.4}>
        <LinearGradient
          start={vec(0, horizon - height * 0.2)}
          end={vec(0, horizon + height * 0.2)}
          colors={['rgba(240,234,222,0)', 'rgba(240,234,222,0.55)', 'rgba(240,234,222,0)']}
        />
      </Rect>

      {/* 4. Middle ground: the valley floor and the far side of the wall */}
      {mid ? (
        <Image image={mid} x={midX} y={horizon - midH * 0.55} width={midW} height={midH} fit="fill">
          {depthBlur ? <Blur blur={0.8} /> : null}
        </Image>
      ) : null}
      <Group transform={[{ translateX: ridgeX }, { translateY: ridgeY }]} opacity={0.75}>
        <Path path={ridge} color={PALETTE.ridge} />
      </Group>

      {/* 5–7. The playable wall, characters, and markers */}
      <Group transform={[{ translateX: worldX }, { translateY: worldY }]}>
        {/* The cliff itself, behind the play space. */}
        <Group clip={geometry.backdrop}>
          <Rect x={-width} y={-height} width={level.width * tile + width * 2} height={level.height * tile + height * 2}>
            <LinearGradient start={vec(0, 0)} end={vec(0, level.height * tile)} colors={[PALETTE.cliffHigh, PALETTE.cliffLow]} />
          </Rect>
          <Path path={geometry.strata} color={PALETTE.strata} />
        </Group>
        <Rect x={-width} y={level.height * tile} width={level.width * tile + width * 2} height={height} color={PALETTE.rock} />
        <Path path={geometry.face} color={PALETTE.face} />
        <Path path={geometry.faceHolds} color={PALETTE.faceHolds} />
        <Path path={geometry.loose} color={PALETTE.loose} />
        <Path path={geometry.looseStones} color={PALETTE.looseStones} />
        <Path path={geometry.rock} color={PALETTE.rock} />
        <Path path={geometry.rockGrain} color={PALETTE.rockGrain} />
        <Path path={geometry.rockLight} color={PALETTE.rockLight} />
        <Path path={geometry.rockShade} color={PALETTE.rockShade} />
        <Path path={geometry.lip} color={PALETTE.lip} />
        <Path path={geometry.rest} color={PALETTE.rest} />
        <Path path={geometry.cairns} color={PALETTE.cairns} />
        <Path path={geometry.exit} color={PALETTE.exit} />

        {gustAlpha > 0
          ? Array.from({ length: 7 }, (_, i) => {
              const y = (15.6 + (i % 3) * 0.6) * tile;
              const x = ((((t * 0.4 + i * 97) % (level.width * tile)) + level.width * tile) % (level.width * tile));
              return (
                <Line
                  key={`gust-${i}`}
                  p1={vec(x, y)}
                  p2={vec(x - tile * (1.5 + (i % 2)), y + 2)}
                  color={`rgba(245,240,230,${gustAlpha})`}
                  strokeWidth={2}
                />
              );
            })
          : null}

        {sim.level.mate ? (
          <>
            <Oval x={sim.mate.x * tile - tile * 0.35} y={sim.mate.y * tile - tile * 0.08} width={tile * 0.7} height={tile * 0.16} color="rgba(0,0,0,0.3)" />
            <Sprite image={marco} sheet={SHEETS.marco} frame={marcoFrame} feetX={sim.mate.x * tile} feetY={sim.mate.y * tile} scale={spriteScale} facing={sim.mate.state === 'helped' ? sim.facing : -1} />
            {sim.mate.state === 'waiting' ? (
              <Circle cx={sim.mate.x * tile} cy={(sim.mate.y - 2.1) * tile + Math.sin(t * 0.005) * 3} r={tile * 0.14} color="#f2c14e" />
            ) : null}
          </>
        ) : null}

        {sim.grounded ? (
          <Oval x={sim.x * tile - tile * 0.35} y={sim.y * tile - tile * 0.08} width={tile * 0.7} height={tile * 0.16} color="rgba(0,0,0,0.35)" />
        ) : null}
        <Sprite
          image={you}
          sheet={SHEETS.you}
          frame={playerFrame}
          feetX={sim.x * tile}
          feetY={sim.y * tile}
          scale={spriteScale}
          facing={sim.facing}
        />
      </Group>

      {/* 8. Foreground occlusion, out of focus */}
      <Group transform={[{ translateX: fgX }, { translateY: fgY }]} opacity={0.92}>
        <Path path={foreground} color={PALETTE.foreground}>
          {depthBlur ? <Blur blur={3} /> : null}
        </Path>
      </Group>

      {/* 9. Weather: drifting mist and dust */}
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
        const speed = 0.02 + (n % 7) * 0.006;
        const x = ((n % 1000) / 1000) * width + Math.sin(t * 0.001 + i) * 10 + (sim.gust === 'blow' ? -t * 0.05 : 0);
        const y = (((n >> 10) % 1000) / 1000) * height + t * speed;
        return (
          <Circle
            key={`p-${i}`}
            cx={((x % width) + width) % width}
            cy={y % height}
            r={1 + (n % 3) * 0.5}
            color="rgba(250,246,238,0.55)"
          />
        );
      })}

      {/* 10. Grade and vignette */}
      <Rect x={0} y={0} width={width} height={height}>
        <RadialGradient
          c={vec(width / 2, height * 0.45)}
          r={Math.max(width, height) * 0.75}
          colors={['rgba(0,0,0,0)', phase === 'dusk' ? 'rgba(60,20,10,0.4)' : 'rgba(20,14,10,0.35)']}
        />
      </Rect>
    </Canvas>
  );
}
