// Interactive camp content. Positions are world px on a 1500 × 760 plate.
// Dialogue is flavour and explanation only: nothing here changes an engine
// value. Lines marked `engine` reuse an existing camp beat (Expedition.tend,
// medicate, play_routine) and in Godot must call that function, not a copy.

import { Look } from '../data/cosmetics'
import type { CampPhase } from '../state/Expedition'
import type { HeroPose } from '../components/Hero'

export const CAMP_W = 1500
export const CAMP_H = 760
export const CAMP_PLATE = 'https://cdn.magicpatterns.com/patterns/generated-images/36fec7fd-213b-47d7-8ec9-d8227d90a7c0.jpg'
export const VIEWPOINT_IMG = 'https://cdn.magicpatterns.com/patterns/generated-images/5972df57-6834-419c-9114-ae23424b233d.jpg'
export const BOUNDS = { x0: 110, x1: 1410, y0: 190, y1: 650 }

export type SpotKind = 'tent' | 'guide' | 'equipment' | 'campfire' | 'viewpoint' | 'exit' | 'npc'
export interface Spot { id: string; kind: SpotKind; x: number; y: number; label: string; verb: string; r?: number }

export const SPOTS: Spot[] = [
  { id: 'tent', kind: 'tent', x: 300, y: 330, label: 'Your tent', verb: 'Open' },
  { id: 'guide', kind: 'guide', x: 1060, y: 318, label: "Guide's table", verb: 'Plan' },
  { id: 'equipment', kind: 'equipment', x: 570, y: 500, label: 'Gear and supplies', verb: 'Inspect' },
  { id: 'campfire', kind: 'campfire', x: 430, y: 600, label: 'Campfire', verb: 'Sit' },
  { id: 'viewpoint', kind: 'viewpoint', x: 1330, y: 218, label: 'Viewpoint', verb: 'Look' },
  { id: 'exit', kind: 'exit', x: 1400, y: 600, label: 'Trail to Barafu', verb: 'Leave' },
]

/** Solid things the player walks around: [x, y, radius]. */
export const COLLIDERS: [number, number, number][] = [
  [300, 290, 52], [180, 250, 44], [440, 250, 44], [780, 240, 70], [1060, 300, 26], [430, 600, 26], [880, 500, 26], [700, 600, 34], [570, 470, 26],
]

export interface Topic { q: string; a: string[]; engine?: string }
export interface Npc {
  id: string; name: string; role: string; look: Look; support?: boolean
  at: Record<CampPhase, { x: number; y: number; pose: HeroPose; facing: 1 | -1; doing: string; asleep?: boolean; patrol?: [number, number] }>
  greet: Record<CampPhase, string>
  topics: Topic[]
}

const L = (o: Partial<Look>): Look => ({
  jacket: '#6f7a3f', jacketTrim: '#4f5a2c', headwear: 'beanie', headwearColor: '#e9c46a', pack: 'none', packColor: '#3a342c',
  harness: '#1f3d34', chalkBag: '#d8c7a4', bagPattern: 'plain', rope: '#d9572b', skin: '#7a4a2e', hair: '#1c1410', ...o,
})

export const NPCS: Npc[] = [
  {
    id: 'lena', name: 'Lena', role: 'Expedition guide',
    look: L({ jacket: '#3f6f8a', jacketTrim: '#2c5068', headwear: 'beanie', headwearColor: '#e9c46a', skin: '#7a4a2e' }),
    at: {
      day: { x: 1020, y: 330, pose: 'talk', facing: 1, doing: 'Reading the sky over the ridge' },
      evening: { x: 470, y: 560, pose: 'talk', facing: -1, doing: 'Briefing the team at the fire' },
      night: { x: 1090, y: 330, pose: 'idle', facing: 1, doing: 'Checking the stars and the wind' },
    },
    greet: {
      day: 'The ridge to Barafu is dry. Cloud comes up from the south after midday. That is the clock we walk to.',
      evening: 'Eat, drink, sleep. Tomorrow is decided at breakfast, not tonight.',
      night: 'Clear. Cold. The wind is from the west. Go to sleep; I will wake you if it changes.',
    },
    topics: [
      { q: 'What is the next route?', a: ['Karanga to Barafu is a short ridge walk: about 600 metres up, four or five hours.', 'There is a fork on the ridge. The upper line is shorter and open to the wind. The lower line is sheltered and longer.'] },
      { q: 'How is the weather?', a: ['Wind from the west, building in the afternoon. On the map it shows as wind; the engine already counts it in "Bad weather".', 'If cloud sits on the ridge we wait for it at the cairn, not in the gully.'] },
      { q: 'What are the risks?', a: ['Marco is tired, Jun has a headache. Height on top of that is how small problems grow.', 'The extra day here is the margin. Spending it is a decision, not a schedule.'] },
      { q: 'Prepare for departure', a: ['When you are ready, the decision is at my table. Nothing leaves this camp without it.'], engine: 'Opens the existing camp decision (same card as the map)' },
    ],
  },
  {
    id: 'marco', name: 'Marco', role: 'Climber',
    look: L({ jacket: '#a8432a', jacketTrim: '#7e3520', headwear: 'sunhat', headwearColor: '#d8c7a4', skin: '#e0b48e', hair: '#5a3a22' }),
    at: {
      day: { x: 200, y: 340, pose: 'sit', facing: 1, doing: 'Resting outside his tent' },
      evening: { x: 380, y: 600, pose: 'sit', facing: 1, doing: 'Warming his hands at the fire' },
      night: { x: 180, y: 300, pose: 'sit', facing: 1, doing: 'Asleep', asleep: true },
    },
    greet: { day: 'Slept badly after the wall. Legs are fine. Head is loud.', evening: 'Baraka\'s soup fixed half of me.', night: '' },
    topics: [
      { q: 'How are you feeling?', a: ['Tired. Not sick. I can tell the difference today; ask me again at Barafu.'] },
      { q: 'Any worries?', a: ['That I will say "fine" on summit night because everyone else is going. Watch me if I go quiet.'] },
      { q: 'How far have we come?', a: ['Six days, Londorossi to Karanga. The wall felt like the middle. Lena says the middle is tomorrow.'] },
      { q: 'Tell me about your climbing', a: ['Limestone at home, sport routes. Up here my arms are useless and my lungs are everything.'] },
      { q: 'Sit with Marco', a: ['You sit together for a while. He talks about home.'], engine: 'Existing camp beat Expedition.tend("marco"): the engine applies its own effect' },
    ],
  },
  {
    id: 'jun', name: 'Jun', role: 'Doctor',
    look: L({ jacket: '#c98a2e', jacketTrim: '#94621c', headwear: 'beanie', headwearColor: '#2d5a4b', skin: '#d9a77c', hair: '#1c1915' }),
    at: {
      day: { x: 470, y: 590, pose: 'sit', facing: -1, doing: 'Writing in his medical notes' },
      evening: { x: 470, y: 640, pose: 'sit', facing: -1, doing: 'Counting the medicine kit' },
      night: { x: 440, y: 290, pose: 'sit', facing: 1, doing: 'Asleep', asleep: true },
    },
    greet: { day: 'Mild altitude headache. One dose given. I am watching it, not ignoring it.', evening: 'Two doses left of four. That number matters more than my headache.', night: '' },
    topics: [
      { q: 'How is your headache?', a: ['Better than this morning. If it is worse after sleeping higher, I go down. That is the rule I would give a patient.'] },
      { q: 'What should I watch for?', a: ['Anyone who stops eating, stumbles on flat ground, or goes quiet. Those are reasons to stop the day.', 'In this game that is a reason, not a diagnosis.'] },
      { q: 'The medicine kit', a: ['Two doses of four. Use one now and there is one for summit night.'], engine: 'Existing Expedition.medicate(): shown in the Team tab today' },
    ],
  },
  {
    id: 'baraka', name: 'Baraka', role: 'Expedition cook', support: true,
    look: L({ jacket: '#2d5a4b', jacketTrim: '#1f3d34', headwear: 'cap', headwearColor: '#f3efe6', skin: '#5e3a24', hair: '#120c08' }),
    at: {
      day: { x: 860, y: 500, pose: 'work', facing: 1, doing: 'Cooking lunch on the stove' },
      evening: { x: 860, y: 500, pose: 'work', facing: 1, doing: 'Serving dinner from the big pot' },
      night: { x: 860, y: 500, pose: 'work', facing: 1, doing: 'Boiling water for the morning' },
    },
    greet: {
      day: 'Lunch is rice and beans with greens. Eat it even if you are not hungry. At this height the body forgets to ask.',
      evening: 'Soup first, then the rest. Hot water bottles are by the mess tent.',
      night: 'Water for tomorrow\'s bottles. It takes a long time to boil up here.',
    },
    topics: [
      { q: 'What are you cooking?', a: ['Rice, beans, greens and ginger tea. Simple food that stays down when you are high.'] },
      { q: 'How long have you worked on the mountain?', a: ['Eleven seasons. I started as a porter, then assistant cook, then this. I know every kitchen spot from the gate to Barafu.'] },
      { q: 'What makes a good camp kitchen?', a: ['Wind behind a rock, water close, and nobody standing in my way when the pot is full.'] },
    ],
  },
  {
    id: 'neema', name: 'Neema', role: 'Porter',
    look: L({ jacket: '#6f9fbf', jacketTrim: '#4a7593', headwear: 'beanie', headwearColor: '#a8432a', skin: '#6b4128', hair: '#120c08', pack: 'expedition', packColor: '#3a342c' }),
    at: {
      day: { x: 700, y: 560, pose: 'walk', facing: 1, doing: 'Carrying water from the stream to the supply store', patrol: [640, 940] },
      evening: { x: 520, y: 620, pose: 'sit', facing: -1, doing: 'Eating with the team at the fire' },
      night: { x: 760, y: 240, pose: 'sit', facing: 1, doing: 'Asleep in the crew tent', asleep: true },
    },
    greet: {
      day: 'Water run. The stream is ten minutes down; we filter and boil everything.',
      evening: 'Long day. Good food. Tomorrow we break camp before you finish breakfast.',
      night: '',
    },
    topics: [
      { q: 'What does your day look like?', a: ['Break camp, carry to the next one, set it up before you arrive. Then water, then food, then sleep.'] },
      { q: 'How heavy is a load?', a: ['Every load is weighed at the gate. The park sets a limit and our company keeps it. A fair load is how we get home well.'] },
      { q: 'Have you been to the summit?', a: ['Four times. The first time I cried at Stella Point. Now I mostly think about getting everyone down.'] },
    ],
  },
  {
    id: 'joseph', name: 'Joseph', role: 'Assistant guide', support: true,
    look: L({ jacket: '#4c5866', jacketTrim: '#2f3742', headwear: 'beanie', headwearColor: '#6f7a3f', skin: '#4f3020', hair: '#120c08' }),
    at: {
      day: { x: 600, y: 520, pose: 'crouch', facing: -1, doing: 'Checking the short rope and the helmets' },
      evening: { x: 760, y: 320, pose: 'work', facing: 1, doing: 'Hanging lanterns at the mess tent' },
      night: { x: 1000, y: 360, pose: 'idle', facing: 1, doing: 'Doing the night check with a headlamp' },
    },
    greet: {
      day: 'Rope, helmets, gloves. If it fails on summit night it failed here first.',
      evening: 'Lanterns up. Nobody walks between the tents in the dark without one.',
      night: 'Night check. I count headlamps and fingers.',
    },
    topics: [
      { q: 'What are you checking?', a: ['The short rope we use on the descent, and every helmet strap. Small things break in the cold.'] },
      { q: 'How did you become a guide?', a: ['Porter first, like most of us. Then the guide course in Moshi, first aid, and years walking behind guides like Lena.'] },
      { q: 'Advice for tomorrow?', a: ['Walk slower than you think you need to. Drink before you are thirsty. Tell me early, not late.'] },
    ],
  },
]

export const PHASE_COPY: Record<CampPhase, { name: string; light: string }> = {
  day: { name: 'Daytime', light: 'Sun high, wind from the west' },
  evening: { name: 'Evening', light: 'Low gold light, the fire lit' },
  night: { name: 'Night', light: 'Stars, lanterns and headlamps' },
}
