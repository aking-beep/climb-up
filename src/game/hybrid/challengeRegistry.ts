export type ChallengeSpec = {
  challengeId: string;
  eventId: string;
  choiceLabel: string;
};

/** Playable scenes keyed to an existing expedition choice. */
export const CHALLENGES: readonly ChallengeSpec[] = [
  {
    challengeId: 'barranco-wall',
    eventId: 'kili-wall',
    choiceLabel: 'Climb the wall and camp at Karanga',
  },
];

export function challengeFor(eventId: string, choiceLabel: string): ChallengeSpec | null {
  return CHALLENGES.find((spec) => spec.eventId === eventId && spec.choiceLabel === choiceLabel) ?? null;
}
