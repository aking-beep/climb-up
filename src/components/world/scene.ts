import type { CheckpointId } from '@/game/types';
import type { TerrainId } from '@/expeditions/everest/terrain';

export type DayPhase = 'night' | 'dawn' | 'day' | 'dusk';
export type Pose = 'walk' | 'lag' | 'kneel';
export type GroundId = 'valley' | 'forest' | 'rock' | 'snow' | 'rainforest' | 'moorland' | 'desert';
export type PartyId = 'jun' | 'marco' | 'you' | 'lena';

export const PARTY: readonly { id: PartyId; name: string; role: string }[] = [
  { id: 'jun', name: 'Jun', role: 'Doctor' },
  { id: 'marco', name: 'Marco', role: 'Climber' },
  { id: 'you', name: 'You', role: 'Lead' },
  { id: 'lena', name: 'Lena', role: 'Guide' },
];

/** Expedition clock starts at morning. The engine's elapsed hours are unchanged. */
export function expeditionHour(elapsedHours: number): number {
  return (9 + elapsedHours) % 24;
}

export function dayPhase(hour: number): DayPhase {
  if (hour < 5 || hour >= 20) return 'night';
  if (hour < 8) return 'dawn';
  if (hour >= 17) return 'dusk';
  return 'day';
}

export function skyColors(phase: DayPhase): readonly [string, string, string] {
  if (phase === 'night') return ['#121820', '#243246', '#4a5964'];
  if (phase === 'dawn') return ['#c47862', '#e7c3a4', '#f0e6d4'];
  if (phase === 'dusk') return ['#7d403c', '#d39270', '#f0e2cc'];
  return ['#8fa6ae', '#d5ddd6', '#f3efe6'];
}

export function routeProgress(altitude: number, low = 1400, high = 8849): number {
  const span = high - low;
  return Math.min(1, Math.max(0, (altitude - low) / span));
}

export function groundFor(terrainId: TerrainId): GroundId {
  if (terrainId === 'forest') return 'forest';
  if (terrainId === 'moraine') return 'rock';
  if (terrainId === 'valley') return 'valley';
  return 'snow';
}

export function campVisible(checkpoint: CheckpointId): boolean {
  return (
    checkpoint === 'ebc' ||
    checkpoint === 'camp1' ||
    checkpoint === 'camp2' ||
    checkpoint === 'camp3' ||
    checkpoint === 'camp4'
  );
}

/** Visual only. Marco, second on the rope, shows the team's fatigue. */
export function partyPoses(teamCondition: number, energy: number): Pose[] {
  if (teamCondition < 42 || energy < 28) return ['walk', 'kneel', 'walk', 'walk'];
  if (teamCondition < 68 || energy < 48) return ['walk', 'lag', 'walk', 'walk'];
  return ['walk', 'walk', 'walk', 'walk'];
}

export function partyCaption(poses: readonly Pose[]): string | null {
  if (poses[1] === 'kneel') return 'Marco is down.';
  if (poses[1] === 'lag') return 'Marco is falling off the pace.';
  return null;
}

export function partyLabel(poses: readonly Pose[]): string {
  const bits = PARTY.map((person, index) => {
    const pose = poses[index];
    if (pose === 'kneel') return `${person.name} is down`;
    if (pose === 'lag') return `${person.name} is lagging`;
    return person.name;
  });
  return `Rope team. ${bits.join(', ')}.`;
}

export function snowDensity(altitude: number, weatherRisk: number): number {
  const alpine = altitude >= 5364 ? 0.4 : altitude >= 4500 ? 0.12 : 0;
  const storm = weatherRisk >= 45 ? (weatherRisk - 45) / 70 : 0;
  return Math.min(1, alpine + storm);
}
