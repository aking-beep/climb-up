import type { ExpeditionDefinition, ExpeditionState, ScoreBucket } from '@/game/types';

const BUCKETS: ScoreBucket[] = ['judgment', 'riskManagement', 'teamwork', 'preparation'];

export function createExpedition(seed: number, def: ExpeditionDefinition): ExpeditionState {
  const safeSeed = seed >>> 0 || 1;
  const start = def.route[0];
  const ledger = {} as ExpeditionState['ledger'];
  for (const bucket of BUCKETS) ledger[bucket] = [];

  return {
    seed: safeSeed,
    checkpoint: start.id,
    altitude: start.meters,
    highestAltitude: start.meters,
    health: 92,
    energy: 88,
    acclimatization: 18,
    oxygen: 72,
    supplies: 86,
    weatherRisk: 16,
    objectiveRisk: 10,
    teamCondition: 90,
    elapsedHours: 0,
    summitReached: false,
    retreating: false,
    returnedSafely: false,
    status: 'active',
    history: [],
    seen: [],
    marks: {},
    lastNote: '',
    ledger,
  };
}
