import type { CheckpointId } from '@/game/types';

/**
 * Game sketches of ground the climber walks. Not a survey and not a route.
 */
export type TerrainId = 'valley' | 'forest' | 'moraine' | 'icefall' | 'glacier' | 'face' | 'col' | 'ridge';

export type TerrainPoint = { x: number; y: number };

export type TerrainScene = {
  id: TerrainId;
  label: string;
  /** t = 0 is the low side of the frame, t = 1 the high side. y grows downward. */
  foot: (t: number) => TerrainPoint;
};

export const TERRAIN_WIDTH = 360;
export const TERRAIN_HEIGHT = 168;

function walk(t: number, y0: number, y1 = y0): TerrainPoint {
  return { x: 36 + t * 288, y: y0 + (y1 - y0) * t };
}

export const TERRAIN: Record<TerrainId, TerrainScene> = {
  valley: { id: 'valley', label: 'Valley floor', foot: (t) => walk(t, 150, 144) },
  forest: { id: 'forest', label: 'Forest trail', foot: (t) => walk(t, 146, 136) },
  moraine: { id: 'moraine', label: 'Moraine', foot: (t) => walk(t, 152, 146) },
  icefall: { id: 'icefall', label: 'Icefall', foot: (t) => walk(t, 144, 136) },
  glacier: { id: 'glacier', label: 'Glacier', foot: (t) => walk(t, 158, 154) },
  face: { id: 'face', label: 'Steep face', foot: (t) => walk(t, 156, 150) },
  col: { id: 'col', label: 'High col', foot: (t) => walk(t, 158, 152) },
  ridge: {
    id: 'ridge',
    label: 'Summit ridge',
    foot: (t) => ({ x: 118 + t * 110, y: 156 - t * 58 }),
  },
};

function band(altitude: number): TerrainScene {
  if (altitude >= 8200) return TERRAIN.ridge;
  if (altitude >= 7600) return TERRAIN.col;
  if (altitude >= 6900) return TERRAIN.face;
  if (altitude >= 6200) return TERRAIN.glacier;
  if (altitude >= 5600) return TERRAIN.icefall;
  if (altitude >= 4500) return TERRAIN.moraine;
  if (altitude >= 2200) return TERRAIN.forest;
  return TERRAIN.valley;
}

export function terrainFor(checkpoint: CheckpointId, altitude: number): TerrainScene {
  if (checkpoint === 'summit') return TERRAIN.ridge;
  if (checkpoint === 'complete' || checkpoint === 'briefing') return TERRAIN.valley;
  return band(altitude);
}

export function groundPath(scene: TerrainScene): string {
  const parts: string[] = [];
  for (let i = 0; i <= 24; i += 1) {
    const point = scene.foot(i / 24);
    parts.push(`${i === 0 ? 'M' : 'L'}${point.x.toFixed(1)} ${point.y.toFixed(1)}`);
  }
  return `${parts.join(' ')} L${TERRAIN_WIDTH} ${TERRAIN_HEIGHT} L0 ${TERRAIN_HEIGHT} Z`;
}
