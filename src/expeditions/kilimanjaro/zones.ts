import type { CheckpointId } from '@/game/types';
import type { GroundId } from '@/components/world/scene';

/** Which painted ground the party is walking. Not a map. */
export function kiliGround(checkpoint: CheckpointId, altitude: number): GroundId {
  if (checkpoint === 'summit' || altitude >= 5200) return 'snow';
  if (checkpoint === 'complete' || checkpoint === 'briefing' || altitude < 3200) return 'rainforest';
  if (altitude < 3900) return 'moorland';
  return 'desert';
}
