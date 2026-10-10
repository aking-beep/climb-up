export type ChallengeSpec = {
  challengeId: string;
  eventId: string;
  choiceId: string;
};

/** Playable scenes keyed by event id and choice id, not by the button label. */
export const CHALLENGES: readonly ChallengeSpec[] = [
  {
    challengeId: 'barranco-wall',
    eventId: 'kili-wall',
    choiceId: 'kili-wall-climb',
  },
];

export function challengeFor(eventId: string, choiceId: string | undefined): ChallengeSpec | null {
  if (!choiceId) return null;
  return CHALLENGES.find((spec) => spec.eventId === eventId && spec.choiceId === choiceId) ?? null;
}

export function challengeById(challengeId: string): ChallengeSpec | null {
  return CHALLENGES.find((spec) => spec.challengeId === challengeId) ?? null;
}
