/**
 * Prototype Everest scenes. This is game fiction, not a route description
 * or safety instruction. Cards flagged `review: 'sme'` need specialist review
 * before any wording is treated as accurate.
 */
import type { EventCard } from '@/game/types';

const turned = (band: number) => ({
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
});

export const EVEREST_EVENTS: readonly EventCard[] = [
  {
    id: 'briefing-aim',
    category: 'turnaround',
    checkpoints: ['briefing'],
    phase: 'up',
    weight: 3,
    title: 'Name the expedition',
    text: 'The permit has a summit on it. The people in the room are waiting to hear what you think the expedition is for. In this game, that sentence is the first decision.',
    choices: [
      {
        label: 'The aim is to come back',
        detail: 'The summit is a place you might visit.',
        effect: {
          note: 'You say it plainly: the result is the return.',
          hours: 3,
          move: 'hold',
          scores: {
            judgment: { label: 'You named the return as the aim', delta: 8, mark: 'aim-return' },
          },
        },
      },
      {
        label: 'Go up only while the descent is still real',
        detail: 'A summit bid with a door still open behind you.',
        effect: {
          note: 'You tie any summit bid to a descent you can still make.',
          hours: 4,
          move: 'up',
          scores: {
            judgment: { label: 'You tied the summit to a fair window', delta: 5, mark: 'aim-window' },
          },
        },
      },
      {
        label: 'The summit is the point',
        detail: 'The walk out can be solved after the photograph.',
        effect: {
          note: 'You point at the top. The room gets quieter.',
          hours: 4,
          move: 'up',
          teamCondition: -4,
          scores: {
            judgment: { label: 'You treated the summit as the whole point', delta: -12, mark: 'aim-summit' },
          },
        },
      },
    ],
  },
  {
    id: 'briefing-oxygen',
    category: 'oxygen',
    checkpoints: ['briefing'],
    phase: 'up',
    weight: 3,
    review: 'sme',
    title: 'How much oxygen to carry',
    text: 'A stack of bottles is a weight, a plan, and a limit. This scene is a game abstraction of a real system. It is not a recommendation for how much oxygen to take, or when to open a bottle.',
    choices: [
      {
        label: 'Carry a reserve and accept the weight',
        detail: 'Slower approach. More margin later in the game.',
        effect: {
          note: 'You take the heavier oxygen plan. The approach will feel it.',
          hours: 4,
          move: 'hold',
          oxygen: 16,
          energy: -4,
          scores: {
            preparation: { label: 'You carried an oxygen reserve', delta: 10, mark: 'o2-reserve' },
          },
        },
      },
      {
        label: 'A standard load for this game',
        detail: 'Neither spare nor stripped.',
        effect: {
          note: 'You take the middle load and move.',
          hours: 6,
          move: 'up',
          oxygen: 6,
        },
      },
      {
        label: 'Travel light and hope the weather is kind',
        detail: 'Easier now. A smaller reserve above Camp III.',
        effect: {
          note: 'The packs are light. The reserve is a story you have not written.',
          hours: 5,
          move: 'up',
          oxygen: -12,
          energy: 4,
          scores: {
            preparation: { label: 'You stripped the oxygen plan', delta: -12, mark: 'o2-light' },
          },
        },
      },
    ],
  },
  {
    id: 'briefing-loads',
    category: 'supplies',
    checkpoints: ['briefing'],
    phase: 'up',
    weight: 2,
    title: 'What the loads are for',
    text: 'Food, fuel, and a repair kit compete with the desire to move fast. Nothing here tells you how to pack a real expedition. It only asks what this game party is willing to carry.',
    choices: [
      {
        label: 'Pack for the walk out, not just the walk up',
        detail: 'Supplies that are still there on the descent.',
        effect: {
          note: 'You pack as if the descent is part of the menu.',
          hours: 5,
          move: 'hold',
          supplies: 8,
          energy: -3,
          scores: {
            preparation: { label: 'You packed for the descent', delta: 10, mark: 'pack-down' },
          },
        },
      },
      {
        label: 'Balance the loads and leave',
        detail: 'Enough, if the days stay ordinary.',
        effect: {
          note: 'The loads are ordinary. You start walking.',
          hours: 6,
          move: 'up',
          supplies: 2,
        },
      },
      {
        label: 'Cut food to make the first days fast',
        detail: 'Speed now. A shorter pantry later.',
        effect: {
          note: 'The first days will look efficient. The pantry will not.',
          hours: 4,
          move: 'up',
          supplies: -10,
          scores: {
            preparation: { label: 'You spent the descent’s food on the approach', delta: -8, mark: 'cut-food' },
          },
        },
      },
    ],
  },
  {
    id: 'approach-pace',
    category: 'acclimatization',
    checkpoints: ['approach'],
    phase: 'up',
    weight: 4,
    review: 'sme',
    title: 'The approach is already altitude',
    text: 'Heads are light and someone wants to push to the next lodge. In this game, going up faster than the body is a cost. It is not a schedule you should copy onto a real trail.',
    choices: [
      {
        label: 'Take the extra night',
        detail: 'No camp gained. A body that is less behind.',
        effect: {
          note: 'You stay. The trail will be there after the night.',
          hours: 18,
          move: 'hold',
          acclimatization: 8,
          supplies: -3,
          scores: {
            judgment: { label: 'You let the approach do its work', delta: 10, mark: 'approach-rest' },
          },
        },
      },
      {
        label: 'Walk on, and stop early',
        detail: 'Some height. Not a race.',
        effect: {
          note: 'You move, then stop while there is still afternoon.',
          hours: 8,
          move: 'up',
          energy: -4,
          acclimatization: 3,
        },
      },
      {
        label: 'Make the lodge before dark',
        detail: 'The itinerary stays pretty. The team gets thinner.',
        effect: {
          note: 'You chase the lodge. The headache keeps up without trying.',
          hours: 7,
          move: 'up',
          energy: -8,
          health: -6,
          teamCondition: -6,
          scores: {
            judgment: { label: 'You hurried the approach', delta: -8, mark: 'hurried-approach' },
          },
        },
      },
    ],
  },
  {
    id: 'approach-day',
    category: 'fatigue',
    checkpoints: ['approach'],
    phase: 'up',
    weight: 2,
    title: 'A climber sits on a pack',
    text: 'It is not a rest. The pack is still on, and the eyes are working harder than the legs. The trail above is only a game trail. The choice is whether the team stays a team.',
    choices: [
      {
        label: 'Stop the whole group',
        detail: 'The itinerary slips. The person stays in it.',
        effect: {
          note: 'You stop everyone. Tea, a layer, and a slower hour.',
          hours: 6,
          move: 'hold',
          teamCondition: 8,
          energy: 4,
          supplies: -2,
          scores: {
            teamwork: { label: 'You stopped for the person who sat down', delta: 10, mark: 'sat-approach' },
          },
        },
      },
      {
        label: 'Shorten the day and keep them in the middle',
        detail: 'Move, but only as far as the slowest comfortable pace.',
        effect: {
          note: 'You put them in the middle of the line and shorten the day.',
          hours: 8,
          move: 'up',
          energy: -5,
          teamCondition: 2,
        },
      },
      {
        label: 'Tell them the lodge is close',
        detail: 'It might be. That is not a reason.',
        effect: {
          note: 'You say the lodge is close. The legs that needed that to be true do not agree.',
          hours: 7,
          move: 'up',
          teamCondition: -10,
          health: -4,
          scores: {
            teamwork: { label: 'You walked away from a tired climber', delta: -12, mark: 'left-tired' },
          },
        },
      },
    ],
  },
  {
    id: 'ebc-rest',
    category: 'acclimatization',
    checkpoints: ['ebc'],
    phase: 'up',
    weight: 4,
    review: 'sme',
    title: 'Base camp is not a victory',
    text: 'The tents feel like an arrival. A headache says otherwise. Resting here is a game rule about going higher later. It is not medical advice and not a real acclimatization schedule.',
    choices: [
      {
        label: 'Rest before the icefall',
        detail: 'A day with no height on it.',
        effect: {
          note: 'You give the day to breathing. The icefall can wait.',
          hours: 20,
          move: 'hold',
          acclimatization: 10,
          supplies: -4,
          scores: {
            judgment: { label: 'You rested at base camp on purpose', delta: 12, mark: 'ebc-rest' },
          },
        },
      },
      {
        label: 'One short trip up, then back to sleep',
        detail: 'A little height, and the night still at base.',
        effect: {
          note: 'You walk up and come back down to sleep. The game calls that a rotation, not a tactic to copy.',
          hours: 10,
          move: 'hold',
          acclimatization: 6,
          energy: -6,
          supplies: -2,
        },
      },
      {
        label: 'The weather window is the schedule',
        detail: 'Go up because the calendar says so.',
        effect: {
          note: 'You leave base camp on the calendar’s authority.',
          hours: 8,
          move: 'up',
          health: -6,
          energy: -8,
          scores: {
            judgment: { label: 'You left base camp ahead of the team’s lungs', delta: -10, mark: 'ebc-rush' },
          },
        },
      },
    ],
  },
  {
    id: 'ebc-forecast',
    category: 'weather',
    checkpoints: ['ebc'],
    phase: 'up',
    weight: 3,
    title: 'The forecast has a front on it',
    text: 'A voice from lower down reads a change in the weather. In the game, believing it is cheap. On a real mountain, forecasts are a tool for people who are trained to use them. This is not that training.',
    choices: [
      {
        label: 'Rewrite the next days around it',
        detail: 'Believe the voice while changing plans is still easy.',
        effect: {
          note: 'You treat the forecast as a reason to wait, not a mood.',
          hours: 12,
          move: 'hold',
          weatherRisk: -8,
          scores: {
            riskManagement: { label: 'You believed the forecast while it was still cheap', delta: 10, mark: 'forecast' },
          },
        },
      },
      {
        label: 'Move one camp and reassess',
        detail: 'Use the clearer day. Do not pretend there are two.',
        effect: {
          note: 'You move while the sky is still willing, and you plan to look again.',
          hours: 10,
          move: 'up',
          weatherRisk: 4,
          energy: -5,
        },
      },
      {
        label: 'Ignore it',
        detail: 'Forecasts do not carry loads.',
        effect: {
          note: 'You call the forecast theater and walk toward the part where it is not.',
          hours: 8,
          move: 'up',
          weatherRisk: 14,
          scores: {
            riskManagement: { label: 'You treated the forecast as a mood', delta: -12, mark: 'ignored-forecast' },
          },
        },
      },
    ],
  },
  {
    id: 'ebc-cough',
    category: 'team',
    checkpoints: ['ebc'],
    phase: 'up',
    weight: 2,
    review: 'sme',
    title: 'A cough that does not finish',
    text: 'One climber has a cough that outlasts the night. The game can lower a number called team condition. It cannot tell you whether a real person should climb. That is a medical decision, not a card.',
    choices: [
      {
        label: 'They stay down',
        detail: 'The team gets smaller. The risk to that person does not.',
        effect: {
          note: 'You leave them at base camp. The rope above is shorter and more honest.',
          hours: 6,
          move: 'hold',
          teamCondition: -4,
          scores: {
            teamwork: { label: 'You kept a sick climber out of the icefall', delta: 12, mark: 'cough-down' },
            judgment: { label: 'You separated hope from a cough', delta: 6, mark: 'cough-judgment' },
          },
        },
      },
      {
        label: 'A rest day, then another look',
        detail: 'No heroics and no instant answer.',
        effect: {
          note: 'You wait a day. The cough is still a fact in the morning.',
          hours: 18,
          move: 'hold',
          teamCondition: 2,
          health: 2,
          supplies: -3,
        },
      },
      {
        label: 'They can turn around if it gets worse',
        detail: 'Worse is a hard place to make a new plan.',
        effect: {
          note: 'You take them up on a promise to turn around later.',
          hours: 8,
          move: 'up',
          teamCondition: -8,
          health: -4,
          scores: {
            teamwork: { label: 'You carried a cough into the route', delta: -10, mark: 'cough-up' },
          },
        },
      },
    ],
  },
  {
    id: 'icefall-hour',
    category: 'objective',
    checkpoints: ['camp1'],
    phase: 'up',
    weight: 4,
    review: 'sme',
    title: 'The ice is moving',
    text: 'The game’s icefall is a hazard that punishes hurry and rewards patience. A real icefall is a place for guides, ladders, and judgment you do not get from a card. Do not treat this as a description of how to cross one.',
    choices: [
      {
        label: 'Cross in the cold, roped, and slow',
        detail: 'A longer morning. Less of the game’s hazard.',
        effect: {
          note: 'You cross while the game’s ice is quiet. It costs the morning.',
          hours: 8,
          move: 'up',
          energy: -6,
          objectiveRisk: -6,
          scores: {
            riskManagement: { label: 'You gave the icefall time instead of speed', delta: 10, mark: 'ice-slow' },
          },
        },
      },
      {
        label: 'Wait for a clearer view',
        detail: 'Warmer hands. A louder mountain, in this fiction.',
        effect: {
          note: 'You wait. The view improves. The clock does not.',
          hours: 10,
          move: 'hold',
          objectiveRisk: 4,
          energy: 3,
        },
      },
      {
        label: 'Sprint the middle',
        detail: 'Speed is not a strategy here. It is a wish.',
        effect: {
          note: 'You run the section the game marks as moving.',
          hours: 5,
          move: 'up',
          health: -10,
          teamCondition: -8,
          objectiveRisk: 12,
          scores: {
            riskManagement: { label: 'You sprinted a moving hazard', delta: -14, mark: 'ice-sprint' },
          },
        },
      },
    ],
  },
  {
    id: 'icefall-delay',
    category: 'delay',
    checkpoints: ['camp1'],
    phase: 'up',
    weight: 2,
    title: 'The route is a queue',
    text: 'Other parties are on the ladders. Waiting spends daylight. Pushing through spends the kind of patience that keeps people clipped in. This is a delay in a game, not traffic advice.',
    choices: [
      {
        label: 'Wait your turn',
        detail: 'The day shrinks. The rope team stays a rope team.',
        effect: {
          note: 'You wait. The ladders clear. The afternoon is shorter.',
          hours: 8,
          move: 'hold',
          energy: -3,
          supplies: -2,
          scores: {
            teamwork: { label: 'You kept the rope team intact in the queue', delta: 6, mark: 'queue' },
          },
        },
      },
      {
        label: 'Cross once the line thins, then stop',
        detail: 'One camp, and no more today.',
        effect: {
          note: 'You cross when there is room and you stop on the far side.',
          hours: 9,
          move: 'up',
          energy: -6,
          supplies: -2,
        },
      },
      {
        label: 'Pass them',
        detail: 'Faster, and ruder, and less clipped-in.',
        effect: {
          note: 'You pass. The minute you save is smaller than the mess you make.',
          hours: 6,
          move: 'up',
          teamCondition: -6,
          objectiveRisk: 8,
          scores: {
            teamwork: { label: 'You broke the line to gain an hour', delta: -8, mark: 'passed' },
          },
        },
      },
    ],
  },
  {
    id: 'camp2-fatigue',
    category: 'fatigue',
    checkpoints: ['camp2'],
    phase: 'up',
    weight: 3,
    title: 'The stove takes longer than the plan',
    text: 'Melting snow is the day’s real work. Hands are clumsy. The route above can wait more easily than a dehydrated team can, at least inside this game.',
    choices: [
      {
        label: 'Spend the day on water',
        detail: 'No progress. A team that has actually drunk.',
        effect: {
          note: 'You make water until the bottles are honest.',
          hours: 14,
          move: 'hold',
          energy: 6,
          health: 3,
          supplies: -3,
          scores: {
            preparation: { label: 'You spent a day making water', delta: 6, mark: 'water-day' },
          },
        },
      },
      {
        label: 'Drink what you have and move',
        detail: 'The route continues on a smaller margin.',
        effect: {
          note: 'You move on a half-melted plan.',
          hours: 9,
          move: 'up',
          energy: -8,
          health: -3,
        },
      },
      {
        label: 'Skip the melt and keep the hour',
        detail: 'The schedule stays. The headache will not.',
        effect: {
          note: 'You leave the stove for later. Later arrives as fatigue.',
          hours: 7,
          move: 'up',
          health: -8,
          energy: -10,
          scores: {
            judgment: { label: 'You skipped water for the schedule', delta: -10, mark: 'skipped-water' },
          },
        },
      },
    ],
  },
  {
    id: 'camp2-cache',
    category: 'supplies',
    checkpoints: ['camp2'],
    phase: 'up',
    weight: 2,
    title: 'A cache for the way down',
    text: 'What you bury here is what the descent eats. Carrying all of it makes today heavier and tomorrow simpler, until tomorrow is the walk out.',
    choices: [
      {
        label: 'Leave a cache',
        detail: 'You go up poorer, on purpose.',
        effect: {
          note: 'You leave food and fuel where the way down will look for them.',
          hours: 6,
          move: 'hold',
          supplies: -8,
          mark: 'cache',
          scores: {
            preparation: { label: 'You left a cache for the descent', delta: 12, mark: 'cached' },
          },
        },
      },
      {
        label: 'Carry it',
        detail: 'Heavier, and nothing hidden to forget.',
        effect: {
          note: 'You carry every meal. The shoulders file a complaint.',
          hours: 8,
          move: 'up',
          energy: -6,
          supplies: -1,
        },
      },
      {
        label: 'Eat a large meal and travel light',
        detail: 'Morale now. A thinner descent.',
        effect: {
          note: 'Dinner is generous. The descent’s pantry notices.',
          hours: 5,
          move: 'hold',
          supplies: -12,
          energy: 4,
          scores: {
            preparation: { label: 'You ate the descent', delta: -10, mark: 'ate-descent' },
          },
        },
      },
    ],
  },
  {
    id: 'camp2-turn',
    category: 'turnaround',
    checkpoints: ['camp2'],
    phase: 'up',
    weight: 3,
    title: 'Someone says the word down',
    text: 'Camp II is high enough for the mountain to feel real and low enough that down is still a walk, not a rescue, in this game. The summit is still several decisions away.',
    choices: [
      {
        label: 'Turn around from here',
        detail: 'A complete expedition that never gets a summit photo.',
        effect: {
          note: 'You turn around at Camp II. The top stays where it is.',
          hours: 6,
          move: 'retreat',
          scores: turned(4),
        },
      },
      {
        label: 'One more camp, then a hard look',
        detail: 'Go up with the turnaround still available.',
        effect: {
          note: 'You agree to look from the next camp, not to promise the top.',
          hours: 10,
          move: 'up',
          energy: -5,
          scores: {
            judgment: { label: 'You refused to promise the summit', delta: 4, mark: 'no-promise' },
          },
        },
      },
      {
        label: 'Down is what people say when they are tired',
        detail: 'You talk them out of it.',
        effect: {
          note: 'You talk the team out of the turn. They follow. That is not the same as agreeing.',
          hours: 8,
          move: 'up',
          teamCondition: -8,
          scores: {
            teamwork: { label: 'You overruled a turnaround', delta: -10, mark: 'overruled' },
            judgment: { label: 'You treated a turnaround as weakness', delta: -8, mark: 'weakness' },
          },
        },
      },
    ],
  },
  {
    id: 'camp3-oxygen',
    category: 'oxygen',
    checkpoints: ['camp3'],
    phase: 'up',
    weight: 4,
    review: 'sme',
    title: 'The bottles come out',
    text: 'Above this camp the game starts charging you for a thin oxygen reserve. When a real climber opens a bottle is a guide’s and a doctor’s decision. This card is not that decision.',
    choices: [
      {
        label: 'Use oxygen and slow down',
        detail: 'The reserve drops. The game’s strain drops with it.',
        effect: {
          note: 'You open the plan you carried. The pace gets dull and more survivable, in the game.',
          hours: 10,
          move: 'hold',
          oxygen: -14,
          health: 6,
          energy: 4,
          scores: {
            preparation: { label: 'You used oxygen as a reserve, not a trophy', delta: 8, mark: 'o2-use' },
          },
        },
      },
      {
        label: 'Climb a little, bottles closed',
        detail: 'Save them. Pay in fatigue.',
        effect: {
          note: 'The bottles stay shut. The team pays in pace.',
          hours: 9,
          move: 'up',
          energy: -8,
          health: -4,
        },
      },
      {
        label: 'Save every bottle for the summit photo',
        detail: 'The top gets the oxygen. The camp does not.',
        effect: {
          note: 'You save the bottles for a photograph you have not earned.',
          hours: 8,
          move: 'up',
          health: -8,
          energy: -8,
          scores: {
            judgment: { label: 'You saved oxygen for the summit photo', delta: -12, mark: 'o2-photo' },
          },
        },
      },
    ],
  },
  {
    id: 'camp3-night',
    category: 'fatigue',
    checkpoints: ['camp3'],
    phase: 'up',
    weight: 2,
    title: 'Nobody sleeps',
    text: 'The night is loud with wind and breathing. A summit push on no sleep is a game penalty. It is also a bad idea the game is not qualified to dosage.',
    choices: [
      {
        label: 'Stay another night',
        detail: 'Miss a window. Regain a team.',
        effect: {
          note: 'You stay. Sleep is partial. It is still more than none.',
          hours: 18,
          move: 'hold',
          energy: 8,
          supplies: -4,
          weatherRisk: 4,
          scores: {
            judgment: { label: 'You refused a sleepless summit push', delta: 8, mark: 'slept' },
          },
        },
      },
      {
        label: 'Move down to thicker air for the night',
        detail: 'Height, given back so people can sleep.',
        effect: {
          note: 'You drop down for the night. Pride stays at Camp III.',
          hours: 10,
          move: 'down',
          energy: 6,
          health: 3,
          scores: {
            riskManagement: { label: 'You traded height for a night of sleep', delta: 8, mark: 'sleep-down' },
          },
        },
      },
      {
        label: 'Leave for Camp IV anyway',
        detail: 'The window is a rumor you are willing to trust.',
        effect: {
          note: 'You go up tired. The game writes that down.',
          hours: 9,
          move: 'up',
          energy: -12,
          health: -6,
          teamCondition: -6,
          scores: {
            judgment: { label: 'You climbed on no sleep', delta: -10, mark: 'no-sleep' },
          },
        },
      },
    ],
  },
  {
    id: 'camp4-wind',
    category: 'weather',
    checkpoints: ['camp4'],
    phase: 'up',
    weight: 4,
    review: 'sme',
    title: 'The wind has weight',
    text: 'At this camp the game’s wind is a reason to dig in or go down. Real wind at a high camp is a reason to listen to the people leading the climb. This is not a wind limit to memorize.',
    choices: [
      {
        label: 'Dig in and wait',
        detail: 'Fuel and patience. No upward progress.',
        effect: {
          note: 'You dig in. The wind spends itself on the tent.',
          hours: 14,
          move: 'hold',
          weatherRisk: -10,
          supplies: -5,
          scores: {
            riskManagement: { label: 'You let the wind have the mountain', delta: 12, mark: 'dug-in' },
          },
        },
      },
      {
        label: 'Turn around in it',
        detail: 'Down is right. Down in this wind is expensive.',
        effect: {
          note: 'You turn around while you can still clip a descender.',
          hours: 8,
          move: 'retreat',
          health: -4,
          energy: -6,
          scores: turned(8),
        },
      },
      {
        label: 'Go up before it gets worse',
        detail: 'It is already worse.',
        effect: {
          note: 'You go up into the wind because waiting felt like losing.',
          hours: 8,
          move: 'up',
          health: -12,
          energy: -10,
          weatherRisk: 10,
          scores: {
            riskManagement: { label: 'You spent people against the wind', delta: -16, mark: 'wind-up' },
          },
        },
      },
    ],
  },
  {
    id: 'camp4-window',
    category: 'summit-window',
    checkpoints: ['camp4'],
    phase: 'up',
    weight: 4,
    title: 'The window is a few hours wide',
    text: 'Someone has circled a departure time. Leaving now is a summit bid. Leaving tomorrow may be nothing. Staying forever is how expeditions get famous for the wrong reason.',
    choices: [
      {
        label: 'Leave if everyone can still turn around',
        detail: 'A bid with the descent already agreed.',
        effect: {
          note: 'You leave with a turnaround that does not require a debate on the ridge.',
          hours: 8,
          move: 'up',
          oxygen: -8,
          energy: -6,
          scores: {
            judgment: { label: 'You set the turnaround before you left high camp', delta: 10, mark: 'window-set' },
          },
        },
      },
      {
        label: 'Wait one more report',
        detail: 'The window might close. The team might improve.',
        effect: {
          note: 'You wait for another report. The mountain does not owe you one.',
          hours: 12,
          move: 'hold',
          weatherRisk: 4,
          supplies: -3,
        },
      },
      {
        label: 'Leave now, and sort the descent at the top',
        detail: 'The top becomes the plan. The plan becomes late.',
        effect: {
          note: 'You leave the descent for the summit to solve.',
          hours: 8,
          move: 'up',
          oxygen: -6,
          teamCondition: -6,
          scores: {
            judgment: { label: 'You postponed the descent until the summit', delta: -12, mark: 'sort-later' },
          },
        },
      },
    ],
  },
  {
    id: 'camp4-partner',
    category: 'team',
    checkpoints: ['camp4'],
    phase: 'up',
    weight: 3,
    title: 'A partner is done',
    text: 'They can stand. They should not climb. The game will let you take them higher anyway, and then it will score that choice. A real decision here belongs to the guides and the person who is done.',
    choices: [
      {
        label: 'The summit bid is over for both of you',
        detail: 'You go down together.',
        effect: {
          note: 'You turn around with them. The summit bid ends as a team.',
          hours: 6,
          move: 'retreat',
          scores: {
            ...turned(8),
            teamwork: { label: 'You went down with the person who was done', delta: 14, mark: 'partner-down' },
          },
        },
      },
      {
        label: 'They stay with a watcher. Two continue.',
        detail: 'The team splits. Splits are how games get cruel.',
        effect: {
          note: 'You split the team. It is a smaller expedition than the one that left base camp.',
          hours: 8,
          move: 'up',
          teamCondition: -12,
          scores: {
            teamwork: { label: 'You split the team under the summit', delta: -8, mark: 'split' },
          },
        },
      },
      {
        label: 'Tell them they will feel better at the top',
        detail: 'They will not.',
        effect: {
          note: 'You talk them upward. The game is not impressed.',
          hours: 8,
          move: 'up',
          health: -8,
          teamCondition: -14,
          scores: {
            teamwork: { label: 'You took a finished climber higher', delta: -16, mark: 'dragged' },
          },
        },
      },
    ],
  },
  {
    id: 'summit-eighty',
    category: 'turnaround',
    checkpoints: ['summit'],
    phase: 'up',
    weight: 5,
    review: 'sme',
    title: 'The top is close enough to count',
    text: 'The game puts you near the summit with daylight already spending itself. Turning around here can outscore tagging the top. Nothing on this card is a turnaround time to use on a real ridge.',
    choices: [
      {
        label: 'Turn around short of the top',
        detail: 'The summit stays. The people come down.',
        effect: {
          note: 'You leave the last meters. The descent starts while hands still work.',
          hours: 6,
          move: 'retreat',
          scores: {
            judgment: { label: 'You left the last meters', delta: 18, mark: 'left-meters' },
            riskManagement: { label: 'You turned around on the summit day', delta: 12, mark: 'summit-turn' },
          },
        },
      },
      {
        label: 'Tag it and leave',
        detail: 'No speeches. Touch the top and turn.',
        effect: {
          note: 'You tag the top and turn around before it becomes a place you linger.',
          hours: 7,
          move: 'hold',
          oxygen: -8,
          energy: -6,
          mark: 'tagged',
          scores: {
            judgment: { label: 'You left the top while the day still existed', delta: 8, mark: 'tagged-left' },
          },
        },
      },
      {
        label: 'Stay until it feels real',
        detail: 'Pictures, a long minute, a darker descent.',
        effect: {
          note: 'You stay. The top feels real. The daylight leaves without you.',
          hours: 10,
          move: 'hold',
          oxygen: -12,
          energy: -12,
          health: -8,
          weatherRisk: 8,
          scores: {
            judgment: { label: 'You spent the summit', delta: -14, mark: 'spent-summit' },
            riskManagement: { label: 'You gave the descent away to the view', delta: -10, mark: 'spent-risk' },
          },
        },
      },
    ],
  },
  {
    id: 'summit-clock',
    category: 'summit-window',
    checkpoints: ['summit'],
    phase: 'up',
    weight: 3,
    when: (state) => state.marks.tagged === true && !state.retreating,
    title: 'You are still standing there',
    text: 'The tag happened. The game is waiting to see if you treat that as the end of the decision or the start of the descent.',
    choices: [
      {
        label: 'Down, now',
        detail: 'The summit is behind you. That is the correct direction.',
        effect: {
          note: 'You turn your back on the top.',
          hours: 6,
          move: 'retreat',
          scores: {
            riskManagement: { label: 'You started down as soon as the tag was done', delta: 8, mark: 'down-now' },
          },
        },
      },
      {
        label: 'One minute, then down',
        detail: 'Long enough to know you were here.',
        effect: {
          note: 'You give it a minute. Then the rope faces down.',
          hours: 7,
          move: 'retreat',
          energy: -3,
        },
      },
      {
        label: 'Wait for the light',
        detail: 'The light you want is the light the descent needed.',
        effect: {
          note: 'You wait for a prettier minute. The descent starts late.',
          hours: 10,
          move: 'retreat',
          health: -8,
          energy: -8,
          oxygen: -8,
          scores: {
            judgment: { label: 'You waited on the summit for the light', delta: -10, mark: 'waited-light' },
          },
        },
      },
    ],
  },
  {
    id: 'descent-sit',
    category: 'descent',
    checkpoints: ['descent'],
    phase: 'down',
    weight: 4,
    repeat: 'day',
    when: (state) => state.energy < 55 || state.teamCondition < 70,
    title: 'Someone sits on the descent',
    text: 'Sitting down on the way out is how a game expedition gets smaller. The route below is not close just because you say it is.',
    choices: [
      {
        label: 'Stop the team and warm them',
        detail: 'Height stays. The person gets an hour.',
        effect: {
          note: 'You stop the descent. The warm drink is the whole plan for this hour.',
          hours: 6,
          move: 'hold',
          energy: 6,
          teamCondition: 8,
          supplies: -3,
          scores: {
            teamwork: { label: 'You stopped the descent for someone who sat down', delta: 12, mark: 'descent-sat' },
          },
        },
      },
      {
        label: 'Short-rope them toward the next camp',
        detail: 'Move, together, and not fast.',
        effect: {
          note: 'You keep them in the rope and aim at the next place a person can lie down on purpose.',
          hours: 8,
          move: 'down',
          energy: -6,
          teamCondition: 2,
        },
      },
      {
        label: 'Tell them camp is close',
        detail: 'Close is a story.',
        effect: {
          note: 'You say camp is close. The person who sat down is still sitting, only lower.',
          hours: 7,
          move: 'down',
          teamCondition: -12,
          health: -6,
          scores: {
            teamwork: { label: 'You hurried a seated climber downhill', delta: -12, mark: 'hurried-down' },
          },
        },
      },
    ],
  },
  {
    id: 'descent-storm',
    category: 'weather',
    checkpoints: ['descent'],
    phase: 'down',
    weight: 4,
    urgent: true,
    repeat: 'day',
    when: (state) => state.weatherRisk >= 68,
    title: 'The descent disappears',
    text: 'Wind and snow take the horizon. Moving is how you get down. Moving blindly is how the game removes people. This is not a whiteout procedure.',
    choices: [
      {
        label: 'Stop until something has an edge',
        detail: 'You burn fuel. You do not invent a trail.',
        effect: {
          note: 'You stop. The whiteout keeps its secrets.',
          hours: 8,
          move: 'hold',
          weatherRisk: -6,
          supplies: -4,
          energy: -3,
          scores: {
            riskManagement: { label: 'You waited out the whiteout', delta: 10, mark: 'whiteout-wait' },
          },
        },
      },
      {
        label: 'Walk a bearing, counting out loud',
        detail: 'Slow, one person navigating, everyone else repeating.',
        effect: {
          note: 'You count paces. The slope arrives in pieces, which is enough to continue.',
          hours: 8,
          move: 'down',
          energy: -6,
          teamCondition: -2,
        },
      },
      {
        label: 'Move fast while downhill still feels downhill',
        detail: 'Downhill is a direction until it is a drop.',
        effect: {
          note: 'You hurry because waiting felt like dying. Hurry finds a drop.',
          hours: 5,
          move: 'down',
          health: -12,
          teamCondition: -10,
          scores: {
            riskManagement: { label: 'You rushed a blind descent', delta: -14, mark: 'rushed-white' },
          },
        },
      },
    ],
  },
  {
    id: 'descent-oxygen',
    category: 'oxygen',
    checkpoints: ['descent'],
    phase: 'down',
    weight: 3,
    review: 'sme',
    when: (state) => state.oxygen < 40 && state.altitude > 6000,
    title: 'The bottles are light',
    text: 'The reserve you argued about at the briefing is now a number near the bottom. Sharing it, saving it, or spending it is a game choice. It is not an oxygen plan for a real descent.',
    choices: [
      {
        label: 'Share what is left, evenly',
        detail: 'Nobody gets a full bottle. Nobody is skipped.',
        effect: {
          note: 'You split the last oxygen in the open.',
          hours: 6,
          move: 'down',
          oxygen: -10,
          teamCondition: 4,
          scores: {
            teamwork: { label: 'You shared the last oxygen', delta: 10, mark: 'share-o2' },
            preparation: { label: 'The oxygen plan lasted until the descent', delta: 4, mark: 'o2-lasted' },
          },
        },
      },
      {
        label: 'Give it to the weakest and keep moving',
        detail: 'Say the name. Take the smaller share.',
        effect: {
          note: 'The weakest climber gets the bottle. Everyone hears you say so.',
          hours: 7,
          move: 'down',
          oxygen: -12,
          health: 4,
          teamCondition: 6,
          scores: {
            teamwork: { label: 'You gave the last oxygen to the weakest climber', delta: 12, mark: 'o2-weak' },
          },
        },
      },
      {
        label: 'Keep a bottle for yourself',
        detail: 'A stronger leader. A worse team.',
        effect: {
          note: 'You keep a bottle. The rope learns the shape of that.',
          hours: 6,
          move: 'down',
          oxygen: -6,
          teamCondition: -12,
          scores: {
            teamwork: { label: 'You kept the last oxygen', delta: -14, mark: 'hoard-o2' },
          },
        },
      },
    ],
  },
  {
    id: 'descent-nav',
    category: 'objective',
    checkpoints: ['descent'],
    phase: 'down',
    weight: 2,
    title: 'The fixed lines are a rumor',
    text: 'You remember the route being somewhere to the left. Memory is not a map. In the game, building a careful descent costs time. Guessing costs people.',
    choices: [
      {
        label: 'Backtrack to the last thing you trust',
        detail: 'Slow. You do not invent a shortcut.',
        effect: {
          note: 'You go back to the last anchor you trust, then down from there.',
          hours: 8,
          move: 'down',
          energy: -4,
          objectiveRisk: -6,
          scores: {
            riskManagement: { label: 'You refused a shortcut on the descent', delta: 8, mark: 'no-shortcut' },
          },
        },
      },
      {
        label: 'Follow the old tracks',
        detail: 'Someone else thought this was down.',
        effect: {
          note: 'The tracks hold. You do not thank them out loud.',
          hours: 6,
          move: 'down',
          energy: -5,
        },
      },
      {
        label: 'Cut the corner',
        detail: 'Shorter, if the corner is still attached to the mountain.',
        effect: {
          note: 'The corner is not a trail. The rope finds that out.',
          hours: 5,
          move: 'down',
          health: -10,
          objectiveRisk: 10,
          scores: {
            riskManagement: { label: 'You cut a corner on the descent', delta: -12, mark: 'corner' },
          },
        },
      },
    ],
  },
  {
    id: 'cache-found',
    category: 'supplies',
    checkpoints: ['descent'],
    phase: 'down',
    weight: 4,
    when: (state) => state.marks.cache === true && state.altitude <= 6600 && state.marks.cacheTaken !== true,
    title: 'The cache is still there',
    text: 'The food you buried on the way up is a small, unromantic victory. Taking it is the point of having left it.',
    choices: [
      {
        label: 'Take it and keep descending',
        detail: 'The walk out gets a meal.',
        effect: {
          note: 'The cache is intact. The descent gets a meal it was promised.',
          hours: 5,
          move: 'down',
          supplies: 14,
          mark: 'cacheTaken',
          scores: {
            preparation: { label: 'The cache was there when you needed it', delta: 8, mark: 'cache-used' },
          },
        },
      },
      {
        label: 'Leave some for anyone still above',
        detail: 'You eat less. The mountain stays less empty.',
        effect: {
          note: 'You take half and leave the rest marked.',
          hours: 5,
          move: 'down',
          supplies: 7,
          teamCondition: 3,
          mark: 'cacheTaken',
          scores: {
            teamwork: { label: 'You left part of the cache for anyone still above', delta: 6, mark: 'cache-share' },
          },
        },
      },
    ],
  },
];

export const SME_REVIEW_IDS = EVEREST_EVENTS.filter((event) => event.review === 'sme').map((event) => event.id);
