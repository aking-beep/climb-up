import type { HybridExpedition } from '@/game/hybrid/coordinator';
import type { ChallengeDefinition, ChallengeId, OutcomeModifier } from '@/game/hybrid/types';
import type { CheckpointId, Effect } from '@/game/types';

import { kilimanjaro } from './index';

/**
 * Kilimanjaro's three played climbs. Each guards a camp: the only way up and
 * out of Shira 2, Barranco, and Barafu is to climb. The card choice still
 * carries the day (height, hours, score); how the climb went shades it by a
 * bounded amount. Game fiction inspired by the places, not route
 * descriptions.
 */
type ClimbCopy = {
  id: ChallengeId;
  title: string;
  gate: CheckpointId;
  /** Prefix for once-only score marks, distinct per climb. */
  mark: string;
  /** The teammate met on the way, if the level has one. */
  mate: string | null;
  topOut: string;
  backOff: string;
  fail: string;
  /** What the climb costs. Later climbs cost more: the summit most of all. */
  stakes: Stakes;
};

type Stakes = {
  /** Health per slip, and at most. */
  slip: number;
  slipMax: number;
  /** A failed attempt. */
  failHealth: number;
  failEnergy: number;
  /** Stopping for the teammate: team condition and teamwork. */
  assistTeam: number;
  assistScore: number;
  /** The helped teammate shares the load tomorrow. Shows even when the team is already at its best. */
  assistEnergy: number;
  /** Leaving the teammate for Lena. Negative. */
  leftTeam: number;
  leftScore: number;
};

/** The day a turned-back climb costs, beyond the card's own hours. */
function lostDay(base: Effect): number {
  return Math.max(0, 24 - (base.hours ?? 6));
}

function climb(copy: ClimbCopy): ChallengeDefinition {
  return {
    id: copy.id,
    title: copy.title,
    gate: copy.gate,
    modifier(outcome, base): OutcomeModifier {
      // Half the effort is spent; none of the height is kept.
      const refund = base.energy && base.energy < 0 ? Math.round(-base.energy / 2) : 0;
      const unlearn = base.acclimatization && base.acclimatization > 0 ? -base.acclimatization : 0;
      const unsettle = base.teamCondition && base.teamCondition > 0 ? -base.teamCondition : 0;

      if (outcome.result === 'retreat') {
        return {
          note: copy.backOff,
          move: 'wait',
          hours: lostDay(base),
          keepBaseScores: false,
          stats: { energy: refund, acclimatization: unlearn, teamCondition: unsettle },
          scores: {
            judgment: { label: `You backed off ${copy.title} while it was still your choice`, delta: 3, mark: `${copy.mark}-backoff` },
          },
        };
      }
      if (outcome.result === 'fail') {
        return {
          note: copy.fail,
          move: 'wait',
          hours: lostDay(base),
          keepBaseScores: false,
          stats: { health: copy.stakes.failHealth, energy: copy.stakes.failEnergy, acclimatization: unlearn, teamCondition: unsettle - 4 },
          scores: {
            riskManagement: { label: `${copy.title} took more than the team had`, delta: -6, mark: `${copy.mark}-fail` },
          },
        };
      }

      const stats: OutcomeModifier['stats'] = {};
      const scores: OutcomeModifier['scores'] = {};
      const bits = [copy.topOut];
      const { stakes } = copy;
      if (outcome.slips > 0) {
        stats.health = -Math.min(stakes.slipMax, outcome.slips * stakes.slip);
        bits.push(outcome.slips === 1 ? 'after one slip' : `after ${outcome.slips} slips`);
      }
      if (outcome.staminaLeft < 25) {
        stats.energy = -4;
        bits.push('with nothing left in your arms');
      }
      if (copy.mate && outcome.assisted === true) {
        stats.teamCondition = stakes.assistTeam;
        stats.energy = (stats.energy ?? 0) + stakes.assistEnergy;
        scores.teamwork = { label: `You stopped for ${copy.mate} on ${copy.title}`, delta: stakes.assistScore, mark: `${copy.mark}-assist` };
        bits.push(`and ${copy.mate} is beside you`);
      } else if (copy.mate && outcome.assisted === false) {
        stats.teamCondition = stakes.leftTeam;
        scores.teamwork = { label: `You left ${copy.mate} for Lena on ${copy.title}`, delta: stakes.leftScore, mark: `${copy.mark}-left` };
        bits.push(`and Lena brings ${copy.mate} up later`);
      }
      if (outcome.regrouped) {
        stats.energy = (stats.energy ?? 0) + 2;
        scores.judgment = { label: `You regrouped halfway up ${copy.title}`, delta: 3, mark: `${copy.mark}-regroup` };
      }
      return {
        note: `${bits.join(' ')}.`,
        stats,
        hours: outcome.regrouped ? 1 : 0,
        keepBaseScores: true,
        scores,
      };
    },
  };
}

export const LAVA_TOWER = climb({
  id: 'lava-tower',
  title: 'the Lava Tower',
  gate: 'camp1',
  mark: 'tower',
  mate: null,
  topOut: 'You touch the top of the Lava Tower and drop to Barranco to sleep low',
  backOff: 'You turn back under the tower and the party walks down to the Shira 2 tents again.',
  fail: 'The tower scree keeps sliding out from under you. You go back down to Shira 2, slowly.',
  stakes: { slip: 1, slipMax: 4, failHealth: -4, failEnergy: -3, assistTeam: 0, assistScore: 0, assistEnergy: 0, leftTeam: 0, leftScore: 0 },
});

export const BARRANCO_WALL = climb({
  id: 'barranco-wall',
  title: 'the Barranco Wall',
  gate: 'camp2',
  mark: 'wall',
  mate: 'Marco',
  topOut: 'You top out on the wall, and Karanga is pitched as the light goes',
  backOff: 'You back off the wall and the party walks down to the Barranco tents again.',
  fail: 'The wall takes more than the party has. You climb down to Barranco, slowly.',
  stakes: { slip: 2, slipMax: 6, failHealth: -6, failEnergy: -4, assistTeam: 5, assistScore: 6, assistEnergy: 3, leftTeam: -6, leftScore: -6 },
});

export const SUMMIT_NIGHT = climb({
  id: 'summit-night',
  title: 'the summit night',
  gate: 'camp4',
  mark: 'summit',
  mate: 'Jun',
  topOut: 'You reach Stella Point as the sky goes pale, then walk the rim to Uhuru',
  backOff: 'You turn the headlamps around on the scree and the party is back at Barafu before dawn.',
  fail: 'The cold and the scree win tonight. The party comes down to Barafu in the dark.',
  stakes: { slip: 3, slipMax: 9, failHealth: -10, failEnergy: -6, assistTeam: 6, assistScore: 8, assistEnergy: 4, leftTeam: -10, leftScore: -8 },
});

export const KILI_CHALLENGES: readonly ChallengeDefinition[] = [LAVA_TOWER, BARRANCO_WALL, SUMMIT_NIGHT];

export const kilimanjaroHybrid: HybridExpedition = { def: kilimanjaro, challenges: KILI_CHALLENGES };
