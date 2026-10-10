/**
 * Ten-day Lemosho scenes. Game fiction, not a route and not advice.
 * Cards flagged `review: 'sme'` need specialist review before any
 * wording is treated as accurate.
 */
import type { CheckpointId, EventCard, LedgerNote } from '@/game/types';

const DAY = 24;
/** A walk that leaves in the morning and reaches camp after dark. */
const EVENING = 12;
/** Sleep that gives the morning back. */
const SLEEP = 12;

function afterNight(checkpoint: CheckpointId): (state: { marks: Record<string, number | boolean> }) => boolean {
  return (state) => state.marks[`night-${checkpoint}`] === true;
}

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
        detail: 'A full day to Big Tree. Camp as the light goes.',
        effect: {
          note: 'You walk the montane forest and reach Mti Mkubwa as the light goes.',
          hours: EVENING,
          move: 'up',
          energy: -6,
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
          supplies: -1,
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
    id: 'kili-night-forest',
    category: 'night',
    checkpoints: ['approach'],
    phase: 'up',
    urgent: true,
    title: 'Rain on the tents',
    text: 'Mti Mkubwa, and the forest is still dripping. In this game the first night is mud, a wet camp, and a choice about whether anyone walks again before morning. It is not a lesson in how to camp.',
    choices: [
      {
        label: 'Sleep under the trees',
        detail: 'Dry what you can. The moorland is a morning.',
        effect: {
          note: 'You keep the camp and sleep under the trees.',
          hours: SLEEP,
          move: 'hold',
          mark: 'night-approach',
          energy: 2,
          teamCondition: 2,
          scores: {
            judgment: { label: 'You gave the forest its night', delta: 6, mark: 'night-forest' },
            teamwork: { label: 'The team stayed in camp', delta: 3, mark: 'night-forest-team' },
          },
        },
      },
      {
        label: 'Walk the mud in the dark',
        detail: 'Out of the tents. No new camp, and a colder team.',
        effect: {
          note: 'You leave the tents and walk the mud. The night does not become a camp.',
          hours: 4,
          move: 'hold',
          mark: 'night-approach',
          energy: -10,
          teamCondition: -6,
          scores: {
            judgment: { label: 'You walked the forest after dark', delta: -6, mark: 'night-forest-walk' },
          },
        },
      },
      {
        label: 'Stay up while the rain runs',
        detail: 'No one sleeps. Morning comes anyway.',
        effect: {
          note: 'You sit the rain out. The team meets the morning already tired.',
          hours: 6,
          move: 'hold',
          mark: 'night-approach',
          energy: -6,
          teamCondition: -3,
          scores: {
            judgment: { label: 'You spent the forest night awake', delta: -3, mark: 'night-forest-wake' },
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
    when: afterNight('approach'),
    title: 'Morning at Big Tree',
    text: 'The rain eased. Morning is for water, a count of the team, and the walk out of the forest onto the moorland. Shira 1 is the next camp, and you will reach it as the light goes.',
    choices: [
      {
        label: 'Break camp and keep a patient pace',
        detail: 'The heath takes the day. Shira 1 gets the tents after dark.',
        effect: {
          note: 'You leave Big Tree at an easy pace and pitch on the Shira Plateau as the light goes.',
          hours: EVENING,
          move: 'up',
          energy: -6,
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
          hours: 16,
          move: 'up',
          energy: -12,
          teamCondition: -8,
          supplies: -1,
          scores: {
            judgment: { label: 'You left the forest faster than the team', delta: -8, mark: 'shira1-rush' },
            teamwork: { label: 'The pace split the group', delta: -6, mark: 'shira1-split' },
          },
        },
      },
    ],
  },
  {
    id: 'kili-night-shira',
    category: 'night',
    checkpoints: ['ebc'],
    phase: 'up',
    urgent: true,
    title: 'Wind on the plateau',
    text: 'Shira 1 after dark. The heath is open, the dust moves, and the cold sits on the tents. In this game the walk above camp belongs to daylight. The night is for staking what you have and sleeping.',
    choices: [
      {
        label: 'Stake the tents and sleep',
        detail: 'The plateau can be walked in the morning.',
        effect: {
          note: 'You stake the tents and sleep through the plateau wind.',
          hours: SLEEP,
          move: 'hold',
          mark: 'night-ebc',
          teamCondition: 2,
          scores: {
            judgment: { label: 'You let the plateau wind be a night in camp', delta: 6, mark: 'night-shira' },
          },
        },
      },
      {
        label: 'Walk above camp in the dark',
        detail: 'The useful walk, done when no one can see.',
        effect: {
          note: 'You leave the tents and walk above camp in the dark.',
          hours: 4,
          move: 'hold',
          mark: 'night-ebc',
          energy: -10,
          teamCondition: -6,
          scores: {
            judgment: { label: 'You took the acclimatization walk at night', delta: -8, mark: 'night-shira-walk' },
          },
        },
      },
      {
        label: 'Sit the wind out',
        detail: 'Awake, and no higher than the tents.',
        effect: {
          note: 'You sit with the wind. Sleep does not really happen.',
          hours: 6,
          move: 'hold',
          mark: 'night-ebc',
          energy: -6,
          teamCondition: -2,
          scores: {
            judgment: { label: 'You sat up through the plateau wind', delta: -3, mark: 'night-shira-wake' },
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
    when: afterNight('ebc'),
    title: 'The plateau',
    text: 'Morning on Shira 1. The old caldera is open heath and giant groundsels, and Kibo is finally a mountain instead of a rumor. Shira 2 is a day away. The useful work is a walk above camp before the light goes.',
    choices: [
      {
        label: 'Cross the plateau and pitch at Shira 2',
        detail: 'Tents at Shira 2 by dusk. A short walk higher, then back down.',
        effect: {
          note: 'You cross to Shira 2, walk above camp, and come back as the light goes.',
          hours: EVENING,
          move: 'up',
          visitMeters: 4100,
          energy: -8,
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
          energy: -12,
          teamCondition: -6,
          acclimatization: 1,
          scores: {
            judgment: { label: 'You crossed the plateau and skipped the walk above camp', delta: -6, mark: 'shira-race' },
          },
        },
      },
    ],
  },
  {
    id: 'kili-night-shira2',
    category: 'night',
    checkpoints: ['camp1'],
    phase: 'up',
    urgent: true,
    title: 'Frost before the tower',
    text: 'Shira 2 is pitched and the frost is already on it. Tomorrow, in this game, is the day you climb toward Lava Tower and sleep lower. Starting that walk in the dark spends the day before it begins.',
    choices: [
      {
        label: 'Sleep before the tower',
        detail: 'The tower is a daylight visit.',
        effect: {
          note: 'You sleep at Shira 2. The tower waits for morning.',
          hours: SLEEP,
          move: 'hold',
          mark: 'night-camp1',
          teamCondition: 2,
          scores: {
            judgment: { label: 'You saved the tower for daylight', delta: 6, mark: 'night-shira2' },
          },
        },
      },
      {
        label: 'Start for the tower in the dark',
        detail: 'The big day, begun with no light.',
        effect: {
          note: 'You start toward the tower in the dark and turn the party back to the tents.',
          hours: 4,
          move: 'hold',
          mark: 'night-camp1',
          energy: -12,
          teamCondition: -6,
          scores: {
            judgment: { label: 'You started the tower day at night', delta: -8, mark: 'night-shira2-walk' },
          },
        },
      },
      {
        label: 'Pace between the tents',
        detail: 'Awake in camp. The tower still waits.',
        effect: {
          note: 'You pace the camp. The frost night is not a sleep.',
          hours: 6,
          move: 'hold',
          mark: 'night-camp1',
          energy: -6,
          scores: {
            judgment: { label: 'You paced away the night before the tower', delta: -3, mark: 'night-shira2-wake' },
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
    when: afterNight('camp1'),
    title: 'Lava Tower, then down',
    text: 'This is the day the ten-day walk is built around. Up to Lava Tower for the air, then down to Barranco to sleep. The camp ends near where it started. You reach the valley as the light goes. The height in the middle is the point.',
    choices: [
      {
        label: 'Tag the tower, then sleep low',
        detail: 'Touch the tower. Pitch in the Barranco valley.',
        effect: {
          note: 'You tag Lava Tower, then drop to Barranco and set the tents under the wall as the light goes.',
          hours: EVENING,
          move: 'up',
          visitMeters: 4630,
          energy: -10,
          supplies: -1,
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
          hours: 14,
          move: 'up',
          energy: -8,
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
    id: 'kili-night-barranco',
    category: 'night',
    checkpoints: ['camp2'],
    phase: 'up',
    urgent: true,
    title: 'The wall is a morning',
    text: 'The Barranco Wall is a dark ridge over the tents. In this game it is a short morning scramble, not a night climb, and cloud usually sits on it by early afternoon. Going up it now is how a team gets turned around tired.',
    choices: [
      {
        label: 'Sleep and leave the wall for morning',
        detail: 'The scramble can wait for light.',
        effect: {
          note: 'You sleep beneath the wall and leave it for morning.',
          hours: SLEEP,
          move: 'hold',
          mark: 'night-camp2',
          teamCondition: 2,
          scores: {
            judgment: { label: 'You left the wall for daylight', delta: 8, mark: 'night-wall' },
            riskManagement: { label: 'A night on the wall was never the plan', delta: 4, mark: 'night-wall-risk' },
          },
        },
      },
      {
        label: 'Try the wall tonight',
        detail: 'Up in the dark. The party will not like it.',
        effect: {
          note: 'You start up the wall in the dark. Lena turns the party back before it becomes a climb.',
          hours: 4,
          move: 'hold',
          mark: 'night-camp2',
          energy: -14,
          health: -4,
          teamCondition: -8,
          scores: {
            judgment: { label: 'You tried the wall at night', delta: -10, mark: 'night-wall-go' },
            teamwork: { label: 'The night start split the party', delta: -4, mark: 'night-wall-team' },
          },
        },
      },
      {
        label: 'Stay up under the wall',
        detail: 'No height. No sleep either.',
        effect: {
          note: 'You stay up watching the wall. Morning comes without a rest.',
          hours: 6,
          move: 'hold',
          mark: 'night-camp2',
          energy: -6,
          teamCondition: -2,
          scores: {
            judgment: { label: 'You watched the wall instead of sleeping', delta: -3, mark: 'night-wall-wake' },
          },
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
    when: afterNight('camp2'),
    title: 'The Barranco Wall',
    text: 'The tents at Barranco come down after breakfast. The wall is a steep morning walk, not a climb, and cloud builds on it by early afternoon. The day is short on purpose. Karanga is where the tents go up, as the light goes.',
    choices: [
      {
        id: 'kili-wall-climb',
        label: 'Climb the wall and camp at Karanga',
        detail: 'You walk the scramble. Then the tents go up at Karanga.',
        effect: {
          note: 'You take the wall in the morning and pitch at Karanga as the light goes.',
          hours: EVENING,
          move: 'up',
          energy: -8,
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
    id: 'kili-night-karanga',
    category: 'night',
    checkpoints: ['camp3'],
    phase: 'up',
    urgent: true,
    title: 'A cold night in the valley',
    text: 'Karanga after dark. The valley is cold and the ridge to Barafu is not tonight’s walk. In this game the extra day only works if the team actually sleeps. Staying up to watch the ridge spends the rest you came here for.',
    choices: [
      {
        label: 'Lie down in the valley',
        detail: 'The extra day can start in the morning.',
        effect: {
          note: 'You lie down at Karanga. The ridge can wait.',
          hours: SLEEP,
          move: 'hold',
          mark: 'night-camp3',
          teamCondition: 2,
          scores: {
            judgment: { label: 'You slept before the extra day', delta: 6, mark: 'night-karanga' },
          },
        },
      },
      {
        label: 'Stay up and watch the ridge',
        detail: 'The view, paid for with the night.',
        effect: {
          note: 'You stay up watching the ridge. The extra day starts tired.',
          hours: 6,
          move: 'hold',
          mark: 'night-camp3',
          energy: -8,
          teamCondition: -4,
          scores: {
            judgment: { label: 'You traded the Karanga night for the view', delta: -4, mark: 'night-karanga-wake' },
          },
        },
      },
      {
        label: 'Walk the tents all night',
        detail: 'Everyone accounted for. No one rested.',
        effect: {
          note: 'You walk the tents until morning. The count was not a rest.',
          hours: 4,
          move: 'hold',
          mark: 'night-camp3',
          energy: -8,
          teamCondition: -4,
          scores: {
            judgment: { label: 'You spent the Karanga night on your feet', delta: -6, mark: 'night-karanga-walk' },
          },
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
    when: afterNight('camp3'),
    title: 'The extra day',
    text: 'Morning at Karanga. On the ten-day walk this day is not for Barafu. It is a short hike above camp, then the same tents again. Skipping it is how a shorter route gets made.',
    choices: [
      {
        label: 'Take the extra day',
        detail: 'Walk above camp. Sleep here again.',
        effect: {
          note: 'You walk above Karanga and come back to the same tents for the night.',
          hours: DAY,
          move: 'hold',
          mark: 'karanga-rest',
          visitMeters: 4200,
          supplies: -1,
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
          hours: 14,
          move: 'up',
          energy: -12,
          teamCondition: -8,
          acclimatization: 1,
          supplies: -1,
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
        detail: 'Pitch high as the light goes. Do not start up tonight.',
        effect: {
          note: 'You walk up to Barafu and pitch as the light goes.',
          hours: EVENING,
          move: 'up',
          energy: -6,
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
    id: 'kili-night-barafu',
    category: 'night',
    checkpoints: ['camp4'],
    phase: 'up',
    urgent: true,
    title: 'Wind on the ridge',
    text: 'Barafu after dark. The ridge wind makes a poor night, and that is still the night you take. In this game the summit bid is not the evening you arrive. Pacing the ridge spends the rest day before it starts.',
    choices: [
      {
        label: 'Lie down on the ridge',
        detail: 'A poor sleep. Still a sleep.',
        effect: {
          note: 'You lie down at Barafu and take the poor sleep.',
          hours: SLEEP,
          move: 'hold',
          mark: 'night-camp4',
          teamCondition: 2,
          scores: {
            judgment: { label: 'You slept at Barafu instead of starting up', delta: 8, mark: 'night-barafu' },
            riskManagement: { label: 'Arrival night was not the bid', delta: 4, mark: 'night-barafu-risk' },
          },
        },
      },
      {
        label: 'Pace the ridge',
        detail: 'Awake in the wind. No higher.',
        effect: {
          note: 'You pace the ridge in the wind. The team does not sleep.',
          hours: 4,
          move: 'hold',
          mark: 'night-camp4',
          energy: -10,
          teamCondition: -6,
          scores: {
            judgment: { label: 'You paced away the night you reached high camp', delta: -6, mark: 'night-barafu-pace' },
          },
        },
      },
      {
        label: 'Sit out in the wind',
        detail: 'Outside the tents. Morning will notice.',
        effect: {
          note: 'You sit out in the wind. The rest day starts already cold.',
          hours: 6,
          move: 'hold',
          mark: 'night-camp4',
          energy: -8,
          health: -2,
          teamCondition: -4,
          scores: {
            judgment: { label: 'You sat the Barafu wind out', delta: -4, mark: 'night-barafu-sit' },
          },
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
    when: afterNight('camp4'),
    title: 'The rest day at Barafu',
    text: 'Morning on the ridge. On this ten-day game, today is empty on purpose: water, food, and a team that is not already spent. The bid is a midnight problem, not a morning one.',
    choices: [
      {
        label: 'Rest the day',
        detail: 'No height. The bid waits until the next night.',
        effect: {
          note: 'You keep the team in the Barafu tents until the night of the bid.',
          hours: 15,
          move: 'hold',
          mark: 'barafu-rest',
          supplies: -1,
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
          note: 'You leave Barafu without the empty day.',
          hours: 18,
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
    id: 'kili-hard-hour',
    category: 'summit-window',
    checkpoints: ['camp4'],
    phase: 'up',
    urgent: true,
    when: (state) => state.marks['barafu-rest'] === true,
    title: 'The hard hour',
    text: 'Midnight, in this game. The bid is loose ground and a cold wind, and the hour before dawn is when someone wants to go faster just to feel warmer. Keep the pace and the summit stays a visit. Speed spends the team. This is not advice, and it is not a route.',
    choices: [
      {
        label: 'Keep the pace through the dark',
        detail: 'Slow. Stella Point at dawn. Uhuru is a visit.',
        effect: {
          note: 'You keep the pace through the dark, pass Stella Point as the light comes, and stand on Uhuru.',
          hours: 8,
          move: 'summit',
          visitMeters: 5756,
          energy: -12,
          oxygen: -4,
          supplies: -1,
          scores: {
            judgment: { label: 'You kept the pace through the hard hour', delta: 10, mark: 'hard-hour' },
            teamwork: { label: 'The party stayed on one pace in the dark', delta: 4, mark: 'hard-hour-team' },
          },
        },
      },
      {
        label: 'Speed up to get warm',
        detail: 'Faster on the scree. A thinner team at the top.',
        effect: {
          note: 'You speed up in the cold. The team arrives at Uhuru spent.',
          hours: 6,
          move: 'summit',
          visitMeters: 5756,
          energy: -16,
          health: -4,
          teamCondition: -8,
          oxygen: -6,
          supplies: -1,
          scores: {
            judgment: { label: 'You sped up to get warm', delta: -8, mark: 'hard-hour-rush' },
            teamwork: { label: 'The pace broke in the cold', delta: -4, mark: 'hard-hour-split' },
          },
        },
      },
      {
        label: 'Turn the bid around',
        detail: 'The rest was enough. Down is the decision.',
        effect: {
          note: 'You turn the bid around in the dark.',
          hours: 4,
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
          note: 'You leave Uhuru and walk down until the tents go up at Mweka in the dark.',
          hours: 13,
          move: 'down',
          energy: -10,
          supplies: -1,
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
          hours: 12,
          move: 'down',
          energy: -8,
          supplies: -1,
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
    id: 'kili-night-mweka',
    category: 'night',
    checkpoints: ['descent'],
    phase: 'down',
    urgent: true,
    title: 'An exhausted forest',
    text: 'Mweka, and the team is used up. The gate is still a forest walk. In this game that walk is a morning. The night is sleep and food, not a race downhill in the dark.',
    choices: [
      {
        label: 'Sleep at Mweka',
        detail: 'The gate can have the morning.',
        effect: {
          note: 'You sleep at Mweka. The gate waits for morning.',
          hours: SLEEP,
          move: 'hold',
          mark: 'night-descent',
          energy: 2,
          teamCondition: 3,
          scores: {
            judgment: { label: 'You slept before the last forest', delta: 6, mark: 'night-mweka' },
            teamwork: { label: 'The used-up team got a night', delta: 4, mark: 'night-mweka-team' },
          },
        },
      },
      {
        label: 'Push the forest in the dark',
        detail: 'The gate sooner. A sloppier finish.',
        effect: {
          note: 'You leave the tents and hurry the last forest in the dark.',
          hours: 6,
          move: 'down',
          mark: 'night-descent',
          energy: -8,
          teamCondition: -6,
          scores: {
            riskManagement: { label: 'The last forest was a night march', delta: -6, mark: 'night-mweka-push' },
            teamwork: { label: 'The finish left people behind the pace', delta: -4, mark: 'night-mweka-split' },
          },
        },
      },
      {
        label: 'Stay up and finish the food',
        detail: 'Eating, without the sleep.',
        effect: {
          note: 'You stay up and finish the food. The morning is thinner for it.',
          hours: 6,
          move: 'hold',
          mark: 'night-descent',
          supplies: -2,
          energy: -4,
          teamCondition: 2,
          scores: {
            judgment: { label: 'You fed the team and skipped the sleep', delta: -2, mark: 'night-mweka-wake' },
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
    when: afterNight('descent'),
    title: 'The forest to the gate',
    text: 'Morning in the forest. The high camps are behind you. What is left is the walk to Mweka Gate, where this expedition actually ends.',
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
        label: 'Leave before breakfast',
        detail: 'The gate sooner. A thinner finish.',
        effect: {
          note: 'You leave before the team has eaten.',
          hours: 8,
          move: 'down',
          energy: -6,
          teamCondition: -4,
          scores: {
            riskManagement: { label: 'The last morning was faster than it needed to be', delta: -4, mark: 'gate-rush' },
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
