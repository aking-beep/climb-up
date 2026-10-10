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
import type { ClimbScene, PartyMember } from '../scenes';
import type { ClimbSim, Pose } from '../sim';
import { SHEETS, frameAt, frameRect, type SpriteSheet } from '../sprites';
import { buildBackdrop } from './levelGeometry';
import { TILE_PX, buildTileBatch } from './tileset';

const PIXEL = { filter: FilterMode.Nearest, mipmap: MipmapMode.None } as const;

const CLOUDS = require('../../../../assets/world/clouds.png');
const TILES = require('../../../../assets/hd2d/terrain/barranco-tiles.png');
const TENT = require('../../../../assets/world/pixel-tent.png');

const NIGHT_SKY = ['#060915', '#10172f', '#1e2848'] as const;
const DAWN_SKY = ['#25284f', '#a35c74', '#f0a872'] as const;

type Props = {
  scene: ClimbScene;
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
  return <Oval x={x * tile - tile * 0.45} y={y * tile - tile * 0.1} width={tile * 0.9} height={tile * 0.2} color={`rgba(12,8,6,${strength})`} />;
}

/** A small warm pool of headlamp light, for the night. */
function Lamp({ x, y, r, strength }: { x: number; y: number; r: number; strength: number }) {
  return (
    <Circle cx={x} cy={y} r={r}>
      <RadialGradient c={vec(x, y)} r={r} colors={[`rgba(255,226,160,${strength})`, 'rgba(255,226,160,0)']} />
    </Circle>
  );
}

function mix(a: string, b: string, t: number): string {
  const pa = [1, 3, 5].map((i) => parseInt(a.slice(i, i + 2), 16));
  const pb = [1, 3, 5].map((i) => parseInt(b.slice(i, i + 2), 16));
  const c = pa.map((v, i) => Math.round(v + (pb[i] - v) * t));
  return `rgb(${c[0]},${c[1]},${c[2]})`;
}

export function ClimbCanvas({ scene, sim, camera, width, height, playHeight, tile, timeMs, phase, weatherRisk, reducedMotion, lowPower }: Props) {
  const { theme } = scene;
  const level = sim.level;
  const backdrop = useMemo(() => buildBackdrop(level, tile), [level, tile]);
  const batch = useMemo(() => buildTileBatch(level, tile, theme.snow), [level, tile, theme.snow]);
  const tint = useMemo(
    () => (theme.tileTint ? batch.sprites.map(() => Skia.Color(theme.tileTint as string)) : undefined),
    [batch, theme.tileTint],
  );
  const far = useImage(theme.far);
  const mid = useImage(theme.mid);
  const cliff = useImage(theme.cliff);
  const foreground = useImage(theme.foreground);
  const clouds = useImage(CLOUDS);
  const tiles = useImage(TILES);
  const tent = useImage(TENT);
  const sheets: Record<PartyMember, SkImage | null> = {
    you: useImage(SHEETS.you.source),
    marco: useImage(SHEETS.marco.source),
    lena: useImage(SHEETS.lena.source),
    jun: useImage(SHEETS.jun.source),
  };

  const t = reducedMotion ? 0 : timeMs;
  const depthBlur = !lowPower;
  const shakeX = camera.shake > 0 ? Math.sin(timeMs * 0.09) * camera.shake * 5 : 0;
  const shakeY = camera.shake > 0 ? Math.cos(timeMs * 0.11) * camera.shake * 3 : 0;
  const worldX = Math.round(width / 2 - camera.x * tile + shakeX);
  const worldY = Math.round(playHeight / 2 - camera.y * tile + shakeY);
  // How far up the wall the camera is, 0 at the bottom, 1 at the top.
  const climb = 1 - camera.y / level.height;
  // How far up the climber is: at night, this is how close dawn is.
  const progress = Math.min(1, Math.max(0, 1 - sim.y / level.height));
  const dawn = theme.night ? Math.pow(progress, 1.4) : 1;
  const horizon = height * (0.48 + climb * 0.2);
  const px = tile / TILE_PX; // one art pixel, in points
  const mist = Math.min(0.5, (theme.night ? 0.03 : 0.06) + weatherRisk / 240);

  const sky = theme.night ? ([0, 1, 2] as const).map((i) => mix(NIGHT_SKY[i], DAWN_SKY[i], dawn)) : skyColors(phase);
  const playerFrame = frameAt(SHEETS.you.clips[sim.pose], (sim.poseTicks * 1000) / 60);
  const matePose: Pose =
    sim.mate.state === 'helped' ? (sim.pose === 'climb' || sim.pose === 'hang' ? sim.pose : sim.pose === 'walk' || sim.pose === 'tired' ? 'walk' : 'idle') : sim.mode === 'mate' ? 'help' : 'rest';
  const mateSheet = scene.mate ? SHEETS[scene.mate] : null;

  // Background layers, sized from the screen and moved by the camera at their own rate.
  const farW = width * theme.farScale;
  const farH = (farW * 560) / 1400;
  const farX = width / 2 - farW * 0.55 - camera.x * tile * 0.03;
  const farY = theme.night
    ? horizon - farH * 0.55 + (level.height - camera.y) * tile * 0.04
    : horizon - farH * 0.92 + (camera.y - level.height) * tile * 0.05;
  const cloudW = width * 1.4;
  const cloudH = (cloudW * 286) / 1139;
  const cloudSpan = cloudW + width;
  const cloudX = (((t * 0.008 - camera.x * tile * 0.1) % cloudSpan) + cloudSpan) % cloudSpan - cloudW;
  const midW = width * 1.9;
  const midH = (midW * 520) / 1400;
  const midX = width / 2 - midW * 0.5 - camera.x * tile * 0.2;
  const midY = horizon - midH * 0.42 + (level.height - camera.y) * tile * 0.1;
  const fgW = width * 1.5;
  const fgH = (fgW * 420) / 1400;
  const fgX = width / 2 - fgW * 0.5 - (camera.x - level.width / 2) * tile * 0.35 + shakeX;
  const fgY = height - fgH * 0.62 + (level.height - camera.y - 9) * tile * 0.3;
  const cliffScale = (tile * 8) / 256;

  const particles = reducedMotion ? 0 : lowPower ? 10 : theme.particles === 'snow' ? 40 : 24;
  const gustAlpha = sim.gust === 'blow' ? 0.75 : sim.gust === 'warn' ? 0.3 : 0;
  const shadowX = ((t * 0.012) % (level.width * tile * 2)) - level.width * tile * 0.5;

  // Night: where the headlamp is, on screen.
  const lampX = worldX + sim.x * tile;
  const lampY = worldY + (sim.y - 1.6) * tile;
  const darkness = theme.night ? 0.86 * (1 - dawn * 0.75) : 0;

  return (
    <Canvas style={{ width, height }}>
      {/* 1. Sky, sun or stars */}
      <Rect x={0} y={0} width={width} height={height}>
        <LinearGradient start={vec(0, 0)} end={vec(0, height)} colors={[sky[0], sky[1], sky[2]]} />
      </Rect>
      {theme.night ? (
        Array.from({ length: lowPower ? 40 : 90 }, (_, i) => {
          const n = hash(i, 77);
          const twinkle = reducedMotion ? 1 : 0.7 + 0.3 * Math.sin(t * 0.002 + i);
          return (
            <Rect
              key={`star-${i}`}
              x={(n % 1000) / 1000 * width}
              y={((n >> 10) % 1000) / 1000 * height * 0.7}
              width={n % 7 === 0 ? 2 : 1}
              height={n % 7 === 0 ? 2 : 1}
              color={`rgba(240,244,255,${(1 - dawn) * 0.85 * twinkle})`}
            />
          );
        })
      ) : (
        <Circle cx={width * 0.82} cy={height * 0.1} r={width * 0.6}>
          <RadialGradient c={vec(width * 0.82, height * 0.1)} r={width * 0.6} colors={['rgba(255,240,205,0.6)', 'rgba(255,240,205,0)']} />
        </Circle>
      )}
      {theme.night && dawn > 0.05 ? (
        <Circle cx={width * 0.85} cy={horizon + height * 0.05} r={width * 0.9}>
          <RadialGradient c={vec(width * 0.85, horizon + height * 0.05)} r={width * 0.9} colors={[`rgba(255,180,120,${dawn * 0.55})`, 'rgba(255,180,120,0)']} />
        </Circle>
      ) : null}

      {/* 2. The far layer: Kibo by day, Mawenzi over the cloud sea by night */}
      {far ? (
        <Image image={far} x={farX} y={farY} width={farW} height={farH} fit="fill">
          {depthBlur ? <Blur blur={0.6} /> : null}
        </Image>
      ) : null}

      {/* 3. Clouds and the haze band */}
      {theme.clouds && clouds ? <Image image={clouds} x={cloudX} y={height * 0.05 + climb * 40} width={cloudW} height={cloudH} fit="fill" opacity={0.8} /> : null}
      {!theme.night ? (
        <Rect x={0} y={horizon - height * 0.16} width={width} height={height * 0.32}>
          <LinearGradient
            start={vec(0, horizon - height * 0.16)}
            end={vec(0, horizon + height * 0.16)}
            colors={['rgba(236,232,222,0)', 'rgba(236,232,222,0.5)', 'rgba(236,232,222,0)']}
          />
        </Rect>
      ) : null}

      {/* 4. The middle ground */}
      {mid && theme.mid !== theme.far ? (
        <Image image={mid} x={midX} y={midY} width={midW} height={midH} fit="fill">
          {depthBlur ? <Blur blur={0.7} /> : null}
        </Image>
      ) : null}

      {theme.sunShafts && !lowPower
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

      {/* 5–7. The climb, its people, and their marks */}
      <Group transform={[{ translateX: worldX }, { translateY: worldY }]}>
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
          <Rect x={level.width * tile * 0.55} y={-height} width={level.width * tile} height={level.height * tile + height * 2}>
            <LinearGradient start={vec(level.width * tile * 0.55, 0)} end={vec(level.width * tile * 1.2, 0)} colors={['rgba(14,10,8,0)', 'rgba(14,10,8,0.35)']} />
          </Rect>
        </Group>
        <Rect x={-width} y={level.height * tile} width={level.width * tile + width * 2} height={height * 2} color={theme.night ? '#11131c' : '#1d1714'} />

        {/* Camp */}
        {tent && scene.camp.tent ? (
          <Image
            image={tent}
            x={scene.camp.tent.x * tile}
            y={scene.camp.tent.y * tile - (3 * tile * 60) / 96}
            width={3 * tile}
            height={(3 * tile * 60) / 96}
            fit="fill"
            sampling={PIXEL}
          />
        ) : null}
        {scene.camp.figures.map((figure, i) => (
          <Group key={`camp-${figure.who}`}>
            <Shadow x={figure.x} y={figure.y} tile={tile} strength={0.3} />
            <Sprite
              image={sheets[figure.who]}
              sheet={SHEETS[figure.who]}
              frame={frameAt(SHEETS[figure.who].clips[figure.pose], timeMs + i * 400)}
              feetX={figure.x * tile}
              feetY={figure.y * tile}
              scale={px}
              facing={figure.facing}
            />
          </Group>
        ))}

        {tiles ? (
          <Atlas image={tiles} sprites={batch.sprites} transforms={batch.transforms} colors={tint} colorBlendMode="modulate" sampling={PIXEL} />
        ) : null}

        {!lowPower && !theme.night ? (
          <Oval x={shadowX} y={level.height * tile * 0.25} width={level.width * tile * 0.9} height={level.height * tile * 0.5} color="rgba(12,10,14,0.10)">
            <Blur blur={tile} />
          </Oval>
        ) : null}

        {gustAlpha > 0
          ? Array.from({ length: 8 }, (_, i) => {
              const exposedTop = level.tiles.findIndex((kind) => kind === 4);
              const row = exposedTop >= 0 ? Math.floor(exposedTop / level.width) : 16;
              const y = (row + 0.4 + (i % 3) * 0.6) * tile;
              const span = level.width * tile;
              const x = (((t * 0.45 + i * 97) % span) + span) % span;
              return <Line key={`gust-${i}`} p1={vec(x, y)} p2={vec(x - tile * (1.6 + (i % 2)), y + px)} color={`rgba(245,240,230,${gustAlpha})`} strokeWidth={px} />;
            })
          : null}

        {level.mate && mateSheet && scene.mate ? (
          <>
            <Shadow x={sim.mate.x} y={sim.mate.y} tile={tile} strength={0.3} />
            <Sprite
              image={sheets[scene.mate]}
              sheet={mateSheet}
              frame={frameAt(mateSheet.clips[matePose], timeMs)}
              feetX={sim.mate.x * tile}
              feetY={sim.mate.y * tile}
              scale={px}
              facing={sim.mate.state === 'helped' ? sim.facing : -1}
            />
            {sim.mate.state === 'waiting' ? (
              <Group transform={[{ translateY: reducedMotion ? 0 : Math.sin(t * 0.005) * px * 1.5 }]}>
                <Path path={`M ${sim.mate.x * tile} ${(sim.mate.y - 2.7) * tile} l ${-px * 3} ${-px * 4} l ${px * 6} 0 Z`} color="#f2c14e" />
              </Group>
            ) : null}
          </>
        ) : null}

        {sim.grounded ? <Shadow x={sim.x} y={sim.y} tile={tile} /> : null}
        <Sprite image={sheets.you} sheet={SHEETS.you} frame={playerFrame} feetX={sim.x * tile} feetY={sim.y * tile} scale={px} facing={sim.facing} />
      </Group>

      {/* 8. Foreground, out of focus */}
      {foreground ? (
        <Image image={foreground} x={fgX} y={fgY} width={fgW} height={fgH} fit="fill" opacity={0.95}>
          {depthBlur ? <Blur blur={4} /> : null}
        </Image>
      ) : null}

      {/* 9. Weather */}
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
        const snow = theme.particles === 'snow';
        const speed = (snow ? 0.03 : 0.015) + (n % 7) * 0.005;
        const x = ((n % 1000) / 1000) * width + Math.sin(t * 0.001 + i) * (snow ? 18 : 10) + (sim.gust === 'blow' ? -t * 0.05 : 0);
        const y = (((n >> 10) % 1000) / 1000) * height + t * speed;
        const size = snow ? (n % 3 === 0 ? 3 : 2) : n % 3 === 0 ? 2 : 1.5;
        return (
          <Rect
            key={`p-${i}`}
            x={Math.round(((x % width) + width) % width)}
            y={Math.round(y % height)}
            width={size}
            height={size}
            color={snow ? 'rgba(244,248,255,0.85)' : 'rgba(250,244,230,0.6)'}
          />
        );
      })}

      {/* 10. Night: darkness, the headlamp's pool and beam, other lamps */}
      {theme.night ? (
        <>
          <Rect x={0} y={0} width={width} height={height}>
            <RadialGradient
              c={vec(lampX, lampY)}
              r={tile * 4.2}
              colors={['rgba(6,8,20,0)', `rgba(6,8,20,${darkness * 0.55})`, `rgba(6,8,20,${darkness})`]}
              positions={[0, 0.55, 1]}
            />
          </Rect>
          <Path
            path={`M ${lampX} ${lampY - px * 2} L ${lampX + sim.facing * tile * 4.5} ${lampY - tile * 1.2} L ${lampX + sim.facing * tile * 4.5} ${lampY + tile * 1.0} Z`}
            opacity={0.22 * (1 - dawn * 0.8)}
          >
            <LinearGradient start={vec(lampX, lampY)} end={vec(lampX + sim.facing * tile * 4.5, lampY)} colors={['rgba(255,236,170,1)', 'rgba(255,236,170,0)']} />
          </Path>
          <Lamp x={lampX + sim.facing * px * 5} y={lampY - px * 3} r={tile * 0.6} strength={0.7} />
          {level.mate ? <Lamp x={worldX + sim.mate.x * tile} y={worldY + (sim.mate.y - 1.6) * tile} r={tile * 1.4} strength={0.35 * (1 - dawn * 0.6)} /> : null}
          {scene.camp.figures.map((figure) => (
            <Lamp key={`lamp-${figure.who}`} x={worldX + figure.x * tile} y={worldY + (figure.y - 1.6) * tile} r={tile * 1.4} strength={0.35 * (1 - dawn * 0.6)} />
          ))}
        </>
      ) : null}

      {/* 11. Grade and vignette */}
      <Rect x={0} y={0} width={width} height={height}>
        <LinearGradient
          start={vec(0, 0)}
          end={vec(0, height)}
          colors={theme.night ? ['rgba(255,170,130,0.06)', 'rgba(60,80,140,0.04)', 'rgba(10,14,40,0.18)'] : ['rgba(255,214,160,0.10)', 'rgba(255,214,160,0)', 'rgba(30,20,40,0.12)']}
        />
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
