/**
 * Ten-day Lemosho scenes. Game fiction, not a route and not advice.
 * Cards flagged `review: 'sme'` need specialist review before any
 * wording is treated as accurate.
 */
import type { EventCard, LedgerNote } from '@/game/types';

const DAY = 24;

function turned(band: number): { judgment: LedgerNote; riskManagement: LedgerNote } {
  return {
    judgment: {
      label: 'You turned around while the way down still existed',
      delta: 12 + band,
      mark: 'turned',
    },
    riskManagement: {
      label: 'You left before the margin was gone',
      delta: 10,
      mark: 'turned-risk',
    },
  };
}

export const KILI_EVENTS: readonly EventCard[] = [
  {
    id: 'kili-gate',
    category: 'turnaround',
    checkpoints: ['briefing'],
    phase: 'up',
    urgent: true,
    title: 'Ten days, if you use them',
    text: 'Londorossi Gate. The forest starts here, and Uhuru is nine sleeps away if you spend the days on the body instead of the photograph. The team is waiting to hear what this expedition is for.',
    choices: [
      {
        label: 'Walk the forest and set camp',
        detail: 'A full day to Big Tree. Tents up before dark.',
        effect: {
          note: 'You walk the montane forest. At Mti Mkubwa the tents go up and the water goes on.',
          hours: DAY,
          move: 'up',
          energy: -4,
          supplies: -2,
          acclimatization: 2,
          scores: {
            judgment: { label: 'You gave the ten days their first night', delta: 6, mark: 'day1-pace' },
            preparation: { label: 'Camp was up before the forest went dark', delta: 4, mark: 'day1-camp' },
          },
        },
      },
      {
        label: 'Push the forest to gain a day',
        detail: 'Higher tonight. A thinner team in the morning.',
        effect: {
          note: 'You hurry the forest and pitch late at Big Tree.',
          hours: 16,
          move: 'up',
          energy: -10,
          teamCondition: -6,
          supplies: -2,
          scores: {
            judgment: { label: 'You spent the first day trying to save one', delta: -6, mark: 'day1-rush' },
          },
        },
      },
      {
        label: 'The aim is to come back',
        detail: 'No height yet. The sentence is the decision.',
        effect: {
          note: 'You tell the team the walk out is the result.',
          hours: 6,
          move: 'hold',
          scores: {
            judgment: { label: 'You named the return as the aim', delta: 8, mark: 'aim-return' },
            teamwork: { label: 'The team heard the aim before the forest', delta: 4, mark: 'aim-team' },
          },
        },
      },
    ],
  },
  {
    id: 'kili-big-tree',
    category: 'supplies',
    checkpoints: ['approach'],
    phase: 'up',
    urgent: true,
    title: 'Big Tree Camp',
    text: 'The tents are already up under the forest. Morning is for water, a count of the team, and the walk onto the moorland. Shira 1 is the next camp.',
    choices: [
      {
        label: 'Break camp and keep a patient pace',
        detail: 'The heath takes the day. Shira 1 gets the tents.',
        effect: {
          note: 'You leave Big Tree at an easy pace and pitch on the edge of the Shira Plateau.',
          hours: DAY,
          move: 'up',
          energy: -4,
          supplies: -1,
          acclimatization: 4,
          scores: {
            judgment: { label: 'You let the moorland take a whole day', delta: 6, mark: 'shira1-pace' },
            teamwork: { label: 'You kept the team inside one pace', delta: 4, mark: 'shira1-team' },
          },
        },
      },
      {
        label: 'Stay another night under the trees',
        detail: 'Food and an easy night. The plateau waits.',
        effect: {
          note: 'You keep the camp in the forest for another night.',
          hours: DAY,
          move: 'hold',
          supplies: -2,
          teamCondition: 4,
          energy: 4,
          scores: {
            judgment: { label: 'You spent a night not going higher', delta: 4, mark: 'forest-hold' },
          },
        },
      },
      {
        label: 'Force the moorland before the team is ready',
        detail: 'Shira 1 before the legs have agreed.',
        effect: {
          note: 'You push out of the forest and arrive at Shira 1 with the team strung out.',
          hours: 18,
          move: 'up',
          energy: -12,
          teamCondition: -8,
          supplies: -2,
          scores: {
            judgment: { label: 'You left the forest faster than the team', delta: -8, mark: 'shira1-rush' },
            teamwork: { label: 'The pace split the group', delta: -6, mark: 'shira1-split' },
          },
        },
      },
    ],
  },
  {
    id: 'kili-shira1',
    category: 'acclimatization',
    checkpoints: ['ebc'],
    phase: 'up',
    urgent: true,
    title: 'The plateau',
    text: 'Shira 1 is pitched. The old caldera is open heath and giant groundsels, and Kibo is finally a mountain instead of a rumor. Shira 2 is not far. The useful work is a walk above camp before dinner.',
    choices: [
      {
        label: 'Cross the plateau and pitch at Shira 2',
        detail: 'Tents at Shira 2. A short walk higher, then back down to sleep.',
        effect: {
          note: 'You cross to Shira 2, set the tents, and walk above camp before coming back to sleep.',
          hours: DAY,
          move: 'up',
          visitMeters: 4100,
          energy: -6,
          supplies: -1,
          acclimatization: 6,
          scores: {
            judgment: { label: 'You walked above Shira 2 and slept lower', delta: 8, mark: 'shira-high' },
            preparation: { label: 'The camp was pitched before the extra walk', delta: 4, mark: 'shira2-camp' },
          },
        },
      },
      {
        label: 'Hold the plateau for a day',
        detail: 'No new camp. Lungs and a quieter team.',
        effect: {
          note: 'You keep the tents at Shira 1 and let the day be a day.',
          hours: DAY,
          move: 'hold',
          supplies: -2,
          teamCondition: 3,
          scores: {
            judgment: { label: 'You held the plateau instead of collecting camps', delta: 5, mark: 'shira1-hold' },
          },
        },
      },
      {
        label: 'Race the plateau',
        detail: 'Shira 2 early. The afternoon walk does not happen.',
        effect: {
          note: 'You race the plateau and pitch at Shira 2 with nothing left for a walk above camp.',
          hours: 14,
          move: 'up',
          energy: -10,
          teamCondition: -4,
          acclimatization: 1,
          scores: {
            judgment: { label: 'You crossed the plateau and skipped the walk above camp', delta: -6, mark: 'shira-race' },
          },
        },
      },
    ],
  },
  {
    id: 'kili-lava',
    category: 'acclimatization',
    checkpoints: ['camp1'],
    phase: 'up',
    urgent: true,
    title: 'Lava Tower, then down',
    text: 'This is the day the ten-day walk is built around. Up to Lava Tower for the air, then down to Barranco to sleep. The camp ends near where it started. The height in the middle is the point.',
    choices: [
      {
        label: 'Tag the tower, then sleep low',
        detail: 'Touch the tower. Pitch in the Barranco valley.',
        effect: {
          note: 'You tag Lava Tower, then drop to Barranco and set the tents under the wall.',
          hours: DAY,
          move: 'up',
          visitMeters: 4630,
          energy: -8,
          supplies: -2,
          acclimatization: 8,
          scores: {
            judgment: { label: 'You climbed high and slept low', delta: 10, mark: 'lava-low' },
            riskManagement: { label: 'The tower was a visit, not a bed', delta: 6, mark: 'lava-visit' },
          },
        },
      },
      {
        label: 'Skip the tower and drop to Barranco',
        detail: 'The valley camp, without the height that teaches the body.',
        effect: {
          note: 'You contour down toward Barranco and never give the team the hour at the tower.',
          hours: 16,
          move: 'up',
          energy: -6,
          acclimatization: 2,
          scores: {
            judgment: { label: 'You skipped the climb-high day', delta: -6, mark: 'lava-skip' },
          },
        },
      },
      {
        label: 'Turn the plateau around',
        detail: 'Uhuru stays. The walk out starts from Shira.',
        effect: {
          note: 'You turn the expedition around on the plateau.',
          hours: 8,
          move: 'retreat',
          scores: turned(4),
        },
      },
    ],
  },
  {
    id: 'kili-wall',
    category: 'fatigue',
    checkpoints: ['camp2'],
    phase: 'up',
    urgent: true,
    title: 'The Barranco Wall',
    text: 'The tents at Barranco come down after breakfast. The wall is a steep walk, not a climb, and the day is short on purpose. Karanga is the next place the tents go up.',
    choices: [
      {
        label: 'Climb the wall and camp at Karanga',
        detail: 'A short day. Camp pitched in the valley beyond.',
        effect: {
          note: 'You take the wall slowly and pitch at Karanga with daylight left.',
          hours: DAY,
          move: 'up',
          energy: -6,
          supplies: -1,
          acclimatization: 4,
          teamCondition: 2,
          scores: {
            judgment: { label: 'You kept the wall day short', delta: 6, mark: 'wall-short' },
            teamwork: { label: 'The team came off the wall together', delta: 4, mark: 'wall-team' },
          },
        },
      },
      {
        label: 'Rest beneath the wall',
        detail: 'Another night at Barranco. The wall can wait.',
        effect: {
          note: 'You leave the tents up at Barranco and take the day.',
          hours: DAY,
          move: 'hold',
          supplies: -2,
          teamCondition: 4,
          scores: {
            judgment: { label: 'You rested under the wall', delta: 4, mark: 'wall-rest' },
          },
        },
      },
      {
        label: 'Turn around in the valley',
        detail: 'The wall stays unclimbed. The team starts down.',
        effect: {
          note: 'You turn around in the Barranco valley.',
          hours: 8,
          move: 'retreat',
          scores: turned(6),
        },
      },
    ],
  },
  {
    id: 'kili-karanga-day',
    category: 'acclimatization',
    checkpoints: ['camp3'],
    phase: 'up',
    urgent: true,
    title: 'The extra day',
    text: 'Karanga is pitched. On the ten-day walk this morning is not for Barafu. It is for a short hike above camp and a night in the same tents. Skipping it is how a shorter route gets made.',
    choices: [
      {
        label: 'Take the extra day',
        detail: 'Walk above camp. Sleep here again.',
        effect: {
          note: 'You walk above Karanga and come back to the same tents.',
          hours: DAY,
          move: 'hold',
          mark: 'karanga-rest',
          visitMeters: 4200,
          supplies: -2,
          teamCondition: 4,
          acclimatization: 6,
          scores: {
            judgment: { label: 'You used the extra day at Karanga', delta: 10, mark: 'karanga-day' },
            riskManagement: { label: 'Barafu waited while the team caught up', delta: 6, mark: 'karanga-risk' },
          },
        },
      },
      {
        label: 'Push on tired to Barafu',
        detail: 'High camp tonight. The rest day disappears.',
        effect: {
          note: 'You break Karanga early and pitch at Barafu on tired legs.',
          hours: 18,
          move: 'up',
          energy: -10,
          teamCondition: -6,
          acclimatization: 1,
          supplies: -2,
          scores: {
            judgment: { label: 'You deleted the Karanga day', delta: -8, mark: 'karanga-push' },
          },
        },
      },
      {
        label: 'Walk out from here',
        detail: 'Barafu and Uhuru stay ahead. The team turns down.',
        effect: {
          note: 'You leave Karanga for the walk out.',
          hours: 8,
          move: 'retreat',
          scores: turned(8),
        },
      },
    ],
  },
  {
    id: 'kili-karanga-leave',
    category: 'delay',
    checkpoints: ['camp3'],
    phase: 'up',
    urgent: true,
    when: (state) => state.marks['karanga-rest'] === true,
    title: 'Break camp for high camp',
    text: 'The extra night is done. Barafu is a short, dry walk up the ridge. The tents there are the last ones before the summit bid.',
    choices: [
      {
        label: 'Break camp for Barafu',
        detail: 'Pitch high. Eat early. Do not start up tonight.',
        effect: {
          note: 'You walk up to Barafu, pitch, and stop for the night.',
          hours: DAY,
          move: 'up',
          energy: -5,
          supplies: -1,
          acclimatization: 3,
          scores: {
            preparation: { label: 'Barafu was a camp, not a starting line', delta: 6, mark: 'barafu-camp' },
          },
        },
      },
      {
        label: 'Keep the rest going',
        detail: 'Another day in the same valley.',
        effect: {
          note: 'You keep the Karanga tents up for one more day.',
          hours: DAY,
          move: 'hold',
          supplies: -3,
          teamCondition: 2,
          scores: {
            judgment: { label: 'You stayed at Karanga past the extra day', delta: 2, mark: 'karanga-extra' },
          },
        },
      },
      {
        label: 'Turn around after the rest',
        detail: 'The rest was the decision. Down starts now.',
        effect: {
          note: 'You turn around after the day at Karanga.',
          hours: 8,
          move: 'retreat',
          scores: turned(8),
        },
      },
    ],
  },
  {
    id: 'kili-barafu-rest',
    category: 'summit-window',
    checkpoints: ['camp4'],
    phase: 'up',
    urgent: true,
    title: 'The rest day at Barafu',
    text: 'The tents are up on the ridge. On this ten-day game, today is empty on purpose: water, food, and a team that is not already spent. Midnight is tomorrow’s problem.',
    choices: [
      {
        label: 'Rest the day',
        detail: 'No height. The bid waits until the next night.',
        effect: {
          note: 'You keep the team in the Barafu tents and let the day be a rest.',
          hours: DAY,
          move: 'hold',
          mark: 'barafu-rest',
          supplies: -2,
          energy: 4,
          teamCondition: 4,
          acclimatization: 6,
          scores: {
            judgment: { label: 'You rested at Barafu before the midnight start', delta: 12, mark: 'barafu-day' },
            riskManagement: { label: 'The summit bid was not the arrival', delta: 8, mark: 'barafu-risk' },
          },
        },
      },
      {
        label: 'Start for the summit tonight',
        detail: 'Uhuru on the day you arrived. The rest is gone.',
        effect: {
          note: 'You leave Barafu the night you arrived.',
          hours: 21,
          move: 'summit',
          energy: -16,
          health: -4,
          oxygen: -8,
          teamCondition: -6,
          supplies: -2,
          scores: {
            judgment: { label: 'You started up the night you reached high camp', delta: -10, mark: 'barafu-rush' },
            riskManagement: { label: 'The rest day was the margin, and you spent it', delta: -8, mark: 'barafu-spent' },
          },
        },
      },
      {
        label: 'The summit can wait forever',
        detail: 'Turn the camp around. The walk out is the result.',
        effect: {
          note: 'You turn the expedition around at Barafu.',
          hours: 8,
          move: 'retreat',
          scores: turned(10),
        },
      },
    ],
  },
  {
    id: 'kili-summit-bid',
    category: 'summit-window',
    checkpoints: ['camp4'],
    phase: 'up',
    urgent: true,
    when: (state) => state.marks['barafu-rest'] === true,
    title: 'Midnight',
    text: 'The rest day is over. In this game the bid leaves in the dark, tags the rim, and is not finished until the team is going down. Stella Point is a place you pass. Uhuru is a place you leave.',
    choices: [
      {
        label: 'Leave at midnight',
        detail: 'Up through the dark. The summit is a visit.',
        effect: {
          note: 'You leave at midnight, pass Stella Point in the dawn, and stand on Uhuru.',
          hours: 21,
          move: 'summit',
          visitMeters: 5756,
          energy: -12,
          oxygen: -6,
          supplies: -2,
          acclimatization: 2,
          scores: {
            judgment: { label: 'The midnight start still had a descent', delta: 8, mark: 'midnight' },
          },
        },
      },
      {
        label: 'Wait out a worse morning',
        detail: 'Another day in the tents. The bid stays available.',
        effect: {
          note: 'You keep the tents zipped and wait.',
          hours: DAY,
          move: 'hold',
          supplies: -3,
          weatherRisk: -6,
          scores: {
            riskManagement: { label: 'You waited when the morning was the wrong one', delta: 6, mark: 'wait-morning' },
          },
        },
      },
      {
        label: 'Turn around at high camp',
        detail: 'The rest was enough. Down is the decision.',
        effect: {
          note: 'You turn around at Barafu after the rest day.',
          hours: 8,
          move: 'retreat',
          scores: turned(10),
        },
      },
    ],
  },
  {
    id: 'kili-uhuru',
    category: 'descent',
    checkpoints: ['summit'],
    phase: 'up',
    urgent: true,
    review: 'sme',
    title: 'The top is not the end',
    text: 'Uhuru, in this game. The photograph is the easy part. Mweka Camp is still a long walk down, and a summit that stays up here is not a finished expedition. This is not advice for a real mountain.',
    choices: [
      {
        label: 'Turn down while you still can',
        detail: 'Leave the summit. Sleep much lower, at Mweka.',
        effect: {
          note: 'You leave Uhuru and walk down until the tents go up at Mweka.',
          hours: 12,
          move: 'down',
          energy: -8,
          supplies: -2,
          teamCondition: 2,
          scores: {
            judgment: { label: 'You left the summit while the day still worked', delta: 10, mark: 'down-now' },
            teamwork: { label: 'The team that went up started down', delta: 6, mark: 'down-team' },
          },
        },
      },
      {
        label: 'A photograph, then down',
        detail: 'A few minutes. Then the same long walk to Mweka.',
        effect: {
          note: 'You take the photograph and start down to Mweka.',
          hours: 14,
          move: 'down',
          energy: -6,
          supplies: -2,
          scores: {
            judgment: { label: 'The photograph did not become the plan', delta: 6, mark: 'photo-down' },
          },
        },
      },
      {
        label: 'Stay on the summit',
        detail: 'More time up here. Less margin for the walk down.',
        effect: {
          note: 'You stay on the summit. In this game, that spends the team.',
          hours: 4,
          move: 'hold',
          health: -8,
          energy: -8,
          oxygen: -6,
          scores: {
            judgment: { label: 'You treated the summit as a place to stay', delta: -12, mark: 'stay-up' },
            riskManagement: { label: 'The descent lost the hour it needed', delta: -8, mark: 'stay-risk' },
          },
        },
      },
    ],
  },
  {
    id: 'kili-mweka',
    category: 'descent',
    checkpoints: ['descent'],
    phase: 'down',
    urgent: true,
    title: 'The forest to the gate',
    text: 'The high camps are behind you. What is left is the walk through the forest to Mweka Gate, where this expedition actually ends.',
    choices: [
      {
        label: 'Walk out to the gate',
        detail: 'Finish the tenth day. The team leaves together.',
        effect: {
          note: 'You walk the forest down to Mweka Gate.',
          hours: 10,
          move: 'down',
          energy: 2,
          teamCondition: 2,
          scores: {
            teamwork: { label: 'The walk out stayed a team', delta: 6, mark: 'gate-team' },
            judgment: { label: 'You finished the descent', delta: 6, mark: 'gate-down' },
          },
        },
      },
      {
        label: 'Camp one more night and eat',
        detail: 'Time and food, spent on people.',
        effect: {
          note: 'You keep a camp on the way out and feed the team.',
          hours: 12,
          move: 'hold',
          supplies: -4,
          energy: 6,
          teamCondition: 6,
          scores: {
            teamwork: { label: 'You stopped the descent for the team', delta: 6, mark: 'descent-eat' },
          },
        },
      },
      {
        label: 'Push the forest in the dark',
        detail: 'The gate sooner. A sloppier finish.',
        effect: {
          note: 'You hurry the last forest in the dark.',
          hours: 8,
          move: 'down',
          energy: -8,
          teamCondition: -4,
          scores: {
            riskManagement: { label: 'The last day was faster than it needed to be', delta: -4, mark: 'gate-rush' },
          },
        },
      },
    ],
  },
  {
    id: 'kili-headache',
    category: 'fatigue',
    checkpoints: ['camp3', 'camp4'],
    phase: 'up',
    review: 'sme',
    when: (state) => state.health < 70,
    title: 'A head that will not settle',
    text: 'Someone on the team is quiet and holding their head. In this game that is a reason to stop the day. It is not a diagnosis, and it is not medical advice.',
    choices: [
      {
        label: 'Stop the day',
        detail: 'Same camp. Water, food, no more height.',
        effect: {
          note: 'You stop the day in camp.',
          hours: DAY,
          move: 'hold',
          supplies: -2,
          teamCondition: 4,
          scores: {
            riskManagement: { label: 'You stopped when a head would not settle', delta: 8, mark: 'head-stop' },
          },
        },
      },
      {
        label: 'Keep climbing',
        detail: 'The schedule stays. The person comes along.',
        effect: {
          note: 'You keep climbing with a teammate who should have stopped.',
          hours: 12,
          move: 'up',
          health: -6,
          teamCondition: -8,
          scores: {
            teamwork: { label: 'You walked away from a hurting teammate', delta: -10, mark: 'head-go' },
          },
        },
      },
      {
        label: 'Turn around',
        detail: 'The summit is not worth this.',
        effect: {
          note: 'You turn around.',
          hours: 8,
          move: 'retreat',
          scores: turned(6),
        },
      },
    ],
  },
  {
    id: 'kili-water',
    category: 'supplies',
    checkpoints: ['approach', 'ebc', 'camp1'],
    phase: 'up',
    when: (state) => state.supplies < 60,
    title: 'The water is the day',
    text: 'The bottles are lighter than the plan. Camp can still be a place to melt, filter, and drink before the next trail.',
    choices: [
      {
        label: 'Stop and sort the water',
        detail: 'Time in camp. The next trail waits.',
        effect: {
          note: 'You halt the day and put the water back in order.',
          hours: 12,
          move: 'hold',
          supplies: 4,
          energy: 2,
          scores: {
            preparation: { label: 'You treated water as part of the camp', delta: 6, mark: 'water' },
          },
        },
      },
      {
        label: 'Carry on and hope',
        detail: 'The camp tonight will have to solve it.',
        effect: {
          note: 'You keep walking with the water already short.',
          hours: 10,
          move: 'up',
          supplies: -4,
          teamCondition: -4,
          scores: {
            preparation: { label: 'You left camp with the water already short', delta: -6, mark: 'water-short' },
          },
        },
      },
    ],
  },
  {
    id: 'kili-weather',
    category: 'weather',
    checkpoints: ['camp2', 'camp3', 'camp4'],
    phase: 'up',
    when: (state) => state.weatherRisk > 55,
    title: 'The ridge is in cloud',
    text: 'Wind and cloud sit on the next camp. The tents you have are a finished decision. The tents you do not have yet can wait.',
    choices: [
      {
        label: 'Stay with the tents you have',
        detail: 'No new height while the cloud is the weather.',
        effect: {
          note: 'You stay in the camp you already pitched.',
          hours: DAY,
          move: 'hold',
          supplies: -2,
          weatherRisk: -8,
          scores: {
            riskManagement: { label: 'You let the cloud keep the next camp', delta: 8, mark: 'cloud-stay' },
          },
        },
      },
      {
        label: 'Walk into it',
        detail: 'The schedule does not look at the sky.',
        effect: {
          note: 'You walk into the cloud.',
          hours: 12,
          move: 'up',
          energy: -8,
          weatherRisk: 6,
          teamCondition: -4,
          scores: {
            riskManagement: { label: 'You walked into weather you could see', delta: -8, mark: 'cloud-go' },
          },
        },
      },
    ],
  },
];

export const SME_REVIEW_IDS = ['kili-uhuru', 'kili-headache'] as const;
