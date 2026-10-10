import type { PartyId, Pose } from '@/components/world/scene';
import type { CheckpointId } from '@/game/types';

/**
 * Where things go on the expedition diorama. Pure functions, no drawing:
 * the plate's own metadata (from tools/art/diorama.py) says where its trail
 * and camp fall, and these place the party, the camp and the route-map
 * marker on whatever size the screen gives the scene.
 */

export type PlatePoint = {
  /** 0..1 of the plate's width and height. */
  x: number;
  y: number;
  /** Plate heights per world unit at this depth. */
  scale: number;
};

export type PlateMeta = {
  zone: string;
  width: number;
  height: number;
  trail: readonly PlatePoint[];
  camp: PlatePoint;
};

/** The plate drawn to cover the view: its rectangle in view points. */
export type Fit = { x: number; y: number; width: number; height: number };

export function coverFit(meta: Pick<PlateMeta, 'width' | 'height'>, viewWidth: number, viewHeight: number, anchorY = 0.62): Fit {
  const scale = Math.max(viewWidth / meta.width, viewHeight / meta.height);
  const width = meta.width * scale;
  const height = meta.height * scale;
  return { x: (viewWidth - width) / 2, y: (viewHeight - height) * anchorY, width, height };
}

export function toView(fit: Fit, point: { x: number; y: number }) {
  return { x: fit.x + point.x * fit.width, y: fit.y + point.y * fit.height };
}

/**
 * People are drawn larger than the world would make them, as HD-2D games do,
 * so faces and gear read at phone size.
 */
export const PERSON_UNITS = 4.8;
/** How tall the figure is in the 32 x 40 sprite frame, in art pixels. */
export const FIGURE_PX = 30;

/** View points per sprite pixel at a depth on the plate, kept in a readable range. */
export function pixelSize(fit: Fit, scale: number): number {
  const raw = (PERSON_UNITS * scale * fit.height) / FIGURE_PX;
  return Math.min(1.4, Math.max(0.42, raw));
}

export type MapFrames = 'back' | 'front' | 'idle' | 'kneel' | 'sit';

export type Placed = {
  id: PartyId;
  /** Feet, in view points. */
  x: number;
  y: number;
  /** View points per sprite pixel. */
  px: number;
  frames: MapFrames;
  flip: boolean;
  /** Walk cycle offset, so the line does not march in step. */
  phaseMs: number;
  /** Slower steps for a tired walker. */
  tempo: number;
};

/** The leader stands this far up the plate; the line trails toward the camera. */
const LEAD_Y = 0.64;
const GAP = 8;
const LAG_GAP = 6;

function nearestIndex(trail: readonly PlatePoint[], y: number): number {
  let best = 0;
  for (let i = 0; i < trail.length; i += 1) {
    if (Math.abs(trail[i].y - y) < Math.abs(trail[best].y - y)) best = i;
  }
  return best;
}

/** Around the fire, in world units from the camp spot (x across, z away). */
const CAMP_SEATS: Record<PartyId, { x: number; z: number; frames: MapFrames }> = {
  lena: { x: -2.6, z: 1.2, frames: 'idle' },
  you: { x: 0.2, z: -2.2, frames: 'sit' },
  marco: { x: 2.8, z: 0.4, frames: 'sit' },
  jun: { x: -1.6, z: -1.6, frames: 'idle' },
};

/** Roughly how much a step away from the camera rises on the plate. */
const FORESHORTEN = 0.5;
/** Camp is drawn roomier than life, like the people in it. */
const CAMP_SPREAD = 2.2;

export function campPoint(meta: PlateMeta, x: number, z: number): { x: number; y: number; scale: number } {
  const { camp } = meta;
  return {
    x: camp.x + (x * CAMP_SPREAD * camp.scale * meta.height) / meta.width,
    y: camp.y - z * CAMP_SPREAD * camp.scale * FORESHORTEN,
    scale: camp.scale,
  };
}

/**
 * The party on the diorama. `order` runs from the camera up the trail, the
 * way the old diorama had it: Jun nearest, Lena (the guide) leading.
 */
export function partyLayout(
  meta: PlateMeta,
  fit: Fit,
  order: readonly { id: PartyId; pose: Pose }[],
  options: { camping: boolean; retreating: boolean },
): Placed[] {
  const placed: Placed[] = [];
  if (options.camping) {
    order.forEach(({ id, pose }, index) => {
      const seat = CAMP_SEATS[id];
      const point = campPoint(meta, seat.x, seat.z);
      const view = toView(fit, point);
      placed.push({
        id,
        x: view.x,
        y: view.y,
        px: pixelSize(fit, point.scale),
        frames: pose === 'kneel' ? 'kneel' : seat.frames,
        flip: seat.x > 0,
        phaseMs: index * 260,
        tempo: 1,
      });
    });
  } else {
    const lead = nearestIndex(meta.trail, LEAD_Y);
    // Walk back down the line from the leader, leaving a gap behind anyone lagging.
    let at = lead;
    const reversed = [...order].reverse();
    reversed.forEach(({ id, pose }, index) => {
      if (index > 0) at -= GAP;
      if (pose === 'lag' && index > 0) at -= LAG_GAP;
      const point = meta.trail[Math.max(0, Math.min(meta.trail.length - 1, at))];
      const view = toView(fit, point);
      const next = meta.trail[Math.min(meta.trail.length - 1, at + 2)];
      placed.push({
        id,
        x: view.x,
        y: view.y,
        px: pixelSize(fit, point.scale),
        frames: pose === 'kneel' ? 'kneel' : options.retreating ? 'front' : 'back',
        // Lean the way the trail bends.
        flip: next.x < point.x,
        phaseMs: index * 170,
        tempo: pose === 'lag' ? 0.65 : 1,
      });
    });
  }
  // Far first, so nearer figures overlap them.
  return placed.sort((a, b) => a.y - b.y);
}

/** The tents and the fire for a camp, as plate points. */
export function campProps(meta: PlateMeta) {
  return {
    tents: [campPoint(meta, -5.2, 6.2), campPoint(meta, 4.6, 7.4)],
    fire: campPoint(meta, 0, 0),
  };
}

/**
 * The route map: where each camp sits on the parchment (tools/art/diorama.py
 * draws Kibo's cone at the centre, Shira to the west). Lemosho walks in from
 * the west, round the south side, up from Barafu, and down Mweka.
 */
export const ROUTE_MAP: readonly { id: CheckpointId; x: number; y: number }[] = [
  { id: 'briefing', x: 0.07, y: 0.5 },
  { id: 'approach', x: 0.14, y: 0.47 },
  { id: 'ebc', x: 0.23, y: 0.42 },
  { id: 'camp1', x: 0.32, y: 0.41 },
  { id: 'camp2', x: 0.43, y: 0.58 },
  { id: 'camp3', x: 0.55, y: 0.67 },
  { id: 'camp4', x: 0.7, y: 0.58 },
  { id: 'summit', x: 0.56, y: 0.46 },
  { id: 'descent', x: 0.66, y: 0.8 },
  { id: 'complete', x: 0.68, y: 0.93 },
];

/** The Lava Tower detour between Shira 2 and Barranco, for the drawn line. */
const LAVA_TOWER = { x: 0.42, y: 0.39 };

export function routeLine(): { x: number; y: number }[] {
  const line: { x: number; y: number }[] = [];
  for (const stop of ROUTE_MAP) {
    line.push({ x: stop.x, y: stop.y });
    if (stop.id === 'camp1') line.push(LAVA_TOWER);
  }
  return line;
}

export function routeMarker(checkpoint: CheckpointId): { x: number; y: number } {
  const stop = ROUTE_MAP.find((item) => item.id === checkpoint) ?? ROUTE_MAP[0];
  return { x: stop.x, y: stop.y };
}
