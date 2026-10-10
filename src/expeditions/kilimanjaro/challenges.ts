import type { HybridExpedition } from '@/game/hybrid/coordinator';
import type { ChallengeDefinition, OutcomeModifier } from '@/game/hybrid/types';

import { kilimanjaro } from './index';

/**
 * The Barranco Wall, played. The card choice "Climb the wall" still carries
 * the day: the height, the hours, the score for keeping it short. How the
 * wall was climbed shades that by a bounded amount. Game fiction, not a
 * description of the real scramble.
 */
export const BARRANCO_WALL: ChallengeDefinition = {
  id: 'barranco-wall',
  title: 'The Barranco Wall',
  eventId: 'kili-wall',
  choiceLabel: 'Climb the wall and camp at Karanga',
  modifier(outcome): OutcomeModifier {
    if (outcome.result === 'retreat') {
      // Backing off costs the day, like resting beneath the wall, and is never
      // better than resting: choosing the wall and walking away is not a shortcut.
      return {
        note: 'You back off the wall and the party walks down to the Barranco tents again.',
        move: 'hold',
        hours: 12,
        keepBaseScores: false,
        // The card spent 8 energy on the whole wall; half a wall costs half.
        // It gained 4 acclimatization for height you did not reach.
        stats: { energy: 4, acclimatization: -4, teamCondition: -2 },
        scores: {
          judgment: {
            label: 'You backed off the wall while it was still your choice',
            delta: 3,
            mark: 'wall-backoff',
          },
        },
      };
    }
    if (outcome.result === 'fail') {
      return {
        note: 'The wall takes more than the party has. You climb down to Barranco, slowly.',
        move: 'hold',
        hours: 12,
        keepBaseScores: false,
        stats: { health: -6, energy: -4, acclimatization: -4, teamCondition: -4 },
        scores: {
          riskManagement: { label: 'The wall took more than the team had', delta: -6, mark: 'wall-fail' },
        },
      };
    }
    const stats: OutcomeModifier['stats'] = {};
    const bits = ['You top out on the wall'];
    const scores: OutcomeModifier['scores'] = {};
    if (outcome.slips > 0) {
      stats.health = -Math.min(6, outcome.slips * 2);
      bits.push(outcome.slips === 1 ? 'after one slip' : `after ${outcome.slips} slips`);
    }
    if (outcome.staminaLeft < 25) {
      stats.energy = -4;
      bits.push('with nothing left in your arms');
    }
    if (outcome.assisted === true) {
      stats.teamCondition = 3;
      scores.teamwork = { label: 'You stopped for Marco on the wall', delta: 4, mark: 'wall-assist' };
      bits.push('and Marco comes up beside you');
    } else if (outcome.assisted === false) {
      stats.teamCondition = -4;
      scores.teamwork = { label: 'You left Marco on the wall for Lena', delta: -4, mark: 'wall-left' };
      bits.push('and Lena brings Marco up later');
    }
    if (outcome.regrouped) {
      stats.energy = (stats.energy ?? 0) + 2;
      scores.judgment = { label: 'You regrouped halfway up the wall', delta: 3, mark: 'wall-regroup' };
    }
    return {
      note: `${bits.join(' ')}. Karanga is pitched as the light goes.`,
      stats,
      hours: outcome.regrouped ? 1 : 0,
      keepBaseScores: true,
      scores,
    };
  },
};

export const KILI_CHALLENGES: readonly ChallengeDefinition[] = [BARRANCO_WALL];

export const kilimanjaroHybrid: HybridExpedition = { def: kilimanjaro, challenges: KILI_CHALLENGES };
