// Checkpoints, party and two events copied from
// godot/modes/expedition/data/kilimanjaro.json. Map positions (x, y in % of
// the map plate) and risk bands are prototype values; in Godot the risk band
// comes from the engine's preview, never from the UI.

export interface Camp {
  id: string
  name: string
  meters: number
  x: number
  y: number
  zone: string
  challenge?: string
}

export const CAMPS: Camp[] = [
  { id: 'briefing', name: 'Londorossi Gate', meters: 2100, x: 9, y: 86, zone: 'Rainforest' },
  { id: 'approach', name: 'Mti Mkubwa Camp', meters: 2780, x: 18, y: 73, zone: 'Rainforest' },
  { id: 'ebc', name: 'Shira 1 Camp', meters: 3500, x: 23, y: 57, zone: 'Moorland' },
  { id: 'camp1', name: 'Shira 2 Camp', meters: 3850, x: 32, y: 47, zone: 'Moorland', challenge: 'Lava Tower' },
  { id: 'camp2', name: 'Barranco Camp', meters: 3960, x: 52, y: 58, zone: 'Alpine desert', challenge: 'Barranco Wall' },
  { id: 'camp3', name: 'Karanga Camp', meters: 4035, x: 70, y: 52, zone: 'Alpine desert' },
  { id: 'camp4', name: 'Barafu Camp', meters: 4640, x: 77, y: 34, zone: 'Alpine desert', challenge: 'Summit night' },
  { id: 'summit', name: 'Uhuru Peak', meters: 5895, x: 64, y: 11, zone: 'Summit' },
]

/**
 * Played climbs on the map. `godot` says what exists in the repo today:
 *  - implemented: a ClimbLevel with a spec already ships (lava_tower, barranco, summit_night, descent).
 *  - proposed: no level exists. Karanga Ridge is new content AND new mechanics.
 * `encounter` links a mark to its Phase 2 playable prototype.
 */
export type EncounterId = 'barranco-wall' | 'karanga-ridge' | 'summit-approach'
export const CHALLENGE_MARKS: { id: string; name: string; x: number; y: number; stars: number; done: boolean; godot: 'implemented' | 'proposed'; encounter?: EncounterId }[] = [
  { id: 'lava-tower', name: 'Lava Tower', x: 43, y: 31, stars: 2, done: true, godot: 'implemented' },
  { id: 'barranco-wall', name: 'Barranco Wall', x: 60, y: 50, stars: 3, done: true, godot: 'implemented', encounter: 'barranco-wall' },
  { id: 'karanga-ridge', name: 'Karanga Ridge', x: 74, y: 44, stars: 0, done: false, godot: 'proposed', encounter: 'karanga-ridge' },
  { id: 'summit-night', name: 'Summit approach', x: 71, y: 22, stars: 0, done: false, godot: 'implemented', encounter: 'summit-approach' },
]

export const ENCOUNTERS: Record<EncounterId, { name: string; from: number; to: number; godot: string; axis: string }> = {
  'barranco-wall': { name: 'Barranco Wall', from: 4, to: 5, godot: 'Level exists (barranco.gd). Hold-choice faces are a new mechanic.', axis: 'Vertical · holds · exposure' },
  'karanga-ridge': { name: 'Karanga Ridge', from: 5, to: 6, godot: 'No level exists. Proposed ClimbLevel on the APK platformer kit, plus bottles and cloud.', axis: 'Solo traverse · water · route split' },
  'summit-approach': { name: 'Summit approach', from: 6, to: 7, godot: 'Level exists (summit_night.gd). Breathing, lamp cone and the summit reunion are proposed.', axis: 'Solo night climb · breath · reunion' },
}

export const CURRENT_INDEX = 5 // Karanga

export type MemberState = 'ok' | 'tired' | 'sick' | 'down'
export interface Member { id: string; name: string; role: string; state: MemberState; note: string; color: string }

export const PARTY: Member[] = [
  { id: 'lena', name: 'Lena', role: 'Guide', state: 'ok', note: 'Steady. Reading the ridge.', color: '#3f6f8a' },
  { id: 'marco', name: 'Marco', role: 'Climber', state: 'tired', note: 'Slept badly after the wall.', color: '#a8432a' },
  { id: 'you', name: 'You', role: 'Lead', state: 'ok', note: 'Fine. Hands cold.', color: '#6f7a3f' },
  { id: 'jun', name: 'Jun', role: 'Doctor', state: 'sick', note: 'Mild altitude headache. 1 dose given.', color: '#c98a2e' },
]

export type StatKey = 'health' | 'energy' | 'acclimatization' | 'teamCondition' | 'supplies' | 'weatherRisk' | 'objectiveRisk'
export const STATS: { key: StatKey; label: string; badHigh: boolean }[] = [
  { key: 'health', label: 'Health', badHigh: false },
  { key: 'energy', label: 'Energy', badHigh: false },
  { key: 'acclimatization', label: 'Used to height', badHigh: false },
  { key: 'teamCondition', label: 'Team spirit', badHigh: false },
  { key: 'supplies', label: 'Food & supplies', badHigh: false },
  { key: 'weatherRisk', label: 'Bad weather', badHigh: true },
  { key: 'objectiveRisk', label: 'Falling rocks', badHigh: true },
]

export const START_STATS: Record<StatKey, number> = {
  health: 72, energy: 58, acclimatization: 61, teamCondition: 66, supplies: 54, weatherRisk: 38, objectiveRisk: 22,
}

export interface Choice {
  label: string
  detail: string
  note: string
  hours: number
  move: 'up' | 'hold' | 'retreat' | 'summit' | 'down'
  /** Prototype stand-in for Expedition.playable(): which encounter this choice opens. */
  climb?: EncounterId
  deltas: Partial<Record<StatKey, number>>
  risk: 'low' | 'med' | 'high'
  riskWhy: string
}

export interface KiliEvent { id: string; camp: string; title: string; text: string; choices: Choice[] }

export const GATE_EVENT: KiliEvent = {
  id: 'kili-gate', camp: 'briefing', title: 'Ten days, if you use them',
  text: 'Londorossi Gate. The forest starts here, and Uhuru is nine sleeps away if you spend the days on the body instead of the photograph. The team is waiting to hear what this expedition is for.',
  choices: [
    { label: 'Walk the forest and set camp', detail: 'A full day to Big Tree. Camp as the light goes.', note: 'You walk the montane forest and reach Mti Mkubwa as the light goes.',
      hours: 12, move: 'up', deltas: { energy: -6, acclimatization: 2 }, risk: 'low', riskWhy: 'A gentle first day' },
    { label: 'Push the forest to gain a day', detail: 'Higher tonight. A thinner team in the morning.', note: 'You push through the forest.',
      hours: 14, move: 'up', deltas: { energy: -14, teamCondition: -6 }, risk: 'med', riskWhy: 'Rushing day one' },
    { label: 'The aim is to come back', detail: 'No height yet. The sentence is the decision.', note: 'You name the return as the aim.',
      hours: 1, move: 'hold', deltas: { teamCondition: 4 }, risk: 'low', riskWhy: 'Sets the aim' },
  ],
}

export const EVENTS: KiliEvent[] = [
  {
    id: 'kili-karanga-day', camp: 'camp3', title: 'The extra day',
    text: 'Morning at Karanga. On the ten-day walk this day is not for Barafu. It is a short hike above camp, then the same tents again. Skipping it is how a shorter route gets made.',
    choices: [
      { label: 'Take the extra day', detail: 'Walk above camp. Sleep here again.', note: 'You walk above Karanga and come back to the same tents for the night.',
        hours: 24, move: 'hold', deltas: { supplies: -1, teamCondition: 4, acclimatization: 6 }, risk: 'low', riskWhy: 'Climb high, sleep low' },
      { label: 'Push on tired to Barafu', detail: 'High camp tonight. The rest day disappears.', note: 'You break Karanga early and pitch at Barafu on tired legs.',
        hours: 14, move: 'up', climb: 'karanga-ridge', deltas: { energy: -12, teamCondition: -8, acclimatization: 1, supplies: -1 }, risk: 'high', riskWhy: 'Marco tired · Jun unwell · +605 m' },
      { label: 'Walk out from here', detail: 'Barafu and Uhuru stay ahead. The team turns down.', note: 'You leave Karanga for the walk out.',
        hours: 8, move: 'retreat', deltas: {}, risk: 'low', riskWhy: 'Ends the ascent' },
    ],
  },
  {
    id: 'kili-karanga-break', camp: 'camp3', title: 'Break camp for high camp',
    text: 'The extra night is done. Barafu is a short, dry walk up the ridge. The tents there are the last ones before the summit bid.',
    choices: [
      { label: 'Break camp for Barafu', detail: 'Pitch high as the light goes. Do not start up tonight.', note: 'You walk up to Barafu and pitch as the light goes.',
        hours: 12, move: 'up', climb: 'karanga-ridge', deltas: { energy: -6, acclimatization: 3 }, risk: 'med', riskWhy: '+605 m · wind on the ridge' },
      { label: 'Keep the rest going', detail: 'Another day in the same valley.', note: 'You keep the Karanga tents up for one more day.',
        hours: 24, move: 'hold', deltas: { supplies: -3, teamCondition: 2 }, risk: 'low', riskWhy: 'Food runs lower' },
      { label: 'Turn around after the rest', detail: 'The rest was the decision. Down starts now.', note: 'You turn around after the day at Karanga.',
        hours: 8, move: 'retreat', deltas: {}, risk: 'low', riskWhy: 'Ends the ascent' },
    ],
  },
]

// Copied from kilimanjaro.json (kili-wall, kili-barafu-rest, kili-hard-hour,
// kili-uhuru). Oxygen deltas are omitted because the prototype has no oxygen
// meter; the engine keeps them. Score ledger entries are engine-side only.
export const WALL_EVENT: KiliEvent = {
  id: 'kili-wall', camp: 'camp2', title: 'The Barranco Wall',
  text: 'The tents at Barranco come down after breakfast. The wall is a steep morning walk, not a climb, and cloud builds on it by early afternoon. The day is short on purpose. Karanga is where the tents go up, as the light goes.',
  choices: [
    { label: 'Climb the wall and camp at Karanga', detail: 'A short day. Camp pitched in the valley beyond.', note: 'You take the wall in the morning and pitch at Karanga as the light goes.',
      hours: 12, move: 'up', climb: 'barranco-wall', deltas: { energy: -8, acclimatization: 4, teamCondition: 2 }, risk: 'med', riskWhy: 'Played climb · cloud by afternoon' },
    { label: 'Rest beneath the wall', detail: 'Another night at Barranco. The wall can wait.', note: 'You leave the tents up at Barranco and take the day.',
      hours: 24, move: 'hold', deltas: { supplies: -2, teamCondition: 4 }, risk: 'low', riskWhy: 'Food runs lower' },
    { label: 'Turn around in the valley', detail: 'The wall stays unclimbed. The team starts down.', note: 'You turn around in the Barranco valley.',
      hours: 8, move: 'retreat', deltas: {}, risk: 'low', riskWhy: 'Ends the ascent' },
  ],
}

export const BARAFU_EVENT: KiliEvent = {
  id: 'kili-barafu-rest', camp: 'camp4', title: 'The rest day at Barafu',
  text: 'Morning on the ridge. On this ten-day game, today is empty on purpose: water, food, and a team that is not already spent. The bid is a midnight problem, not a morning one.',
  choices: [
    { label: 'Rest the day', detail: 'No height. The bid waits until the next night.', note: 'You keep the team in the Barafu tents until the night of the bid.',
      hours: 15, move: 'hold', deltas: { supplies: -1, energy: 4, teamCondition: 4, acclimatization: 6 }, risk: 'low', riskWhy: 'The summit bid is not the arrival' },
    { label: 'Start for the summit tonight', detail: 'Uhuru on the day you arrived. The rest is gone.', note: 'You leave Barafu without the empty day.',
      hours: 18, move: 'summit', climb: 'summit-approach', deltas: { energy: -16, health: -4, teamCondition: -6, supplies: -2 }, risk: 'high', riskWhy: 'No rest day · +1,255 m' },
    { label: 'The summit can wait forever', detail: 'Turn the camp around. The walk out is the result.', note: 'You turn the expedition around at Barafu.',
      hours: 8, move: 'retreat', deltas: {}, risk: 'low', riskWhy: 'Ends the ascent' },
  ],
}

export const HARD_HOUR_EVENT: KiliEvent = {
  id: 'kili-hard-hour', camp: 'camp4', title: 'The hard hour',
  text: 'Midnight, in this game. The bid is loose ground and a cold wind, and the hour before dawn is when someone wants to go faster just to feel warmer. Keep the pace and the summit stays a visit. Speed spends the team.',
  choices: [
    { label: 'Keep the pace through the dark', detail: 'Slow. Stella Point at dawn. Uhuru is a visit.', note: 'You keep the pace through the dark, pass Stella Point as the light comes, and stand on Uhuru.',
      hours: 8, move: 'summit', climb: 'summit-approach', deltas: { energy: -12, supplies: -1 }, risk: 'med', riskWhy: 'Played climb · cold and wind' },
    { label: 'Speed up to get warm', detail: 'Faster on the scree. A thinner team at the top.', note: 'You speed up in the cold. The team arrives at Uhuru spent.',
      hours: 6, move: 'summit', climb: 'summit-approach', deltas: { energy: -16, health: -4, teamCondition: -8, supplies: -1 }, risk: 'high', riskWhy: 'Pace breaks in the cold' },
    { label: 'Turn the bid around', detail: 'The rest was enough. Down is the decision.', note: 'You turn the bid around in the dark.',
      hours: 4, move: 'retreat', deltas: {}, risk: 'low', riskWhy: 'Ends the ascent' },
  ],
}

export const UHURU_EVENT: KiliEvent = {
  id: 'kili-uhuru', camp: 'summit', title: 'The top is not the end',
  text: 'Uhuru, in this game. The photograph is the easy part. Mweka Camp is still a long walk down, and a summit that stays up here is not a finished expedition.',
  choices: [
    { label: 'Turn down while you still can', detail: 'Leave the summit. Sleep much lower, at Mweka.', note: 'You leave Uhuru and walk down until the tents go up at Mweka in the dark.',
      hours: 13, move: 'down', deltas: { energy: -10, supplies: -1, teamCondition: 2 }, risk: 'low', riskWhy: 'Opens the descent' },
    { label: 'A photograph, then down', detail: 'A few minutes. Then the same long walk to Mweka.', note: 'You take the photograph and start down to Mweka.',
      hours: 12, move: 'down', deltas: { energy: -8, supplies: -1 }, risk: 'low', riskWhy: 'Opens the descent' },
    { label: 'Stay on the summit', detail: 'More time up here. Less margin for the walk down.', note: 'You stay on the summit. In this game, that spends the team.',
      hours: 4, move: 'hold', deltas: { health: -8, energy: -8 }, risk: 'high', riskWhy: 'The descent loses its hour' },
  ],
}

export const EXP_ROUTES = [
  { id: 'lemosho', name: 'Lemosho', days: 13, label: 'Gentle', text: 'The long way round. More nights to get used to height; more slips allowed; full stores.' },
  { id: 'machame', name: 'Machame', days: 9, label: 'Standard', text: 'Fewer spare days. The extra day at Karanga still matters.' },
  { id: 'umbwe', name: 'Umbwe', days: 8, label: 'Steep', text: 'Starts high and climbs fast. Few slips allowed, thin stores. For leaders who already know the mountain.' },
]

export const PACK = {
  medicine: 2, medicineMax: 4, snacks: 3, artifacts: 5,
  gear: [
    { id: 'poles', label: 'Poles', found: true },
    { id: 'gloves', label: 'Gloves', found: true },
    { id: 'goggles', label: 'Goggles & buff', found: false },
    { id: 'crampons', label: 'Crampons', found: false },
    { id: 'headlamp', label: 'Headlamp', found: true },
  ],
}
