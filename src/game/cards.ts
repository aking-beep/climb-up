import {
  BANDS,
  type Card,
  type Choice,
  type GameState,
  hash,
  turnJudgment,
} from '@/game/world';

function here(state: GameState) {
  return BANDS[state.band];
}

const PLACE: Record<string, { upTitle: string; up: string; downTitle: string; down: string }> = {
  road: {
    upTitle: 'The truck is still warm',
    up: 'Kharung is a number on a permit and a shape in the haze. Lena coils a rope she already coiled. Jun counts tablets. Marco looks at the summit as if it had agreed to something.',
    downTitle: 'Engines and dust',
    down: 'The road smells like hot metal. If you are here on the way down, the climb is over.',
  },
  valley: {
    upTitle: 'The valley does the first work',
    up: 'The river is loud and the trail is not. Base camp is a rumor of tents above the moraine. Nobody is tired yet. That will not last, and it is not a virtue.',
    downTitle: 'The valley, going out',
    down: 'The air is thicker than it was this morning, or whenever you were last this low. The river is the same river. You are not the same rope team.',
  },
  base: {
    upTitle: 'Base camp has opinions',
    up: 'Stoves, a radio, and a view that makes people say things they have not earned. Jun watches faces more than the peak. Lena has a time in mind. Marco has a picture in mind.',
    downTitle: 'Base camp, from above',
    down: 'The tents are still a promise. Getting to them is the job. Talking about the summit can wait until the kettle boils.',
  },
  abc: {
    upTitle: 'Advanced camp is not a victory',
    up: 'The icefall is a white argument above the cook tent. Sleep is thin. Food is starting to be a plan instead of a habit. The next steps are the ones people regret in good weather.',
    downTitle: 'Down through advanced camp',
    down: 'You know this tent. That is the danger. Familiar ground makes people hurry, and the mountain has not agreed to be familiar.',
  },
  ice: {
    upTitle: 'The icefall is awake',
    up: 'It ticks. Lena wants the dawn crossing, when the cold is still holding the blocks in place. Every hour of sun is a vote for something falling.',
    downTitle: 'Back through the ice',
    down: 'The way you came up is the way down, except the bridges have opinions about being used twice. Rope is a resource. So is patience.',
  },
  high: {
    upTitle: 'High camp, and the top is a rumor again',
    up: 'The ridge looks close enough to touch and far enough to kill a schedule. Water is snow. Warmth is a decision you keep making. Marco has started talking about the summit in the present tense.',
    downTitle: 'Leaving high camp',
    down: 'Down is a long verb from here. The people who can still walk have to be the plan. The view is not.',
  },
  ridge: {
    upTitle: 'The ridge does not have a railing',
    up: 'Eighty meters is a small number that has ended expeditions. The cornice is a white lip over nothing. If the turnaround is going to mean something, it means it here.',
    downTitle: 'The ridge, in reverse',
    down: 'You face the mountain on the way down. That is not poetry. It is how you see your feet, and your feet are the expedition now.',
  },
  summit: {
    upTitle: 'A small place',
    up: 'There is room for four people and a fact. The fact is that the summit is not the bottom of the mountain. The light is already spending itself.',
    downTitle: 'Leaving the top',
    down: 'The summit is behind you. It does not care. The rope does.',
  },
};

export function planCard(state: GameState): Card {
  const place = here(state);
  const above = BANDS[state.band + 1];
  const below = BANDS[state.band - 1];
  const copy = PLACE[place.id];
  const stormy = state.weather === 'storm' || state.forecast === 'storm';
  const choices: Choice[] = [];

  if (state.descending && below) {
    choices.push({
      label: `Continue down toward ${below.name}`,
      detail: state.weather === 'storm' ? 'Downhill, in weather that is not helping.' : 'The right direction, if you keep the pace honest.',
      tone: state.weather === 'storm' ? 'bold' : 'cautious',
      move: 'down',
      apply: () => ({
        note: `You leave ${place.name} on the way to ${below.name}.`,
        move: 'down',
        daylight: -5,
        food: -2,
        warmth: state.weather === 'storm' ? -12 : state.weather === 'whiteout' ? -6 : -3,
      }),
    });
  }

  if (!state.descending && above) {
    const ontoSummit = state.band + 1 === BANDS.length - 1;
    choices.push({
      label: ontoSummit ? 'Go for the summit' : `Move up toward ${above.name}`,
      detail: stormy
        ? 'The weather is already arguing with you.'
        : `${above.meters.toLocaleString('en-US')} m. The day will be spent getting there.`,
      tone: stormy ? 'reckless' : 'bold',
      move: ontoSummit ? 'summit' : 'up',
      apply: () => ({
        note: ontoSummit
          ? `You leave ${place.name} for the top.`
          : `You leave ${place.name} and walk toward ${above.name}.`,
        move: ontoSummit ? 'summit' : 'up',
        daylight: -5,
        food: -2,
        warmth: state.weather === 'storm' ? -14 : state.weather === 'whiteout' ? -8 : -4,
        strainAll: state.weather === 'storm' ? 1 : 0,
      }),
    });
  }

  choices.push({
    label: state.descending ? 'Hold and put the party back together' : 'Hold the day and let people recover',
    detail: 'Food and daylight, spent on lungs and warmth.',
    tone: 'cautious',
    move: 'hold',
    apply: () => ({
      note: state.descending
        ? `You stay at ${place.name} long enough to put hands back on the rope.`
        : `You spend the day at ${place.name}. Nobody gets higher. Everybody breathes.`,
      move: 'hold',
      daylight: -6,
      food: -4,
      warmth: 7,
      acclimatization: state.descending ? 0 : 14,
      relieve: 1,
    }),
  });

  if (!state.descending && state.band > 0) {
    choices.push({
      label: 'Turn around and start down',
      detail: 'The summit stays where it is. The road does not.',
      tone: stormy ? 'cautious' : 'bold',
      move: 'turn',
      apply: (current) => ({
        note: `You turn the party around at ${place.name}. The rest of the route can wait forever.`,
        move: 'turn',
        daylight: -4,
        food: -2,
        judgment: turnJudgment(current),
      }),
    });
  }

  return {
    id: `plan-${state.day}-${state.band}-${state.descending ? 'd' : 'u'}`,
    title: state.descending ? copy.downTitle : copy.upTitle,
    text: state.descending ? copy.down : copy.up,
    choices,
    ephemeral: true,
  };
}

export function stormCard(state: GameState): Card {
  const place = here(state);
  const choices: Choice[] = [
    {
      label: 'Dig in and let it pass',
      detail: 'A hole, a stove, and no heroics. The mountain can have the afternoon.',
      tone: 'cautious',
      move: 'hold',
      apply: () => ({
        note: `You dig in at ${place.name}. The storm spends itself on the tent wall instead of on you.`,
        move: 'hold',
        daylight: -6,
        food: -4,
        warmth: -6,
        dugIn: true,
        judgment: {
          label: 'You let the storm have the mountain',
          delta: 280,
          mark: 'dug-storm',
        },
      }),
    },
  ];

  if (!state.descending && state.band > 0) {
    choices.push({
      label: 'Turn around in it',
      detail: 'Down is right. Down right now is expensive.',
      tone: 'bold',
      move: 'turn',
      apply: (current) => ({
        note: 'You turn the party around while the snow is still arriving sideways.',
        move: 'turn',
        daylight: -5,
        warmth: -14,
        strainAll: 1,
        judgment: turnJudgment(current),
      }),
    });
  }

  if (state.descending && state.band > 0) {
    choices.push({
      label: 'Walk down through it',
      detail: 'You will not see the crevasses until they introduce themselves.',
      tone: 'bold',
      move: 'down',
      apply: () => ({
        note: 'You move because staying felt worse. The storm edits the route as you walk.',
        move: 'down',
        daylight: -5,
        warmth: -14,
        strainAll: 1,
      }),
    });
  }

  if (!state.descending && state.band < BANDS.length - 1) {
    choices.push({
      label: 'Race it toward the top',
      detail: 'Marco says the summit is a window. Windows close on people.',
      tone: 'reckless',
      move: state.band >= BANDS.length - 2 ? 'summit' : 'up',
      apply: () => ({
        note: 'You go up because the schedule said so. The wind takes the argument personally.',
        move: state.band >= BANDS.length - 2 ? 'summit' : 'up',
        daylight: -5,
        warmth: -18,
        morale: -6,
        strainAll: 2,
        judgment: {
          label: 'You spent people against a storm',
          delta: -420,
          mark: 'raced-storm',
        },
      }),
    });
  }

  return {
    id: 'storm-day',
    title: 'The mountain closes',
    text: `Wind at ${place.name} has a weight. Spindrift fills a glove in a minute. Lena does not look at the summit. She looks at the anchors, and then at you, and waits for the decision you already know.`,
    choices,
    urgent: true,
    repeat: 'day',
    weather: ['storm'],
  };
}

export const CARDS: Card[] = [
  {
    id: 'valley-path',
    bands: ['road', 'valley'],
    phase: 'up',
    weight: 3,
    title: 'Two ways through the valley',
    text: 'The moraine path is longer and stays out of the water. The river flats are direct, and the river is not interested in your boots. Base camp does not move closer out of sympathy.',
    choices: [
      {
        label: 'Take the sheltered moraine',
        detail: 'Slower. Drier. The afternoon gets used up.',
        tone: 'cautious',
        move: 'up',
        apply: () => ({
          note: 'You take the long dry path. Boots stay boots. The day gets shorter.',
          move: 'up',
          daylight: -6,
          food: -2,
          warmth: 2,
        }),
      },
      {
        label: 'Cross the flats and keep moving',
        detail: 'Faster, and someone will be wet for hours.',
        tone: 'bold',
        move: 'up',
        apply: () => ({
          note: 'The flats are quick. Marco laughs until the water finds his socks.',
          move: 'up',
          daylight: -4,
          food: -2,
          warmth: -4,
          strain: { marco: 1 },
        }),
      },
      {
        label: 'Push past dark to gain the camp',
        detail: 'The headlamps come out. So do the mistakes.',
        tone: 'reckless',
        move: 'up',
        apply: () => ({
          note: 'You walk after the light is gone. The trail is a guess with rocks in it.',
          move: 'up',
          daylight: -8,
          warmth: -8,
          strainAll: 1,
          judgment: { label: 'You spent the dark on an approach', delta: -120, mark: 'night-approach' },
        }),
      },
    ],
  },
  {
    id: 'photo-hour',
    bands: ['road', 'valley'],
    phase: 'up',
    weight: 1,
    title: 'Marco wants the overlook',
    text: 'There is a spur of rock with the whole route behind it. Marco already has the camera out, as if the expedition were a thing that had happened. Lena looks at the sky, not the lens.',
    choices: [
      {
        label: 'Keep to the route',
        detail: 'The picture can be taken from the trail.',
        tone: 'cautious',
        move: 'up',
        apply: () => ({
          note: 'You stay on the path. Marco takes one frame without stopping the rope.',
          move: 'up',
          daylight: -4,
          food: -1,
          morale: -2,
        }),
      },
      {
        label: 'Give him twenty minutes',
        detail: 'A small gift. The day notices.',
        tone: 'bold',
        move: 'up',
        apply: () => ({
          note: 'Twenty minutes becomes thirty. The picture is good. The schedule is worse.',
          move: 'up',
          daylight: -6,
          morale: 6,
          food: -2,
        }),
      },
      {
        label: 'Detour until the light is right',
        detail: 'The overlook is not on the climb.',
        tone: 'reckless',
        move: 'hold',
        apply: () => ({
          note: 'You chase the light off the route. Camp is still where you left the idea of it.',
          move: 'hold',
          daylight: -7,
          food: -3,
          morale: 8,
          judgment: { label: 'You spent a day on a photograph', delta: -80, mark: 'photo-day' },
        }),
      },
    ],
  },
  {
    id: 'cache-food',
    bands: ['valley', 'base'],
    phase: 'up',
    weight: 2,
    title: 'What you carry is what you eat later',
    text: 'Lena marks a boulder with a cairn the size of a decision. A cache here feeds the walk out. It also means the pack on your back is a lie about how much food you have.',
    choices: [
      {
        label: 'Bury a cache for the way down',
        detail: 'You go up lighter, and poorer, on purpose.',
        tone: 'cautious',
        move: 'hold',
        apply: () => ({
          note: 'You bury food where the way down will need it. The pack gets honest.',
          move: 'hold',
          daylight: -4,
          food: -8,
          mark: 'cache',
          judgment: {
            label: 'You left something for the walk out',
            delta: 220,
            mark: 'cached-food',
          },
        }),
      },
      {
        label: 'Carry all of it',
        detail: 'Heavier now. Simpler, until it is not.',
        tone: 'bold',
        move: 'up',
        apply: () => ({
          note: 'You carry every meal. The logic is clean and the shoulders disagree.',
          move: 'up',
          daylight: -5,
          food: -1,
          strain: { jun: 1 },
        }),
      },
      {
        label: 'Cook a celebration meal',
        detail: 'Morale now. Rations later, which is where you die.',
        tone: 'reckless',
        move: 'hold',
        apply: () => ({
          note: 'Dinner is generous. Breakfast is already nervous.',
          move: 'hold',
          daylight: -4,
          food: -12,
          morale: 10,
          judgment: { label: 'You ate the descent', delta: -160, mark: 'feast' },
        }),
      },
    ],
  },
  {
    id: 'river-morning',
    bands: ['valley'],
    phase: 'up',
    weight: 2,
    title: 'The river is lower when it is cold',
    text: 'At dawn the crossing is a inconvenience. By noon it is a swim with rocks in it. Jun is already calculating what wet clothes do to a night at this height.',
    choices: [
      {
        label: 'Wait for dawn and cross then',
        detail: 'You lose the evening. You keep your warmth.',
        tone: 'cautious',
        move: 'up',
        apply: () => ({
          note: 'You wait for the cold, then cross. The river is an inconvenience instead of a swim.',
          move: 'up',
          daylight: -6,
          warmth: 2,
          food: -2,
        }),
      },
      {
        label: 'Wade it now, carefully',
        detail: 'Unpleasant. Done before the heat.',
        tone: 'bold',
        move: 'up',
        apply: () => ({
          note: 'You cross while you can still feel your ankles. Just.',
          move: 'up',
          daylight: -4,
          warmth: -6,
          strain: { jun: 1 },
        }),
      },
      {
        label: 'Rope up and force a line',
        detail: 'Faster if nobody gets swept. That is the whole risk.',
        tone: 'reckless',
        move: 'up',
        apply: (state) => {
          const swept = hash(state.seed, state.day, 9) % 4 === 0;
          return {
            note: swept
              ? 'The current takes Marco off his feet. The rope holds. The afternoon does not.'
              : 'You force the line. It works, and it should not be a habit.',
            move: 'up',
            daylight: -3,
            warmth: -8,
            rope: -6,
            strain: swept ? { marco: 3 } : { marco: 1 },
          };
        },
      },
    ],
  },
  {
    id: 'lungs-day',
    bands: ['base', 'abc'],
    phase: 'up',
    weight: 4,
    when: (state) => state.acclimatization < 48,
    title: 'Jun says the air is ahead of you',
    text: 'Someone’s headache has a pulse. Jun names it without drama: you are climbing faster than your blood. A rest day here is invisible from the valley. It is not invisible on the ridge.',
    choices: [
      {
        label: 'Rest the day and let lungs catch up',
        detail: 'No height. Real acclimatization.',
        tone: 'cautious',
        move: 'hold',
        apply: () => ({
          note: 'You rest. The summit does not move. Your blood does, slowly, in the right direction.',
          move: 'hold',
          daylight: -6,
          food: -4,
          warmth: 4,
          acclimatization: 16,
          relieve: 1,
          judgment: {
            label: 'You spent a day getting used to the air',
            delta: 300,
            mark: 'rested-lungs',
          },
        }),
      },
      {
        label: 'Go up, but shorten the day',
        detail: 'Some height. Not a race.',
        tone: 'bold',
        move: 'up',
        apply: () => ({
          note: 'You move up and stop early. Jun allows it without pretending to like it.',
          move: 'up',
          daylight: -5,
          food: -2,
          acclimatization: 4,
        }),
      },
      {
        label: 'The schedule does not move',
        detail: 'Headaches are what medicine is for. Jun disagrees.',
        tone: 'reckless',
        move: 'up',
        apply: () => ({
          note: 'You climb anyway. The headache climbs with you, and it is a better athlete.',
          move: 'up',
          daylight: -5,
          food: -2,
          acclimatization: -4,
          strainAll: 2,
          judgment: { label: 'You ignored the air', delta: -250, mark: 'ignored-air' },
        }),
      },
    ],
  },
  {
    id: 'radio',
    bands: ['base'],
    phase: 'up',
    weight: 2,
    when: (state) => state.day <= 6,
    title: 'The radio has a front on it',
    text: 'A voice from somewhere with a roof reads you the next change in the weather. Lena writes it down. Marco says forecasts are a kind of pessimism. The sky, so far, has no opinion.',
    choices: [
      {
        label: 'Rewrite the plan around the front',
        detail: 'Believe the voice. Spend today getting ready.',
        tone: 'cautious',
        move: 'hold',
        apply: () => ({
          note: 'You treat the forecast as a fact. Ropes get sorted. Egos get less time.',
          move: 'hold',
          daylight: -5,
          food: -3,
          warmth: 3,
          acclimatization: 8,
          judgment: { label: 'You believed the forecast while it was still cheap', delta: 180, mark: 'heeded-radio' },
        }),
      },
      {
        label: 'Move camp before it arrives',
        detail: 'Use the good day. Do not pretend there will be two.',
        tone: 'bold',
        move: 'up',
        apply: () => ({
          note: 'You move while the sky is still willing. The radio stays in the pack.',
          move: 'up',
          daylight: -5,
          food: -2,
        }),
      },
      {
        label: 'Ignore it',
        detail: 'Forecasts do not carry loads. You do.',
        tone: 'reckless',
        move: 'up',
        apply: () => ({
          note: 'You call the forecast theater and walk up into the part where it is not.',
          move: 'up',
          daylight: -4,
          strainAll: 1,
          judgment: { label: 'You treated the forecast as a mood', delta: -180, mark: 'ignored-radio' },
        }),
      },
    ],
  },
  {
    id: 'kitchen',
    bands: ['base', 'abc'],
    weight: 1,
    title: 'The pot is smaller than the argument',
    text: 'Dinner is a measured thing. Marco wants a full bowl. Jun wants the same measure tomorrow, and the day after, on the way down. Morale and rations are the same argument wearing two coats.',
    choices: [
      {
        label: 'Even shares, including tomorrow',
        detail: 'Nobody is full. Nobody is robbed.',
        tone: 'cautious',
        move: 'hold',
        apply: () => ({
          note: 'You measure the pot like a promise. It is not a feast. It is a plan.',
          move: 'hold',
          daylight: -4,
          food: -2,
          morale: 2,
          judgment: { label: 'You kept the rations honest', delta: 80, mark: 'even-pot' },
        }),
      },
      {
        label: 'A little extra for the tired one',
        detail: 'Someone else eats less. Say so out loud.',
        tone: 'bold',
        move: 'hold',
        apply: (state) => {
          const weakest = [...state.party]
            .filter((person) => person.strain < 7)
            .sort((a, b) => b.strain - a.strain)[0];
          return {
            note: `You give the extra to ${weakest.id === 'you' ? 'yourself' : weakest.name}, and you say it out loud.`,
            move: 'hold',
            daylight: -4,
            food: -3,
            strain: { [weakest.id]: -1 },
            morale: 3,
          };
        },
      },
      {
        label: 'The leader eats a full portion',
        detail: 'You will need it. They will notice.',
        tone: 'reckless',
        move: 'hold',
        apply: () => ({
          note: 'You eat. The tent gets quiet in a way that is not rest.',
          move: 'hold',
          daylight: -3,
          food: -4,
          strain: { you: -1, marco: 1, jun: 1 },
          morale: -12,
          judgment: { label: 'You ate first', delta: -200, mark: 'ate-first' },
        }),
      },
    ],
  },
  {
    id: 'icefall',
    bands: ['ice'],
    phase: 'up',
    weight: 4,
    title: 'Cross before the sun does',
    text: 'The icefall is a stack of decisions that can fall on you. Lena wants the dark, the cold, and a rope that is longer than anyone’s pride. By midmorning the seracs start answering questions nobody asked.',
    choices: [
      {
        label: 'Leave in the cold and cross roped',
        detail: 'Miserable. This is the safe version.',
        tone: 'cautious',
        move: 'up',
        apply: () => ({
          note: 'You cross while the ice is still holding its breath. It costs the morning and saves the rest.',
          move: 'up',
          daylight: -6,
          warmth: -8,
          rope: -8,
          food: -2,
          judgment: { label: 'You crossed the icefall while it was quiet', delta: 160, mark: 'quiet-ice' },
        }),
      },
      {
        label: 'Wait for warmth and visibility',
        detail: 'Kinder on hands. The icefall gets louder.',
        tone: 'bold',
        move: 'hold',
        apply: (state) => {
          const hit = hash(state.seed, state.day, 17) % 3 === 0;
          return {
            note: hit
              ? 'You wait for the sun. A serac answers anyway. Marco is in the rope, then under the ice.'
              : 'You wait. The icefall only ticks. Today, ticking is enough.',
            move: 'hold',
            daylight: -5,
            warmth: 4,
            strain: hit ? { marco: 3 } : {},
          };
        },
      },
      {
        label: 'Sprint the middle unroped',
        detail: 'Speed is not a strategy. It is a wish.',
        tone: 'reckless',
        move: 'up',
        apply: () => ({
          note: 'You run the throat of the icefall. The rope stays in the pack, which is a choice you will have to live beside.',
          move: 'up',
          daylight: -3,
          warmth: -4,
          strainAll: 2,
          judgment: { label: 'You unroped in the icefall', delta: -280, mark: 'unroped' },
        }),
      },
    ],
  },
  {
    id: 'rope-team',
    bands: ['ice'],
    phase: 'up',
    weight: 2,
    title: 'How long is the rope',
    text: 'A long rope is slow and catches a fall. A short rope is a conversation you are having too closely. Lena holds the coil and waits, which is her way of refusing to decide it for you.',
    choices: [
      {
        label: 'Long rope, slow pace',
        detail: 'The day shrinks. The falls get smaller.',
        tone: 'cautious',
        move: 'up',
        apply: () => ({
          note: 'You lengthen the rope and shorten the ambition of each step.',
          move: 'up',
          daylight: -6,
          rope: -4,
          food: -2,
        }),
      },
      {
        label: 'A standard interval',
        detail: 'The ordinary risk, taken ordinarily.',
        tone: 'bold',
        move: 'up',
        apply: () => ({
          note: 'You move as a normal rope team. The ice accepts it, for now.',
          move: 'up',
          daylight: -4,
          rope: -6,
          food: -2,
        }),
      },
      {
        label: 'Short rope, and move',
        detail: 'If one person goes, the next person is already going.',
        tone: 'reckless',
        move: 'up',
        apply: () => ({
          note: 'The rope is a suggestion. A foot goes through a lid of snow and the suggestion becomes a fact.',
          move: 'up',
          daylight: -3,
          strainAll: 1,
          strain: { lena: 2 },
        }),
      },
    ],
  },
  {
    id: 'stove',
    bands: ['abc', 'high'],
    weight: 2,
    title: 'The stove coughs',
    text: 'Meltwater is the day’s real work. The stove lights, dies, lights. Jun’s hands are already clumsy. Without water, altitude becomes a faster problem than the route.',
    choices: [
      {
        label: 'Spend the afternoon fixing it',
        detail: 'No progress. Water tonight.',
        tone: 'cautious',
        move: 'hold',
        apply: () => ({
          note: 'You take the stove apart in the tent. It works. So does the evening, and nothing else.',
          move: 'hold',
          daylight: -6,
          warmth: 10,
          food: -2,
          relieve: 1,
        }),
      },
      {
        label: 'Nurse a flame and keep the plan',
        detail: 'Less water. The route still happens.',
        tone: 'bold',
        move: 'continue',
        apply: () => ({
          note: 'You melt what you can and move. Thirst comes along as a member of the party.',
          move: 'continue',
          daylight: -5,
          warmth: -6,
          food: -2,
          strain: { jun: 1 },
        }),
      },
      {
        label: 'Skip water and keep the hour',
        detail: 'The schedule stays. The headache will not.',
        tone: 'reckless',
        move: 'continue',
        apply: () => ({
          note: 'You leave the stove for later. Later arrives as a headache with your name on it.',
          move: 'continue',
          daylight: -3,
          warmth: -10,
          strainAll: 1,
        }),
      },
    ],
  },
  {
    id: 'wind-slab',
    bands: ['high'],
    phase: 'up',
    weather: ['clear', 'rising'],
    weight: 3,
    title: 'The snow has a dull sound',
    text: 'Lena stops the rope with a flat hand. The slope under the ridge sounds wrong, the dull sound of snow that is not attached to the mountain. Marco has already unclipped one sling. The clouds are not here yet. They are scheduled.',
    choices: [
      {
        label: 'Go around and lose the afternoon',
        detail: 'No crossing. The day becomes a rest whether you like it or not.',
        tone: 'cautious',
        move: 'hold',
        apply: () => ({
          note: 'You refuse the slope. High camp stays high camp. Everyone is still clipped in.',
          move: 'hold',
          daylight: -5,
          food: -2,
          warmth: 2,
          judgment: { label: 'You walked away from a loaded slope', delta: 240, mark: 'refused-slab' },
        }),
      },
      {
        label: 'Belay across, one at a time',
        detail: 'Slow enough to be a decision, not a rush.',
        tone: 'bold',
        move: 'up',
        apply: () => ({
          note: 'One at a time, the rope does its job. The slope never gets the chance to do its job.',
          move: 'up',
          daylight: -6,
          rope: -10,
          food: -2,
          warmth: -4,
        }),
      },
      {
        label: 'It will hold if you are light and fast',
        detail: 'Three steps. Or one story.',
        tone: 'reckless',
        move: 'up',
        apply: (state) => {
          const breaks = state.weather === 'rising' || hash(state.seed, state.day, 4) % 2 === 0;
          return {
            note: breaks
              ? 'The slab answers. The rope team becomes a single mistake with four names.'
              : 'It holds. You will be tempted to believe that means it was safe.',
            move: 'up',
            daylight: -3,
            warmth: breaks ? -12 : -4,
            strainAll: breaks ? 2 : 0,
            judgment: breaks
              ? { label: 'You bet the rope on a dull sound', delta: -320, mark: 'bet-slab' }
              : undefined,
          };
        },
      },
    ],
  },
  {
    id: 'fever',
    bands: ['high', 'ridge'],
    phase: 'up',
    weight: 3,
    title: 'Marco says the word summit',
    text: 'He says it like a destination and not a ridge that still has to be reversed. Lena names a turnaround time and does not raise her voice. Jun is repacking a medical kit that has started to look like a prediction.',
    choices: [
      {
        label: 'The turnaround time stands',
        detail: 'If you are past it, you are already deciding.',
        tone: 'cautious',
        move: 'turn',
        apply: (state) => ({
          note: 'You keep the time Lena named. The summit remains a place you did not visit.',
          move: 'turn',
          daylight: -4,
          food: -2,
          morale: -4,
          judgment: turnJudgment(state),
        }),
      },
      {
        label: 'Look at the ridge, then decide',
        detail: 'Information, if you can still use it when you get there.',
        tone: 'bold',
        move: 'up',
        apply: () => ({
          note: 'You go up to see. Seeing is not the same as leaving.',
          move: 'up',
          daylight: -4,
          food: -2,
          warmth: -4,
        }),
      },
      {
        label: 'Tell them the summit is the point',
        detail: 'They will follow. That is the problem.',
        tone: 'reckless',
        move: 'up',
        apply: () => ({
          note: 'You say the quiet part. The rope moves because you said so, not because the mountain agreed.',
          move: 'up',
          daylight: -4,
          morale: 4,
          strain: { jun: 1 },
          judgment: { label: 'You told them the summit was the point', delta: -300, mark: 'summit-point' },
        }),
      },
    ],
  },
  {
    id: 'cornice',
    bands: ['ridge'],
    weight: 2,
    title: 'The cornice is a rumor with an edge',
    text: 'The bootpack wanders toward the white lip. Lena pulls the rope back onto the rock without a speech. The drop on the far side is not visible, which is why people step on it.',
    choices: [
      {
        label: 'Stay back on the rock',
        detail: 'Slower feet. A real edge.',
        tone: 'cautious',
        move: 'continue',
        apply: () => ({
          note: 'You keep the rope on the rock. The cornice gets to stay a rumor.',
          move: 'continue',
          daylight: -4,
          rope: -4,
          food: -1,
        }),
      },
      {
        label: 'Follow the bootpack on the crest',
        detail: 'Someone else thought this was fine.',
        tone: 'bold',
        move: 'continue',
        apply: () => ({
          note: 'The crest holds the old steps. You add yours, and you do not look at the lip.',
          move: 'continue',
          daylight: -3,
          warmth: -4,
        }),
      },
      {
        label: 'Cut the corner on the snow',
        detail: 'Shorter. The shorter path is over air.',
        tone: 'reckless',
        move: 'continue',
        apply: (state) => {
          const breaks = hash(state.seed, state.day, 21) % 3 !== 2;
          return {
            note: breaks
              ? 'The lip gives. You are in the rope and then you are a weight on it.'
              : 'The corner holds. Lena says nothing, which is worse than a lecture.',
            move: 'continue',
            daylight: -2,
            strain: breaks ? { you: 4, lena: 2 } : { you: 1 },
          };
        },
      },
    ],
  },
  {
    id: 'false-summit',
    bands: ['ridge'],
    phase: 'up',
    weather: ['clear', 'rising', 'whiteout'],
    weight: 4,
    when: (state) => !state.summited,
    title: 'Eighty meters',
    text: 'The top is close enough to count in minutes. It is also close enough to ruin the descent if you spend those minutes badly. The light is a finite thing. So are hands.',
    choices: [
      {
        label: 'Turn around eighty meters short',
        detail: 'The summit stays. The people come with you.',
        tone: 'cautious',
        move: 'turn',
        apply: () => ({
          note: 'You leave the last meters on the mountain. Nobody argues for long. The cold is a better speaker.',
          move: 'turn',
          daylight: -3,
          food: -1,
          morale: -3,
          judgment: {
            label: 'You left the last meters',
            delta: 420,
            mark: 'left-meters',
          },
        }),
      },
      {
        label: 'Tag the top and leave',
        detail: 'No photographs. No speeches. Touch it and turn.',
        tone: 'bold',
        move: 'summit',
        apply: () => ({
          note: 'You tag the top. It is a small place, and you are still standing in it.',
          move: 'summit',
          daylight: -4,
          warmth: -6,
          food: -2,
        }),
      },
      {
        label: 'Stay until it feels real',
        detail: 'Pictures, a long minute, a darker descent.',
        tone: 'reckless',
        move: 'summit',
        apply: () => ({
          note: 'You stay long enough for the top to feel real. The daylight starts leaving without you.',
          move: 'summit',
          daylight: -8,
          warmth: -14,
          morale: 6,
          food: -2,
          judgment: { label: 'You spent the summit', delta: -150, mark: 'stayed-top' },
        }),
      },
    ],
  },
  {
    id: 'fixed-line',
    bands: ['ice', 'high', 'ridge'],
    weight: 2,
    title: 'Someone else’s rope',
    text: 'An old fixed line runs the pitch, sun-bleached and confident. It would save your rope. Lena flicks it and listens to the sound, which is not the sound of something you should trust with a person.',
    choices: [
      {
        label: 'Use your own rope',
        detail: 'Slower, and the gear you trust is the gear you carried.',
        tone: 'cautious',
        move: 'continue',
        apply: () => ({
          note: 'You climb on your own rope. The old line stays a warning.',
          move: 'continue',
          daylight: -4,
          rope: -12,
          food: -1,
        }),
      },
      {
        label: 'Test it, then trust a section',
        detail: 'A compromise with a stranger’s knot.',
        tone: 'bold',
        move: 'continue',
        apply: (state) => {
          const fails = hash(state.seed, state.day, 11) % 5 === 0;
          return {
            note: fails
              ? 'The sheath opens under Lena’s weight. Your rope finishes the pitch. Hers almost does not.'
              : 'The old line holds for one pitch. You do not ask it for a second.',
            move: 'continue',
            daylight: -3,
            rope: -4,
            strain: fails ? { lena: 3 } : {},
          };
        },
      },
      {
        label: 'Clip it and move together',
        detail: 'The abandoned rope becomes the plan.',
        tone: 'reckless',
        move: 'continue',
        apply: () => ({
          note: 'You commit to a rope you did not place. It remembers someone else’s standard.',
          move: 'continue',
          daylight: -2,
          strainAll: 1,
          strain: { lena: 2 },
        }),
      },
    ],
  },
  {
    id: 'summit-stay',
    bands: ['summit'],
    phase: 'up',
    weight: 6,
    title: 'A small place',
    text: 'Four people can stand here, and then they should stop standing here. The descent is the rest of the mountain. Jun is already facing downhill. Marco is facing the view, which is not a direction.',
    choices: [
      {
        label: 'Leave now',
        detail: 'The summit happened. Do not negotiate with it.',
        tone: 'cautious',
        move: 'leave',
        apply: () => ({
          note: 'You turn your back on the top before anyone can make it a ceremony.',
          move: 'leave',
          daylight: -3,
          warmth: -4,
          food: -1,
          judgment: {
            label: 'You left the top while the day still existed',
            delta: 180,
            mark: 'left-summit',
          },
        }),
      },
      {
        label: 'One quiet minute',
        detail: 'Long enough to know you were here. Not longer.',
        tone: 'bold',
        move: 'leave',
        apply: () => ({
          note: 'You give it a minute. Then the rope faces the right way.',
          move: 'leave',
          daylight: -4,
          warmth: -6,
          morale: 4,
          food: -1,
        }),
      },
      {
        label: 'Stay until the pictures are done',
        detail: 'The light you are using is the light you needed for down.',
        tone: 'reckless',
        move: 'leave',
        apply: () => ({
          note: 'The pictures get taken. The descent begins in a color that means hurry.',
          move: 'leave',
          daylight: -7,
          warmth: -12,
          morale: 6,
          judgment: { label: 'You spent the summit', delta: -150, mark: 'stayed-summit' },
        }),
      },
    ],
  },
  {
    id: 'whiteout-walk',
    phase: 'any',
    weather: ['whiteout'],
    urgent: true,
    repeat: 'day',
    weight: 5,
    when: (state) => {
      const id = BANDS[state.band].id;
      return id !== 'road' && id !== 'summit';
    },
    title: 'The horizon leaves',
    text: 'White on white. The slope and the sky sign the same paper. A bearing is a story you tell with your feet. Stopping is also a story, and it has a colder ending if you wait too long.',
    choices: [
      {
        label: 'Stop until something has an edge',
        detail: 'You burn food and warmth. You do not walk off the map.',
        tone: 'cautious',
        move: 'hold',
        apply: () => ({
          note: 'You stop. The whiteout keeps its secrets. So do your ankles.',
          move: 'hold',
          daylight: -5,
          food: -3,
          warmth: -6,
          judgment: { label: 'You waited for a horizon', delta: 200, mark: 'waited-white' },
        }),
      },
      {
        label: 'Walk a bearing and count paces',
        detail: 'Slow, spoken out loud, one person navigating.',
        tone: 'bold',
        move: 'continue',
        apply: () => ({
          note: 'Lena counts. You repeat the count. The slope arrives in pieces, which is enough.',
          move: 'continue',
          daylight: -5,
          rope: -4,
          warmth: -6,
          food: -2,
        }),
      },
      {
        label: 'Move fast while you still feel downhill',
        detail: 'Downhill is a direction until it is a cliff.',
        tone: 'reckless',
        move: 'continue',
        apply: () => ({
          note: 'You hurry because the white makes waiting feel like dying. Hurry finds a drop the pace did not.',
          move: 'continue',
          daylight: -3,
          warmth: -8,
          strainAll: 2,
        }),
      },
    ],
  },
  {
    id: 'sits-down',
    repeat: 'day',
    weight: 3,
    when: (state) => state.party.some((person) => person.strain >= 3 && person.strain < 7),
    title: 'Someone sits down',
    text: 'It is the kind of sitting that is not a rest. The pack stays on. The eyes are working harder than the legs. If you walk away from this, you are choosing a smaller expedition.',
    choices: [
      {
        label: 'Stop the whole team and warm them',
        detail: 'The route waits. The person does not.',
        tone: 'cautious',
        move: 'hold',
        apply: (state) => {
          const worst = [...state.party]
            .filter((person) => person.strain < 7)
            .sort((a, b) => b.strain - a.strain)[0];
          const name = worst.id === 'you' ? 'You' : worst.name;
          return {
            note: `You stop the rope. ${name} gets the warm drink and the hour.`,
            move: 'hold',
            daylight: -5,
            food: -3,
            warmth: 8,
            strain: { [worst.id]: -2 },
            judgment: {
              label: 'You stopped for the person who was failing',
              delta: 240,
              mark: 'stopped-for',
            },
          };
        },
      },
      {
        label: 'Shorten the rope and keep a camp in reach',
        detail: 'Move, but only toward a place you can stop.',
        tone: 'bold',
        move: 'continue',
        apply: () => ({
          note: 'You keep moving, close together, toward the nearest place a person can lie down on purpose.',
          move: 'continue',
          daylight: -4,
          warmth: -4,
          food: -2,
          strain: { jun: 1 },
        }),
      },
      {
        label: 'Tell them camp is close',
        detail: 'It might be. That is not a reason.',
        tone: 'reckless',
        move: 'continue',
        apply: (state) => {
          const worst = [...state.party]
            .filter((person) => person.strain < 7)
            .sort((a, b) => b.strain - a.strain)[0];
          return {
            note: 'You say camp is close. The legs that needed that to be true do not improve.',
            move: 'continue',
            daylight: -3,
            morale: -6,
            strain: { [worst.id]: 2 },
          };
        },
      },
    ],
  },
  {
    id: 'rappel',
    bands: ['ice', 'high', 'ridge'],
    phase: 'down',
    weight: 3,
    title: 'The anchor is the whole pitch',
    text: 'Down is a series of trusts. The rock will take a sling. It will also take a hurry. Lena builds nothing until you say what kind of time you think you have. She already knows what kind you actually have.',
    choices: [
      {
        label: 'Build a real anchor',
        detail: 'Rope and minutes, spent on not falling.',
        tone: 'cautious',
        move: 'down',
        apply: () => ({
          note: 'The anchor is boring and correct. You go down one at a time, which is the point.',
          move: 'down',
          daylight: -5,
          rope: -12,
          food: -1,
          judgment: { label: 'You built the anchor the pitch deserved', delta: 120, mark: 'real-anchor' },
        }),
      },
      {
        label: 'Thread what is already there',
        detail: 'Faster. You inherit a stranger’s knot.',
        tone: 'bold',
        move: 'down',
        apply: (state) => {
          const fails = hash(state.seed, state.day, 13) % 6 === 0;
          return {
            note: fails
              ? 'The old sling is powder. Jun catches the fact in time. The next anchor is yours.'
              : 'The old piece holds. You do not thank it out loud.',
            move: 'down',
            daylight: -3,
            rope: -4,
            strain: fails ? { jun: 2 } : {},
          };
        },
      },
      {
        label: 'Downclimb it and save the gear',
        detail: 'The rope stays in the pack. So does the margin.',
        tone: 'reckless',
        move: 'down',
        apply: () => ({
          note: 'You downclimb to save a sling. The mountain charges interest.',
          move: 'down',
          daylight: -4,
          strainAll: 1,
          strain: { marco: 1 },
        }),
      },
    ],
  },
  {
    id: 'shares',
    repeat: 'day',
    weight: 2,
    when: (state) => state.food < 42 && state.party.some((person) => person.strain < 7),
    title: 'The food is a short sentence',
    text: 'There is enough for a careful day, or a generous hour. Jun lays the bars out like instruments. Nobody reaches first. They are waiting to see what kind of leader the shortage gets.',
    choices: [
      {
        label: 'Even shares',
        detail: 'The same hunger for everyone.',
        tone: 'cautious',
        move: 'hold',
        apply: () => ({
          note: 'You split it evenly. The hunger is fair, which is not the same as gone.',
          move: 'hold',
          daylight: -3,
          food: -4,
          morale: 4,
          judgment: { label: 'You kept the last food fair', delta: 100, mark: 'fair-food' },
        }),
      },
      {
        label: 'More to the weakest',
        detail: 'Say the name. Take the smaller share yourself.',
        tone: 'bold',
        move: 'hold',
        apply: (state) => {
          const weakest = [...state.party]
            .filter((person) => person.strain < 7)
            .sort((a, b) => b.strain - a.strain)[0];
          return {
            note: `The extra bar goes to ${weakest.id === 'you' ? 'you' : weakest.name}. The rest of you eat the decision.`,
            move: 'hold',
            daylight: -3,
            food: -5,
            strain: { [weakest.id]: -1, you: weakest.id === 'you' ? 0 : 1 },
            judgment: { label: 'You fed the person who was failing', delta: 160, mark: 'fed-weak' },
          };
        },
      },
      {
        label: 'Keep a full share for yourself',
        detail: 'A strong leader, and a worse team.',
        tone: 'reckless',
        move: 'hold',
        apply: () => ({
          note: 'You keep a full share. The tent learns the shape of that.',
          move: 'hold',
          daylight: -2,
          food: -6,
          strain: { you: -1, lena: 1, marco: 1, jun: 1 },
          morale: -14,
          judgment: { label: 'You kept the last food', delta: -220, mark: 'hoarded' },
        }),
      },
    ],
  },
  {
    id: 'headache',
    bands: ['abc', 'ice', 'high'],
    phase: 'up',
    weight: 3,
    when: (state) => state.acclimatization < 50,
    title: 'Your own headache',
    text: 'It sits behind the eyes and pretends to be fatigue. Jun recognizes it and does not soften the name. Going higher today is a bet that the headache is lying.',
    choices: [
      {
        label: 'Rest here until it fades',
        detail: 'A lost day. A leader who can still think tomorrow.',
        tone: 'cautious',
        move: 'hold',
        apply: () => ({
          note: 'You stop. The headache loosens its grip by evening, which is the evidence.',
          move: 'hold',
          daylight: -6,
          food: -3,
          acclimatization: 12,
          strain: { you: -1 },
          judgment: { label: 'You stopped for your own altitude', delta: 200, mark: 'own-headache' },
        }),
      },
      {
        label: 'Drop back to the last camp',
        detail: 'Height, given back on purpose.',
        tone: 'bold',
        move: 'back',
        apply: () => ({
          note: 'You give a camp back to the mountain. Breathing gets less theatrical.',
          move: 'back',
          daylight: -4,
          food: -2,
          acclimatization: 8,
          strain: { you: -1 },
        }),
      },
      {
        label: 'Take something and keep climbing',
        detail: 'The symptom goes quiet. The cause does not.',
        tone: 'reckless',
        move: 'up',
        apply: () => ({
          note: 'The pills turn the volume down. The altitude does not take requests.',
          move: 'up',
          daylight: -4,
          food: -2,
          strain: { you: 2 },
          judgment: { label: 'You medicated a reason to stop', delta: -180, mark: 'medicated' },
        }),
      },
    ],
  },
  {
    id: 'river-home',
    bands: ['valley'],
    phase: 'down',
    weight: 3,
    title: 'The river, on the way out',
    text: 'You have crossed it once, which the river does not remember. It is higher than it was, or you are tireder, which is the same problem with different boots.',
    choices: [
      {
        label: 'Wait for morning and cross cold',
        detail: 'One more night. A lower river.',
        tone: 'cautious',
        move: 'hold',
        apply: () => ({
          note: 'You wait out the melt. Dawn gives you a crossing instead of a swim.',
          move: 'down',
          daylight: -6,
          food: -3,
          warmth: -2,
        }),
      },
      {
        label: 'Wade it together',
        detail: 'Unpleasant, finished, wet.',
        tone: 'bold',
        move: 'down',
        apply: () => ({
          note: 'You cross as a cluster of elbows and rope. Everyone is wet. Everyone is across.',
          move: 'down',
          daylight: -4,
          warmth: -6,
          strain: { marco: 1 },
        }),
      },
      {
        label: 'Look for a log in the failing light',
        detail: 'A shortcut that ends in the water.',
        tone: 'reckless',
        move: 'down',
        apply: () => ({
          note: 'The log is a rumor. The water is not. You arrive on the far bank angrier and colder.',
          move: 'down',
          daylight: -5,
          warmth: -10,
          strainAll: 1,
        }),
      },
    ],
  },
];
