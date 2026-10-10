import { Tile, isClimbable, tileAt } from './level';
import { TUNING, type ClimbSim } from './sim';

/** One short line telling the player what the climber can do right now. */
export function hintFor(sim: ClimbSim): string | null {
  if (sim.mode === 'done') return null;
  if (sim.slipTicks > 0) return sim.slips >= TUNING.maxSlips ? 'Too many slips. The team calls it.' : 'Slipped. Back to the last cairn.';
  if (sim.mode !== 'play') return null;
  const here = tileAt(sim.level, sim.x, sim.y - 0.5);
  const exposed = here === Tile.Exposed;
  if (exposed && sim.gust === 'blow') return 'Gust. Stand still.';
  if (exposed && sim.gust === 'warn') return 'Wind coming. Stop and brace.';
  if (sim.stamina < sim.maxStamina * 0.2) {
    return sim.climbing ? 'Arms are going. Get onto a ledge.' : 'Stand still to get your breath back.';
  }
  if (sim.climbing) {
    const above = tileAt(sim.level, sim.x, sim.y - TUNING.height - 0.1);
    if (!isClimbable(above)) return 'Top of the face. Step left or right onto the ledge.';
    return null;
  }
  const face = isClimbable(tileAt(sim.level, sim.x, sim.y - 0.5));
  if (face && sim.grounded) return 'Rock face. Hold up to scramble.';
  if (here === Tile.Rest && sim.grounded) return 'A sitting stone. Stand here to recover faster.';
  if (exposed) return 'Exposed step. Move between gusts.';
  return null;
}
