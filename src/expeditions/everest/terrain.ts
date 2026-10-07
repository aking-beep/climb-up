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

export const TERRAIN: Record<TerrainId, TerrainScene> = {
  valley: {
    id: 'valley',
    label: 'Valley floor',
    foot: (t) => ({ x: t * TERRAIN_WIDTH, y: 138 - t * 8 }),
  },
  forest: {
    id: 'forest',
    label: 'Forest trail',
    foot: (t) => ({ x: t * TERRAIN_WIDTH, y: 150 - t * 58 }),
  },
  moraine: {
    id: 'moraine',
    label: 'Moraine',
    foot: (t) => ({
      x: t * TERRAIN_WIDTH,
      y: 142 - t * 16 - Math.sin(t * Math.PI * 4) * 6,
    }),
  },
  icefall: {
    id: 'icefall',
    label: 'Icefall',
    foot: (t) => {
      const step = Math.round(t * 5) / 5;
      return { x: t * TERRAIN_WIDTH, y: 146 - step * 52 };
    },
  },
  glacier: {
    id: 'glacier',
    label: 'Glacier',
    foot: (t) => ({ x: t * TERRAIN_WIDTH, y: 112 + Math.sin(t * Math.PI) * 24 }),
  },
  face: {
    id: 'face',
    label: 'Steep face',
    foot: (t) => ({ x: t * TERRAIN_WIDTH, y: 152 - t * 78 }),
  },
  col: {
    id: 'col',
    label: 'High col',
    foot: (t) => ({ x: t * TERRAIN_WIDTH, y: 86 + Math.sin(t * Math.PI) * 34 }),
  },
  ridge: {
    id: 'ridge',
    label: 'Summit ridge',
    foot: (t) => ({ x: t * TERRAIN_WIDTH, y: 146 - t ** 1.2 * 84 }),
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
