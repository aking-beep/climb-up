export type ChallengeResult = 'completed' | 'retreated' | 'failed';

/** A climb that has been entered and not yet written into the expedition. */
export type PendingChallenge = {
  attemptId: string;
  challengeId: string;
  eventId: string;
  choiceIndex: number;
};

/**
 * What the playable scene reports. The expedition engine applies this once.
 * Nothing here is a per-frame stat change.
 */
export type ChallengeOutcome = {
  attemptId: string;
  challengeId: string;
  eventId: string;
  choiceIndex: number;
  result: ChallengeResult;
  elapsedSeconds: number;
  staminaSpent: number;
  falls: number;
  hazardsEncountered: string[];
};
