// Mirrors godot/modes/crag/crag.gd ROUTES and logbook.gd CHALLENGES.
// Route lines (`path`) are prototype topo drawings, not the real route maps.

export interface Route {
  id: string
  name: string
  grade: string
  level: string
  skill: string
  text: string
  crux: string
  bolts: number
  heightM: number
  firstBoltM: number
  longestM: number
  falls: number
  challenge: [string, string]
  path: string
  tagX: number
  tagY: number
  daily?: boolean
}

export interface RouteProgress {
  attempts: number
  sends: number
  best: '' | 'onsight' | 'flash' | 'redpoint' | 'top'
  bestSeconds: number
  stars: number
  highBolt: number
}

export const STYLE_LABEL: Record<string, string> = {
  onsight: 'Onsight', flash: 'Flash', redpoint: 'Redpoint', top: 'Top with falls', '': 'Not topped',
}

export const ROUTES: Route[] = [
  { id: 'first-climb', name: 'First Climb', grade: 'Lesson', level: 'how to play', skill: 'The basics', bolts: 3, heightM: 12, firstBoltM: 2.4, longestM: 3.2, falls: 9,
    text: 'A short climb that shows you everything, one thing at a time. Take your time.', crux: 'Nothing hard: this one is for learning.',
    challenge: ['No falls', 'Climb the lesson without falling.'], path: 'M70 384 C 74 340, 66 300, 76 262', tagX: 76, tagY: 254 },
  { id: 'warm-up', name: 'Warm-up Wall', grade: '4', level: 'easy', skill: 'Clip, rest, repeat', bolts: 6, heightM: 18, firstBoltM: 2.4, longestM: 2.8, falls: 5,
    text: 'Good rock with pockets and one big hold halfway. Clip each bolt from a good hold and rest before you need to.', crux: 'Two short bits of tiny holds.',
    challenge: ['Good clips', 'Send it, clipping every bolt from a good hold.'], path: 'M118 384 C 126 320, 112 260, 124 200', tagX: 124, tagY: 192 },
  { id: 'sundown', name: 'Sundown Traverse', grade: '5b', level: 'moderate', skill: 'Slow and steady', bolts: 4, heightM: 22, firstBoltM: 4.8, longestM: 5.6, falls: 5,
    text: 'Up, then a long move sideways across slopers. Move slowly and pause to let your grip settle. Few bolts and a high first one.', crux: 'The slopers on the traverse, a long way above the last bolt.',
    challenge: ['Feather touch', 'Send it without your grip on the slopers dropping below a third.'], path: 'M168 384 C 172 330, 160 300, 172 270 C 200 250, 236 252, 252 236 C 262 200, 250 170, 258 140', tagX: 258, tagY: 132 },
  { id: 'the-pinch', name: 'The Pinch', grade: '6a', level: 'hard', skill: 'Squeeze timing', bolts: 8, heightM: 24, firstBoltM: 2.4, longestM: 2.4, falls: 4,
    text: 'Four stretches of tiny holds, the longest at the top. Squeeze GRIP once when the meter drops below half. Bolts close together all the way.', crux: 'The last stretch of tiny holds. Stopping on them drains you.',
    challenge: ['Economy', 'Send it clean without a wasted squeeze.'], path: 'M214 384 C 222 320, 204 250, 216 190 C 222 150, 210 110, 218 76', tagX: 218, tagY: 68 },
  { id: 'leap-of-faith', name: 'Leap of Faith', grade: '6b', level: 'harder', skill: 'The leap', bolts: 6, heightM: 26, firstBoltM: 3.2, longestM: 4.4, falls: 4,
    text: 'Above a big hold the rock is blank: press JUMP to leap. A ring closes on the hold: tap GRIP once as it closes.', crux: 'The catch, then tiny holds.',
    challenge: ['Stick it', 'Send it clean with a perfect catch on the leap.'], path: 'M276 384 C 282 330, 270 280, 284 230 C 290 190, 296 150, 300 96', tagX: 300, tagY: 88 },
  { id: 'lions-roof', name: "Lion's Roof", grade: '6c', level: 'very hard', skill: 'Steep ground', bolts: 8, heightM: 26, firstBoltM: 2.4, longestM: 3.2, falls: 3,
    text: 'Tiny holds off the ground, then sideways under a roof on pockets. A big hold, a leap, and long tiny holds to the top.', crux: 'The roof, then six rows of tiny holds.',
    challenge: ['No sitting', 'Send it without resting on the rope once.'], path: 'M330 384 C 336 330, 326 290, 340 250 C 362 236, 380 232, 390 200 C 394 160, 386 120, 392 70', tagX: 392, tagY: 62 },
  { id: 'thunderhead', name: 'Thunderhead', grade: '7a', level: 'hardest', skill: 'All of it, run-out', bolts: 5, heightM: 30, firstBoltM: 4.0, longestM: 7.2, falls: 3,
    text: 'Two leaps across blank rock, a roof, slopers, long stretches of tiny holds and only three big holds. Few bolts, the top ones very far apart.', crux: 'A fall up there is a big one.',
    challenge: ['Lightning', 'Send it clean with both catches perfect.'], path: 'M378 384 C 392 320, 420 270, 430 210 C 440 160, 428 100, 440 40', tagX: 440, tagY: 34 },
]

export const DAILY: Route = {
  id: 'daily', name: 'Ember Ribbon', grade: '6a+', level: 'hard', skill: 'Squeeze timing', bolts: 6, heightM: 22, firstBoltM: 3.2, longestM: 4.0, falls: 4, daily: true,
  text: "Today's route, the same for every climber. Featuring: squeeze timing.", crux: 'Generated daily (Daily.route_for, UTC date).',
  challenge: ['Daily onsight', 'Send it on your first go today without falling.'], path: 'M150 384 C 140 330, 150 290, 140 240 C 132 200, 150 170, 146 120', tagX: 146, tagY: 112,
}

export const INITIAL_PROGRESS: Record<string, RouteProgress> = {
  'first-climb': { attempts: 1, sends: 1, best: 'onsight', bestSeconds: 74, stars: 3, highBolt: 3 },
  'warm-up': { attempts: 1, sends: 1, best: 'flash', bestSeconds: 102, stars: 2, highBolt: 6 },
  sundown: { attempts: 4, sends: 1, best: 'top', bestSeconds: 188, stars: 1, highBolt: 4 },
  'the-pinch': { attempts: 2, sends: 0, best: '', bestSeconds: 0, stars: 0, highBolt: 5 },
  daily: { attempts: 1, sends: 0, best: '', bestSeconds: 0, stars: 0, highBolt: 3 },
}

export function isUnlocked(id: string, progress: Record<string, RouteProgress>) {
  if (id === 'first-climb') return true
  if (id === 'daily') return (progress['first-climb']?.sends ?? 0) > 0
  const i = ROUTES.findIndex(r => r.id === id)
  return (progress[ROUTES[i - 1].id]?.sends ?? 0) > 0
}

export function nextRoute(progress: Record<string, RouteProgress>) {
  return ROUTES.find(r => isUnlocked(r.id, progress) && (progress[r.id]?.sends ?? 0) === 0) ?? ROUTES[ROUTES.length - 1]
}

export function fmtTime(s: number) {
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`
}
