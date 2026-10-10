import {
  BackdropBlur,
  Canvas,
  Circle,
  DashPathEffect,
  FilterMode,
  Group,
  Image,
  ImageShader,
  LinearGradient,
  Mask,
  MipmapMode,
  Oval,
  Path,
  Points,
  RadialGradient,
  Rect,
  Skia,
  rect,
  useImage,
  vec,
  type SkImage,
} from '@shopify/react-native-skia';
import { useMemo } from 'react';

import { skyColors, type DayPhase, type PartyId } from '@/components/world/scene';
import { hash } from '@/utils/number';

import type { CheckpointId } from '@/game/types';

import { campProps, coverFit, pixelSize, routeLine, routeMarker, toView, type Placed } from './layout';
import { CAMP_PROPS, FOG, MAP_SHEETS, ROUTE_PARCHMENT, mapFrame, type Plate } from './plates';

const PIXEL = { filter: FilterMode.Nearest, mipmap: MipmapMode.None } as const;
const SMOOTH = { filter: FilterMode.Linear, mipmap: MipmapMode.None } as const;
const FRAME_W = 32;
const FRAME_H = 40;

export type WorldCanvasProps = {
  plate: Plate;
  width: number;
  height: number;
  phase: DayPhase;
  /** 0..1 how much weather is in the air (fog, particles). */
  weather: number;
  /** 0..1 how much snow is falling. */
  snow: number;
  camping: boolean;
  party: readonly Placed[];
  selected: PartyId | null;
  checkpoint: CheckpointId;
  timeMs: number;
  lowPower: boolean;
  showMap: boolean;
};

const NIGHT_SKY = ['#070b1a', '#121c38', '#26345a'] as const;

function triangle(points: readonly [number, number][]) {
  const path = Skia.PathBuilder.Make();
  points.forEach(([x, y], i) => (i === 0 ? path.moveTo(x, y) : path.lineTo(x, y)));
  path.close();
  return path.build();
}

function sky(phase: DayPhase): readonly [string, string, string] {
  return phase === 'night' ? NIGHT_SKY : skyColors(phase);
}

function Sprite({ image, frame, x, y, px, flip }: { image: SkImage | null; frame: number; x: number; y: number; px: number; flip: boolean }) {
  if (!image) return null;
  const sx = (frame % 8) * FRAME_W;
  const sy = Math.floor(frame / 8) * FRAME_H;
  const w = FRAME_W * px;
  const h = FRAME_H * px;
  const left = x - w / 2;
  const top = y - h;
  return (
    <Group origin={vec(x, 0)} transform={flip ? [{ scaleX: -1 }] : []}>
      <Group clip={rect(left, top, w, h)}>
        <Image image={image} x={left - sx * px} y={top - sy * px} width={image.width() * px} height={image.height() * px} fit="fill" sampling={PIXEL} />
      </Group>
    </Group>
  );
}

/** Additive light: a wide soft bloom and a hot core. */
function Glow({ x, y, r, color, strength }: { x: number; y: number; r: number; color: [number, number, number]; strength: number }) {
  if (strength <= 0.01) return null;
  const [cr, cg, cb] = color;
  return (
    <Group blendMode="plus">
      <Circle cx={x} cy={y} r={r}>
        <RadialGradient c={vec(x, y)} r={r} colors={[`rgba(${cr},${cg},${cb},${0.55 * strength})`, `rgba(${cr},${cg},${cb},0)`]} />
      </Circle>
      <Circle cx={x} cy={y} r={r * 0.22}>
        <RadialGradient c={vec(x, y)} r={r * 0.22} colors={[`rgba(255,250,235,${0.9 * strength})`, `rgba(${cr},${cg},${cb},0)`]} />
      </Circle>
    </Group>
  );
}

/** Deterministic drifting particles: one Points node per depth layer. */
function particleLayer(count: number, seed: number, width: number, height: number, t: number, fall: number, drift: number, sway: number) {
  const points = [];
  for (let i = 0; i < count; i += 1) {
    const a = hash(seed * 7919 + i);
    const b = hash(seed * 104729 + i * 31);
    const x0 = (a % 10000) / 10000;
    const y0 = (b % 10000) / 10000;
    const x = (((x0 * width + drift * t + Math.sin(t * 0.0011 + i) * sway) % width) + width) % width;
    const y = (((y0 * height + fall * t) % height) + height) % height;
    points.push(vec(x, y));
  }
  return points;
}

export function WorldCanvas({ plate, width, height, phase, weather, snow, camping, party, selected, checkpoint, timeMs, lowPower, showMap }: WorldCanvasProps) {
  const image = useImage(plate.image);
  const far = useImage(plate.far);
  const fog = useImage(FOG);
  const props = useImage(CAMP_PROPS);
  const parchment = useImage(ROUTE_PARCHMENT);
  const sheets: Record<PartyId, SkImage | null> = {
    you: useImage(MAP_SHEETS.you),
    marco: useImage(MAP_SHEETS.marco),
    lena: useImage(MAP_SHEETS.lena),
    jun: useImage(MAP_SHEETS.jun),
  };

  const fit = useMemo(() => coverFit(plate.meta, width, height), [plate.meta, width, height]);
  const camp = useMemo(() => campProps(plate.meta), [plate.meta]);
  const t = timeMs;
  const night = phase === 'night';
  const low = phase === 'dawn' || phase === 'dusk';
  const [skyTop, skyMid, skyLow] = sky(phase);
  const horizon = fit.y + fit.height * 0.32;

  const stars = useMemo(() => {
    const pts = [];
    for (let i = 0; i < 70; i += 1) {
      const a = hash(4049 + i);
      pts.push(vec((a % 1000) / 1000 * width, ((hash(a) % 1000) / 1000) * horizon * 0.9));
    }
    return pts;
  }, [width, horizon]);

  const route = useMemo(() => {
    const path = Skia.PathBuilder.Make();
    routeLine().forEach((p, i) => (i === 0 ? path.moveTo(p.x, p.y) : path.lineTo(p.x, p.y)));
    return path.build();
  }, []);

  // Particles: three depths, the nearest biggest and softest.
  const pCount = lowPower ? 0.4 : 1;
  const kind = plate.particles;
  const fallBase = kind === 'snow' ? 0.028 : kind === 'motes' ? -0.004 : 0.004;
  const driftBase = kind === 'snow' ? -0.006 - weather * 0.03 : kind === 'dust' ? 0.03 + weather * 0.04 : 0.008;
  const density = kind === 'snow' ? Math.max(0.35, snow) : kind === 'motes' ? (night ? 0.7 : 0.25) : 0.35 + weather * 0.4;
  const layers = [
    { n: Math.round(70 * density * pCount), size: 1.6, speed: 0.6, alpha: 0.55, seed: 1 },
    { n: Math.round(40 * density * pCount), size: 2.6, speed: 1, alpha: 0.75, seed: 2 },
    { n: Math.round(14 * density * pCount), size: 5, speed: 1.6, alpha: 0.5, seed: 3 },
  ];
  const particleColor =
    kind === 'snow' ? '255,255,255' : kind === 'motes' ? (night ? '200,255,150' : '236,240,170') : kind === 'seeds' ? '246,238,214' : '236,214,180';

  const fogDrift = (t * 0.008) % 512;
  const fogStrength = Math.min(0.8, 0.18 + weather * 0.6 + (night ? 0.1 : 0));
  const fireFlicker = 0.85 + 0.15 * Math.sin(t * 0.017) * Math.sin(t * 0.0071 + 1);
  const campFrame = Math.floor(t / 120) % 4;

  const mapR = Math.min(34, width * 0.09);
  const mapC = vec(width - mapR - 12, height - mapR - 12);
  const marker = routeMarker(checkpoint);

  return (
    <Canvas style={{ width, height }}>
      {/* 1. Sky, stars, moon or sun. */}
      <Rect x={0} y={0} width={width} height={height}>
        <LinearGradient start={vec(0, 0)} end={vec(0, horizon + fit.height * 0.1)} colors={[skyTop, skyMid, skyLow]} />
      </Rect>
      {night ? (
        <>
          <Points points={stars} mode="points" color="rgba(230,236,255,0.85)" strokeWidth={1.4} style="stroke" strokeCap="round" />
          <Glow x={width * 0.18} y={horizon * 0.35} r={width * 0.22} color={[170, 200, 255]} strength={0.7} />
          <Circle cx={width * 0.18} cy={horizon * 0.35} r={9} color="#f4f6ff" />
        </>
      ) : (
        <Glow x={width * 0.12} y={horizon * 0.2} r={width * 0.55} color={low ? [255, 170, 110] : [255, 236, 200]} strength={low ? 0.8 : 0.45} />
      )}

      {/* 2. The far mountain behind the plate's horizon, softened by distance. */}
      {far ? (
        <Group opacity={night ? 0.55 : 0.8}>
          <Image image={far} x={0} y={horizon - width * 0.42} width={width} height={width * 0.4} fit="cover" sampling={SMOOTH} />
        </Group>
      ) : null}

      {/* 3. The diorama plate. */}
      {image ? <Image image={image} x={fit.x} y={fit.y} width={fit.width} height={fit.height} fit="fill" sampling={SMOOTH} /> : null}

      {/* 4. Air: distance haze, then drifting fog banks. */}
      <Rect x={0} y={0} width={width} height={height}>
        <LinearGradient
          start={vec(0, horizon - 10)}
          end={vec(0, fit.y + fit.height * 0.7)}
          colors={[`${plate.haze}aa`, `${plate.haze}33`, `${plate.haze}00`]}
        />
      </Rect>
      {fog ? (
        <Mask
          mode="luminance"
          mask={
            <Rect x={0} y={0} width={width} height={height}>
              <LinearGradient
                start={vec(0, horizon - 20)}
                end={vec(0, height)}
                colors={['#000000', '#ffffff', '#777777', '#000000', '#555555', '#000000']}
                positions={[0, 0.12, 0.3, 0.5, 0.82, 1]}
              />
            </Rect>
          }
        >
          <Group opacity={fogStrength}>
            <Rect x={0} y={0} width={width} height={height}>
              <ImageShader image={fog} tx="repeat" ty="repeat" rect={rect(-fogDrift, 0, 512, 256)} />
            </Rect>
            <Group opacity={0.6}>
              <Rect x={0} y={0} width={width} height={height}>
                <ImageShader image={fog} tx="repeat" ty="repeat" rect={rect(fogDrift * 1.7, 90, 768, 384)} />
              </Rect>
            </Group>
          </Group>
        </Mask>
      ) : null}

      {/* 5. Camp: tents and the fire. */}
      {camping && props
        ? camp.tents.map((point, i) => {
            const v = toView(fit, point);
            const px = pixelSize(fit, point.scale) * 1.9;
            return (
              <Group key={`tent-${i}`}>
                <Oval x={v.x - 16 * px} y={v.y - 2 * px} width={32 * px} height={5 * px} color="rgba(10,12,16,0.3)" />
                <Group clip={rect(v.x - 16 * px, v.y - 24 * px, 32 * px, 24 * px)}>
                  <Image image={props} x={v.x - 16 * px - i * 32 * px} y={v.y - 24 * px} width={props.width() * px} height={props.height() * px} fit="fill" sampling={PIXEL} />
                </Group>
              </Group>
            );
          })
        : null}
      {camping && props
        ? (() => {
            const v = toView(fit, camp.fire);
            const px = pixelSize(fit, camp.fire.scale) * 1.3;
            return (
              <Group clip={rect(v.x - 16 * px, v.y - 22 * px, 32 * px, 24 * px)}>
                <Image image={props} x={v.x - 16 * px - (64 + campFrame * 32) * px} y={v.y - 22 * px} width={props.width() * px} height={props.height() * px} fit="fill" sampling={PIXEL} />
              </Group>
            );
          })()
        : null}

      {/* 6. The party, with contact shadows, far to near. */}
      {party.map((p) => (
        <Oval key={`shadow-${p.id}`} x={p.x - 9 * p.px} y={p.y - 2 * p.px} width={18 * p.px} height={4 * p.px} color="rgba(8,10,14,0.35)" />
      ))}
      {party.map((p) => (
        <Sprite
          key={p.id}
          image={sheets[p.id]}
          frame={mapFrame(p.frames, (t + p.phaseMs) * p.tempo)}
          x={p.x}
          y={p.y}
          px={p.px}
          flip={p.flip}
        />
      ))}
      {party
        .filter((p) => p.id === selected)
        .map((p) => {
          const top = p.y - FRAME_H * p.px - 6 + Math.sin(t * 0.006) * 2;
          return <Path key="marker" path={triangle([[p.x - 5, top - 7], [p.x + 5, top - 7], [p.x, top]])} color="#f6c445" />;
        })}

      {/* 7. Time of day: a graded wash over the world, then the lights on top. */}
      {night ? <Rect x={0} y={0} width={width} height={height} color="rgb(108,128,190)" blendMode="multiply" /> : null}
      {low ? <Rect x={0} y={0} width={width} height={height} color={phase === 'dawn' ? 'rgba(255,170,140,0.32)' : 'rgba(255,140,90,0.34)'} blendMode="softLight" /> : null}
      {phase === 'day' ? (
        <Rect x={0} y={0} width={width} height={height} blendMode="softLight">
          <LinearGradient start={vec(0, 0)} end={vec(width, height)} colors={['rgba(255,236,190,0.45)', 'rgba(255,236,190,0)', 'rgba(40,60,90,0.25)']} />
        </Rect>
      ) : null}
      {night && plate.zone === 'snow' ? <Rect x={0} y={0} width={width} height={height} color="rgba(120,170,255,0.12)" blendMode="screen" /> : null}

      {camping ? (
        <>
          {(() => {
            const v = toView(fit, camp.fire);
            const r = pixelSize(fit, camp.fire.scale) * 70;
            return <Glow x={v.x} y={v.y - r * 0.12} r={r} color={[255, 150, 60]} strength={(night ? 1 : low ? 0.7 : 0.3) * fireFlicker} />;
          })()}
          {camp.tents.map((point, i) => {
            const v = toView(fit, point);
            const r = pixelSize(fit, point.scale) * 40;
            return <Glow key={`tg-${i}`} x={v.x} y={v.y - r * 0.25} r={r} color={[255, 200, 120]} strength={night ? 0.6 : low ? 0.3 : 0} />;
          })}
        </>
      ) : null}
      {(night || low) && !camping
        ? party.map((p) => (
            <Glow key={`lamp-${p.id}`} x={p.x} y={p.y - FRAME_H * p.px * 0.72} r={p.px * 26} color={[255, 236, 180]} strength={night ? 0.75 : 0.35} />
          ))
        : null}

      {/* 8. Weather in the air, three depths. */}
      {layers.map((layer) =>
        layer.n > 0 ? (
          <Points
            key={`p-${layer.seed}`}
            points={particleLayer(layer.n, layer.seed, width, height, t, fallBase * layer.speed, driftBase * layer.speed, 6 * layer.speed)}
            mode="points"
            color={`rgba(${particleColor},${layer.alpha * (kind === 'motes' && night ? 0.6 + 0.4 * Math.sin(t * 0.004 + layer.seed) : 1)})`}
            strokeWidth={layer.size}
            style="stroke"
            strokeCap="round"
            blendMode={kind === 'motes' && night ? 'plus' : 'srcOver'}
          />
        ) : null,
      )}

      {/* 9. The lens: tilt-shift blur top and bottom, and a vignette. */}
      {!lowPower ? (
        <>
          <BackdropBlur blur={3} clip={rect(0, 0, width, height * 0.16)} />
          <BackdropBlur blur={2.5} clip={rect(0, height * 0.16, width, height * 0.06)} />
          <BackdropBlur blur={2} clip={rect(0, height * 0.9, width, height * 0.1)} />
        </>
      ) : null}
      <Rect x={0} y={0} width={width} height={height}>
        <RadialGradient
          c={vec(width / 2, height * 0.55)}
          r={Math.max(width, height) * 0.75}
          colors={['rgba(0,0,0,0)', 'rgba(0,0,0,0)', `rgba(6,8,16,${night ? 0.6 : 0.38})`]}
          positions={[0, 0.6, 1]}
        />
      </Rect>

      {/* 10. The route map: where on the mountain the party is. */}
      {showMap && parchment ? (
        <Group>
          <Circle cx={mapC.x} cy={mapC.y} r={mapR + 4} color="rgba(10,8,6,0.45)" />
          <Group clip={Skia.RRectXY(rect(mapC.x - mapR, mapC.y - mapR, mapR * 2, mapR * 2), mapR, mapR)}>
            <Image image={parchment} x={mapC.x - mapR} y={mapC.y - mapR} width={mapR * 2} height={mapR * 2} fit="fill" sampling={SMOOTH} />
            <Group transform={[{ translateX: mapC.x - mapR }, { translateY: mapC.y - mapR }, { scale: mapR * 2 }]}>
              <Path path={route} style="stroke" strokeWidth={1.6 / (mapR * 2)} color="rgba(150,40,20,0.85)">
                <DashPathEffect intervals={[3 / (mapR * 2), 2 / (mapR * 2)]} />
              </Path>
            </Group>
            {night ? <Rect x={mapC.x - mapR} y={mapC.y - mapR} width={mapR * 2} height={mapR * 2} color="rgba(30,40,80,0.35)" blendMode="multiply" /> : null}
          </Group>
          <Circle cx={mapC.x} cy={mapC.y} r={mapR} style="stroke" strokeWidth={3} color="#7a5a2e" />
          <Circle cx={mapC.x} cy={mapC.y} r={mapR - 2} style="stroke" strokeWidth={1} color="#e8d29a" />
          {(() => {
            const mx = mapC.x - mapR + marker.x * mapR * 2;
            const my = mapC.y - mapR + marker.y * mapR * 2;
            const bob = Math.sin(t * 0.005) * 1.2;
            const arrow = triangle([[mx, my - 1 + bob], [mx - 4, my - 9 + bob], [mx + 4, my - 9 + bob]]);
            return (
              <>
                <Circle cx={mx} cy={my} r={2.2} color="#fff4c8" />
                <Path path={arrow} color="#f6c445" />
                <Path path={arrow} color="#5a3a10" style="stroke" strokeWidth={0.8} />
              </>
            );
          })()}
        </Group>
      ) : null}
    </Canvas>
  );
}

