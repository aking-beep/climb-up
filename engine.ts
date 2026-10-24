// A small tile platformer that mirrors the APK's expedition climb
// (godot/core/player/climber.gd, core/world/terrain.gd, hazards.gd,
// creatures.gd, modes/expedition/levels/climb_level.gd).
//
// EXISTING in the APK (re-implemented here for the prototype, values scaled
// ×2 because the prototype tile is 32 px, the APK's is 16 px): walk, the edge
// guard, HOP (~2 tiles), grab a face (UP) and climb, top out, step down onto
// a face, rest with REST_LIMIT, gusts on exposed ground, ice without grip,
// cracked slabs that go if you stop, falls > 4 tiles are slips, holes,
// rockfall columns, rolling stones, siafu, nettles, ravens, cairns as
// checkpoints, gear, artifacts dropped on a counted slip, rope catches a slip.
//
// Nothing here is code to port: the Godot build already does all of it.
// Stage-specific PROPOSED verbs (bottles, breathing, the summit reunion) live
// in the stage screens, not here.

import { APK, GEAR, GearKind, Raven, SlipCause, freshRaven } from '../stageData'
import type { Toast } from '../StageKit'

export const T = 32
export const BW = 18
export const BH = 50
export const SAFE_FALL = 4 * T

const WALK = 128
const TIRED_WALK = 84
const EXPOSED_WALK = 64
const WADE = 58
const ACCEL = 1400
const DECEL = 2200
const ICE_ACCEL = 300
const ICE_DECEL = 140
const GRAV = 1800
const MAX_FALL = 840
const HOP_V = 545
const AIR_CTL = 520
const CLIMB_UP = 78
const CLIMB_SIDE = 60
const ARMS_GRACE = 3
const ROLL_PERIOD = 6.5
const ROLL_WARN = 3
const ROLL_GO = ROLL_WARN + APK.STONE_WARN
const ROLL_SPEED = 130

export type Tone = 'info' | 'warn' | 'bad' | 'good'

export interface Marker { ch: string; cx: number; cy: number; x: number; y: number; key: string; lane?: [number, number] }
export interface SignText { label: string; title: string; body: string }
export interface Level {
  id: string
  w: number
  h: number
  cells: string[][]
  markers: Marker[]
  by: Record<string, Marker[]>
  maxSlips: number
  rockPeriod: number
  drain: number
  restRate: number
  cold: boolean
  snacks: boolean
  gear: { kind: GearKind; where: string }[]
  signs: Record<string, SignText>
}

export type BodyState = 'ground' | 'air' | 'climb' | 'rest' | 'slip' | 'stun' | 'locked'
export type Ev =
  | { k: 'slip'; counted: boolean }
  | { k: 'fail' }
  | { k: 'find'; m: Marker }
  | { k: 'cairn'; m: Marker; n: number }
  | { k: 'hurt'; amount: number }
  | { k: 'hop' }
  | { k: 'exit' }

export interface Input { x: number; y: number; hop: boolean }

export interface Sim {
  t: number
  x: number; y: number; vx: number; vy: number; st: BodyState; facing: 1 | -1
  fallFrom: number; walkPh: number; climbPh: number; lift: number; stunT: number; slipT: number; slipTo: [number, number]
  guard: number; armsOut: number; stagCool: number
  stamina: number; barMax: number; lowest: number
  slips: number; caught: number; causes: Partial<Record<SlipCause, number>>; hurt: number
  checkpoint: [number, number]; visited: Record<string, number>; safe: [number, number]
  rests: number; restOpen: boolean; restFree: boolean; restStone: boolean; snacks: number; rested: number
  wind: 'calm' | 'rising' | 'gust'; windT: number; exposed: boolean; onIce: boolean; wading: boolean
  gone: Record<string, number>; slabHold: number; slabKey: string
  taken: Record<string, boolean>
  gear: GearKind[]; carried: number[]; spotter: boolean
  ravens: Record<string, Raven & { call: number }>; movedAt: number
  hitCycle: Record<string, number>
  caption: string | null; tone: Tone; capT: number
  toast: Toast | null; toastT: number
  said: Record<string, boolean>
  events: Ev[]
  /** Set by the stage each frame (breath, cold, load). 1 = normal. */
  speedMul: number
  /** Set by the stage each frame: extra drain on walking and climbing. */
  loadMul: number
  camX: number; camY: number
  exited: boolean
}

/* ---------------------------------------------------------------- level build */

export function grid(w: number, h: number) {
  const g: string[][] = Array.from({ length: h }, () => Array<string>(w).fill('.'))
  const signs: Record<string, SignText> = {}
  const api = {
    g, w, h, signs,
    set(x: number, y: number, c: string) { if (x >= 0 && x < w && y >= 0 && y < h) g[y][x] = c },
    rect(x0: number, y0: number, x1: number, y1: number, c: string) { for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) api.set(x, y, c) },
    /** Solid ground from `top` down to the bottom of the map. */
    ground(x0: number, x1: number, top: number) { api.rect(x0, top, x1, h - 1, '#') },
    sign(x: number, y: number, label: string, title: string, body: string) { api.set(x, y, 'S'); signs[`${x},${y}`] = { label, title, body } },
  }
  return api
}

const MARKS = 'PKSXTFRrbdnav12345ABglmjU'

export function parseLevel(b: ReturnType<typeof grid>, o: Omit<Level, 'w' | 'h' | 'cells' | 'markers' | 'by' | 'signs'>): Level {
  const cells = b.g.map(r => r.slice())
  const markers: Marker[] = []
  for (let y = 0; y < b.h; y++) for (let x = 0; x < b.w; x++) {
    const c = cells[y][x]
    if (!MARKS.includes(c)) continue
    markers.push({ ch: c, cx: x, cy: y, x: x * T + T / 2, y: (y + 1) * T, key: `${c}${x},${y}` })
    // a marker standing in the wind keeps the wind
    cells[y][x] = cells[y][x - 1] === 'E' || cells[y][x + 1] === 'E' ? 'E' : '.'
  }
  const by: Record<string, Marker[]> = {}
  markers.forEach(m => { (by[m.ch] ??= []).push(m) })
  const L: Level = { ...o, w: b.w, h: b.h, cells, markers, by, signs: b.signs }
  // rolling-stone lanes: along the floor until it ends or a rock stops it
  ;[...(by.b ?? []), ...(by.d ?? [])].forEach(m => {
    const dir = m.ch === 'b' ? -1 : 1
    let x = m.cx
    while (x + dir >= 0 && x + dir < b.w && !isSolid(cells[m.cy][x + dir]) && isSolid(cells[m.cy + 1]?.[x + dir] ?? '.')) x += dir
    m.lane = dir < 0 ? [x * T, m.x] : [m.x, x * T + T]
  })
  // rockfall columns: from the marker down to the first rock
  ;(by.r ?? []).forEach(m => {
    let y = m.cy
    while (y + 1 < b.h && !isSolid(cells[y + 1][m.cx])) y++
    m.lane = [m.cy * T, (y + 1) * T]
  })
  return L
}

export const isSolid = (c: string) => c === '#' || c === 'i' || c === 'c'
export const isClimb = (c: string) => c === 'C' || c === 'L' || c === 's'

export function cellAt(L: Level, s: Sim | null, cx: number, cy: number) {
  if (cx < 0 || cx >= L.w) return '#'
  if (cy < 0 || cy >= L.h) return '.'
  const c = L.cells[cy][cx]
  if (c === 'c' && s && (s.gone[`${cx},${cy}`] ?? 0) > 0) return '.'
  return c
}

/* ---------------------------------------------------------------- sim */

export function freshSim(L: Level, barMax: number): Sim {
  const p = L.by.P?.[0] ?? L.markers[0]
  return {
    t: 0, x: p.x, y: p.y, vx: 0, vy: 0, st: 'ground', facing: 1,
    fallFrom: p.y, walkPh: 0, climbPh: 0, lift: 0, stunT: 0, slipT: 0, slipTo: [p.x, p.y], guard: 0, armsOut: 0, stagCool: 0,
    stamina: barMax, barMax, lowest: 100, slips: 0, caught: 0, causes: {}, hurt: 0,
    checkpoint: [p.x, p.y], visited: {}, safe: [p.x, p.y],
    rests: APK.REST_LIMIT, restOpen: false, restFree: false, restStone: false, snacks: 0, rested: 0,
    wind: 'calm', windT: 0, exposed: false, onIce: false, wading: false,
    gone: {}, slabHold: 0, slabKey: '', taken: {}, gear: [], carried: [], spotter: false,
    ravens: {}, movedAt: 0, hitCycle: {},
    caption: null, tone: 'info', capT: 0, toast: null, toastT: 0, said: {}, events: [],
    speedMul: 1, loadMul: 1, exited: false,
    camX: clamp(p.x - 915 * 0.42 + 50, 0, Math.max(0, L.w * T - 915)),
    camY: clamp(p.y - 412 * 0.6, 0, Math.max(0, L.h * T - 412)),
  }
}

export const has = (s: Sim, g: GearKind) => s.gear.includes(g)
export function say(s: Sim, t: string, tone: Tone, secs: number) { s.caption = t; s.tone = tone; s.capT = secs }
export function sayOnce(s: Sim, key: string, t: string, tone: Tone, secs: number) { if (!s.said[key]) { s.said[key] = true; say(s, t, tone, secs) } }

export function step(s: Sim, L: Level, inp: Input, dt: number, arts: [string, string][], rm: boolean) {
  s.events = []
  if (s.capT > 0) { s.capT -= dt; if (s.capT <= 0) s.caption = null }
  if (s.toast) { s.toastT += dt; if (s.toastT > (s.toast.kind === 'artifact' ? 5 : 3.4)) { s.toast = null; s.toastT = 0 } } else s.toastT = 0
  camera(s, L, dt, rm)
  if (s.st === 'locked') return
  s.t += dt
  if (s.guard > 0) s.guard -= dt
  if (s.stagCool > 0) s.stagCool -= dt
  s.lift *= rm ? 0 : Math.exp(-dt / 0.06)
  for (const k in s.gone) { s.gone[k] -= dt; if (s.gone[k] <= 0) delete s.gone[k] }

  // wind: calm 4 s, rising 1.2 s, gust 2.2 s (APK WindSchedule shape)
  s.windT += dt
  const wc = s.windT % 7.4
  const prevWind = s.wind
  s.wind = wc < 4 ? 'calm' : wc < 5.2 ? 'rising' : 'gust'
  s.exposed = bodyHas(L, s, s.x, s.y, 'E')
  if (s.exposed && prevWind !== s.wind) {
    if (s.wind === 'rising') say(s, 'Wind rising: stop, or sit down and REST until it passes', 'warn', 1.3)
    if (s.wind === 'gust') say(s, has(s, 'shell') ? 'Gust! The goggles help. Stand still.' : 'Gust! Don\'t walk or hop in it.', 'bad', 1.8)
  }
  const under = cellAt(L, s, Math.floor(s.x / T), Math.round(s.y / T))
  s.onIce = s.st === 'ground' && under === 'i'
  s.wading = cellAt(L, s, Math.floor(s.x / T), Math.floor((s.y - 0.01) / T)) === '~'

  switch (s.st) {
    case 'slip':
      s.slipT -= dt
      if (s.slipT <= 0) { s.x = s.slipTo[0]; s.y = s.slipTo[1]; s.vx = s.vy = 0; s.st = 'ground'; s.armsOut = 0; s.stamina = Math.max(s.stamina, s.barMax * 0.5); s.lift = 0 }
      return
    case 'stun':
      s.stunT -= dt; if (s.stunT <= 0) s.st = 'ground'
      break
    case 'rest': rest(s, L, inp, dt); break
    case 'ground': ground(s, L, inp, dt); break
    case 'air': air(s, L, inp, dt, arts); break
    case 'climb': climb(s, L, inp, dt, arts); break
  }
  if (halted(s)) return
  slab(s, L, dt)
  hazards(s, L, dt, arts)
  if (halted(s)) return
  pickups(s, L, arts)
  if (s.y > L.h * T + 60) slip(s, L, 'You drop into the dark.', 'fall', arts)
  if (s.stamina < 0) s.stamina = 0
  s.lowest = Math.min(s.lowest, (s.stamina / s.barMax) * 100)
  if (s.st === 'ground' && !s.exposed && support(L, s, s.x, s.y) === '#') s.safe = [s.x, s.y]
}

function camera(s: Sim, L: Level, dt: number, rm: boolean) {
  const tx = clamp(s.x - 915 * 0.42 + s.facing * 50, 0, Math.max(0, L.w * T - 915))
  const ty = clamp(s.y - 412 * 0.6, 0, Math.max(0, L.h * T - 412))
  const k = rm ? 1 : 1 - Math.exp(-dt / 0.14)
  s.camX += (tx - s.camX) * k
  s.camY += (ty - s.camY) * (rm ? 1 : 1 - Math.exp(-dt / 0.18))
}

/* ---------------------------------------------------------------- states */

function ground(s: Sim, L: Level, inp: Input, dt: number) {
  if (inp.y < -0.5 && climbHere(L, s)) { s.st = 'climb'; s.vx = s.vy = 0; return }
  if (inp.y > 0.5 && support(L, s, s.x, s.y) === 'top') { s.st = 'climb'; s.y += 6; s.vx = 0; return }
  if (inp.hop && hop(s, L, inp)) return
  const slick = s.onIce && !has(s, 'crampons')
  let limit = s.wading ? WADE : s.exposed ? EXPOSED_WALK : s.stamina <= s.barMax * 0.12 ? TIRED_WALK : WALK
  if (L.cold && !has(s, 'headlamp')) limit *= 0.85
  limit *= s.speedMul
  let target = inp.x * limit
  if (s.exposed && s.wind === 'gust') {
    if (Math.abs(inp.x) > 0.2 && s.stagCool <= 0) {
      const cost = has(s, 'shell') ? 5 : 10
      s.stamina -= cost; s.vx = 0; s.st = 'stun'; s.stunT = 0.6; s.stagCool = 1.4
      moveX(s, L, -Math.sign(inp.x) * 14, false)
      say(s, `The gust staggers you (−${cost}). Stand still, or REST.`, 'bad', 1.8)
      return
    }
    if (Math.abs(inp.x) <= 0.2) target = 10 * (has(s, 'shell') ? 0.4 : 1)
    s.stamina -= (has(s, 'shell') ? 3 : 6) * dt
  }
  let rate = Math.abs(target) > Math.abs(s.vx) ? ACCEL : DECEL
  if (slick) rate = Math.abs(target) > Math.abs(s.vx) && Math.sign(target) === Math.sign(s.vx) ? ICE_ACCEL : ICE_DECEL
  s.vx = toward(s.vx, target, rate * dt)
  if (Math.abs(inp.x) > 0.15) s.facing = inp.x > 0 ? 1 : -1
  // the edge guard: walking never carries you off a drop that would be a slip (on ice it can)
  if (Math.abs(s.vx) > 1 && !slick && dropAhead(L, s, Math.sign(s.vx))) {
    s.vx = 0
    if (s.capT <= 0) say(s, 'A drop. HOP across, or find the way down.', 'info', 1.4)
  }
  const bx = s.x
  moveX(s, L, s.vx * dt, true)
  const moved = Math.abs(s.x - bx)
  s.walkPh += moved / 70
  if (moved > 0.3) s.movedAt = s.t
  s.stamina -= (moved / dt > 6 ? 0.45 * L.drain * (has(s, 'poles') ? 0.7 : 1) * s.loadMul : 0) * dt + (s.wading && moved > 0.3 ? 3 * dt : 0)
  if (!support(L, s, s.x, s.y)) { s.st = 'air'; s.fallFrom = s.y; s.vy = 0 }
}

function hop(s: Sim, L: Level, inp: Input) {
  const cost = 2 * L.drain * s.loadMul
  if (s.stamina < cost) { if (s.capT <= 0) say(s, 'No breath to hop. REST first.', 'warn', 1.4); return false }
  s.stamina -= cost
  s.events.push({ k: 'hop' })
  s.movedAt = s.t
  if (s.exposed && s.wind === 'gust') { slip(s, L, 'You hop in the gust and the wind takes you.', 'wind', []); return true }
  s.vy = -HOP_V
  if (Math.abs(inp.x) > 0.2) s.vx = Math.sign(inp.x) * Math.max(Math.abs(s.vx), (s.exposed ? WALK * 0.9 : WALK * 1.15) * Math.max(0.8, s.speedMul))
  s.st = 'air'; s.fallFrom = s.y
  return true
}

function air(s: Sim, L: Level, inp: Input, dt: number, arts: [string, string][]) {
  const limit = WALK * 1.15
  s.vx = Math.abs(inp.x) > 0.2 ? toward(s.vx, inp.x * limit, AIR_CTL * dt) : toward(s.vx, 0, 240 * dt)
  if (Math.abs(inp.x) > 0.15) s.facing = inp.x > 0 ? 1 : -1
  // catch the rock on the way down, from a short fall only
  if (inp.y < -0.5 && climbHere(L, s) && s.y - s.fallFrom < SAFE_FALL * 0.5 && s.stamina > 0) { s.st = 'climb'; s.vy = 0; s.vx = 0; return }
  s.vy = Math.min(s.vy + GRAV * dt, MAX_FALL)
  moveX(s, L, s.vx * dt, false)
  const r = moveY(s, L, s.vy * dt, inp.y <= 0.5)
  if (r === 'bonk') s.vy = 0
  if (r === 'land') {
    const drop = s.y - s.fallFrom
    s.vy = 0
    if (drop > SAFE_FALL + 1) slip(s, L, 'You fall too far and land hard.', 'fall', arts)
    else s.st = 'ground'
  }
}

function climb(s: Sim, L: Level, inp: Input, dt: number, arts: [string, string][]) {
  const k = climbKind(L, s)
  if (!k) { if (support(L, s, s.x, s.y)) s.st = 'ground'; else { s.st = 'air'; s.fallFrom = s.y; s.vy = 0 } return }
  const out = s.stamina <= 0
  if (out) {
    s.armsOut += dt
    sayOnce(s, `arms${s.slips}`, 'Your arms are giving out! Climb down now.', 'bad', 2.4)
    if (s.armsOut > ARMS_GRACE) { slip(s, L, 'Your arms give out.', 'arms', arts); return }
  } else s.armsOut = 0
  let vy = Math.abs(inp.y) < 0.25 ? 0 : inp.y * CLIMB_UP * Math.max(0.6, s.speedMul)
  const vx = Math.abs(inp.x) < 0.25 ? 0 : inp.x * CLIMB_SIDE
  if (out && vy < 0) vy = 0
  if (Math.abs(inp.x) > 0.25) s.facing = inp.x > 0 ? 1 : -1
  const ox = s.x, oy = s.y
  if (vx) moveX(s, L, vx * dt, false)
  if (vy) {
    const r = moveY(s, L, vy * dt, false)
    if (r === 'land') { s.st = 'ground'; return }
  }
  const moved = Math.abs(s.x - ox) + Math.abs(s.y - oy)
  s.climbPh += moved / 20
  if (moved > 0.2) s.movedAt = s.t
  const gloves = has(s, 'gloves') ? 0.8 : 1
  const base = k === 'L' ? [4.6, 1.6] : k === 'C' ? [3.2, 1] : [1.8, 0.4]
  s.stamina -= (moved > 0.2 ? base[0] : base[1]) * L.drain * gloves * s.loadMul * dt
  if (s.exposed && s.wind === 'gust') s.stamina -= 3 * dt
  // topped out: the feet have left the column, stand on its top
  if (vy < 0) {
    const row = Math.floor((s.y - 0.01) / T)
    if (!isClimb(cellAt(L, s, Math.floor(s.x / T), row))) { s.y = (row + 1) * T; s.st = 'ground'; s.vy = 0 }
  }
}

function rest(s: Sim, L: Level, inp: Input, dt: number) {
  if (Math.abs(inp.x) > 0.3 || Math.abs(inp.y) > 0.5 || inp.hop) { s.st = 'ground'; return }
  const rate = L.restRate * (s.restStone ? 1.5 : 1)
  if (s.restOpen || s.restFree) s.stamina = Math.min(s.barMax, s.stamina + rate * dt)
  else if (s.exposed && s.wind !== 'calm' && has(s, 'shell')) s.stamina = Math.min(s.barMax, s.stamina + 4 * dt)
  if (s.stamina >= s.barMax - 0.01) {
    s.restOpen = false
    if (!s.restFree) { s.st = 'ground'; say(s, 'Full breath. On you go.', 'good', 1.4) }
  }
}

/** APK · ClimbLevel._rest_gate: a rest from this stretch, else a snack from camp food, else nothing. A rest stone or sitting out the wind never counts. */
export function tryRest(s: Sim, L: Level, food: number) {
  if (s.st !== 'ground') return false
  const stone = near(s, L, 'R', 34)
  const free = !!stone || (s.exposed && s.wind !== 'calm')
  s.restFree = free; s.restStone = !!stone
  if (stone) say(s, 'The rest stone, out of the wind: a full rest that doesn\'t count.', 'info', 2)
  else if (free) say(s, 'Sitting out the wind. It doesn\'t count as a rest.', 'info', 1.8)
  else if (s.restOpen) say(s, 'Sitting again: the same rest.', 'info', 1.4)
  else if (s.stamina >= s.barMax - 1) { say(s, 'You have your breath. Keep moving.', 'info', 1.4); return false }
  else if (s.rests > 0) { s.rests--; s.restOpen = true; say(s, s.rests === 0 ? 'Your last rest before the next cairn.' : 'Sitting down: breath comes back.', s.rests === 0 ? 'warn' : 'info', 2) }
  else if (L.snacks && food - s.snacks * APK.SNACK >= APK.SNACK) { s.snacks++; s.restOpen = true; say(s, `No rests left: you eat from the camp food (supplies −${APK.SNACK}).`, 'warn', 2.6) }
  else { say(s, 'No rests left. Make for the next cairn.', 'bad', 2.4); return false }
  s.st = 'rest'; s.vx = 0; s.rested++
  return true
}

/* ---------------------------------------------------------------- terrain physics */

function bodyCells(x: number, y: number) {
  return {
    x0: Math.floor((x - BW / 2) / T), x1: Math.floor((x + BW / 2 - 0.01) / T),
    y0: Math.floor((y - BH) / T), y1: Math.floor((y - 0.01) / T),
  }
}

function hits(L: Level, s: Sim, x: number, y: number) {
  const b = bodyCells(x, y)
  for (let cy = b.y0; cy <= b.y1; cy++) for (let cx = b.x0; cx <= b.x1; cx++) if (isSolid(cellAt(L, s, cx, cy))) return true
  return false
}

function bodyHas(L: Level, s: Sim, x: number, y: number, c: string) {
  const b = bodyCells(x, y)
  for (let cy = b.y0; cy <= b.y1; cy++) for (let cx = b.x0; cx <= b.x1; cx++) if (cellAt(L, s, cx, cy) === c) return true
  return false
}

function rowSupports(L: Level, s: Sim, x: number, k: number, platforms: boolean) {
  const b = bodyCells(x, k * T)
  for (let cx = b.x0; cx <= b.x1; cx++) {
    const c = cellAt(L, s, cx, k)
    if (isSolid(c)) return true
    if (platforms && isClimb(c) && !isClimb(cellAt(L, s, cx, k - 1))) return true
  }
  return false
}

/** What the feet stand on: '#', 'i', 'c', 'top' (the top of a face), or null. */
export function support(L: Level, s: Sim, x: number, y: number): string | null {
  if (Math.abs(y - Math.round(y / T) * T) > 0.6) return null
  const k = Math.round(y / T)
  const b = bodyCells(x, k * T)
  let top = false
  let found: string | null = null
  for (let cx = b.x0; cx <= b.x1; cx++) {
    const c = cellAt(L, s, cx, k)
    if (isSolid(c)) { if (found === null || c === '#') found = c }
    else if (isClimb(c) && !isClimb(cellAt(L, s, cx, k - 1))) top = true
  }
  return found ?? (top ? 'top' : null)
}

function moveX(s: Sim, L: Level, dx: number, grounded: boolean) {
  if (!dx) return
  const n = Math.max(1, Math.ceil(Math.abs(dx) / 4))
  const d = dx / n
  for (let i = 0; i < n; i++) {
    const nx = s.x + d
    if (!hits(L, s, nx, s.y)) { s.x = nx; continue }
    // a one-tile step: walk up it (the APK's slopes, as steps)
    if (grounded && !hits(L, s, nx, s.y - T) && !hits(L, s, s.x, s.y - T)) { s.y -= T; s.x = nx; s.lift += T; s.stamina -= 0.8 * L.drain * s.loadMul; continue }
    s.vx = 0
    return
  }
}

function moveY(s: Sim, L: Level, dy: number, platforms: boolean): 'land' | 'bonk' | null {
  const n = Math.max(1, Math.ceil(Math.abs(dy) / 4))
  const d = dy / n
  for (let i = 0; i < n; i++) {
    const ny = s.y + d
    if (d > 0) {
      const k = Math.ceil(s.y / T - 1e-4)
      if (ny >= k * T - 1e-4 && rowSupports(L, s, s.x, k, platforms)) { s.y = k * T; return 'land' }
      s.y = ny
    } else {
      if (hits(L, s, s.x, ny)) return 'bonk'
      s.y = ny
    }
  }
  return null
}

function dropAhead(L: Level, s: Sim, dir: number) {
  const cx = Math.floor((s.x + dir * (BW / 2 + 3)) / T)
  const k = Math.round(s.y / T)
  for (let r = k; r <= k + 4; r++) { const c = cellAt(L, s, cx, r); if (isSolid(c) || isClimb(c)) return false }
  return true
}

function climbKind(L: Level, s: Sim): string | null {
  const cx = Math.floor(s.x / T)
  for (let r = Math.floor((s.y - BH * 0.7) / T); r <= Math.floor((s.y - 1) / T); r++) { const c = cellAt(L, s, cx, r); if (isClimb(c)) return c }
  return null
}
export function climbHere(L: Level, s: Sim) { return climbKind(L, s) !== null }

/* ---------------------------------------------------------------- slabs, hazards, creatures */

function slab(s: Sim, L: Level, dt: number) {
  if (s.st !== 'ground' && s.st !== 'stun' && s.st !== 'rest') { s.slabHold = 0; return }
  const k = Math.round(s.y / T)
  const b = bodyCells(s.x, k * T)
  let on = -1
  for (let cx = b.x0; cx <= b.x1; cx++) if (cellAt(L, s, cx, k) === 'c') on = cx
  if (on < 0) { s.slabHold = 0; return }
  sayOnce(s, `slab${k}`, 'The slab creaks. Keep walking!', 'warn', 1.6)
  s.slabKey = `${on},${k}`
  if (Math.abs(s.vx) < 12) s.slabHold += dt; else s.slabHold = Math.max(0, s.slabHold - dt)
  if (s.slabHold >= APK.SLAB_HOLD) {
    let a = on, z = on
    while (L.cells[k][a - 1] === 'c') a--
    while (L.cells[k][z + 1] === 'c') z++
    for (let x = a; x <= z; x++) s.gone[`${x},${k}`] = 5
    s.slabHold = 0
    s.st = 'air'; s.fallFrom = s.y; s.vy = 0
    say(s, 'The slab goes under you!', 'bad', 1.6)
  }
}

export function antX(t: number, m: Marker) { const p = ((t * 28) / 128 + (m.cx % 3) * 0.3) % 2; return m.x - 64 + (p < 1 ? p : 2 - p) * 128 }
const ph = (m: Marker) => (m.cx * 0.37) % 1

export function rollerAt(s: Sim, m: Marker): { phase: 'idle' | 'warn' | 'roll'; x: number; cycle: number } {
  const c = (s.t + ph(m) * ROLL_PERIOD) % ROLL_PERIOD
  const cycle = Math.floor((s.t + ph(m) * ROLL_PERIOD) / ROLL_PERIOD)
  const dir = m.ch === 'b' ? -1 : 1
  if (c < ROLL_WARN) return { phase: 'idle', x: m.x, cycle }
  if (c < ROLL_GO) return { phase: 'warn', x: m.x, cycle }
  const x = m.x + dir * (c - ROLL_GO) * ROLL_SPEED
  const [a, b] = m.lane ?? [m.x, m.x]
  if (x < a || x > b) return { phase: 'idle', x: m.x, cycle }
  return { phase: 'roll', x, cycle }
}

export function rockAt(s: Sim, L: Level, m: Marker): { phase: 'idle' | 'warn' | 'fall'; y: number; cycle: number } {
  const P = L.rockPeriod
  const c = (s.t + ph(m) * P) % P
  const cycle = Math.floor((s.t + ph(m) * P) / P)
  const [top, bot] = m.lane ?? [m.y, m.y]
  if (c < P - 0.5 - APK.STONE_WARN) return { phase: 'idle', y: top, cycle }
  if (c < P - 0.5) return { phase: 'warn', y: top, cycle }
  return { phase: 'fall', y: top + ((c - (P - 0.5)) / 0.5) * (bot - top), cycle }
}

function hazards(s: Sim, L: Level, dt: number, arts: [string, string][]) {
  const grounded = s.st === 'ground' || s.st === 'stun' || s.st === 'rest'
  // siafu and nettles (APK · Creatures): hop over them
  for (const m of L.by.a ?? []) if (s.guard <= 0 && grounded && Math.abs(s.x - antX(s.t, m)) < 14 && Math.abs(s.y - m.y) < 6) hurt(s, L, APK.ANT_HURT, 'Siafu! The ants bite', arts)
  for (const m of L.by.n ?? []) if (s.guard <= 0 && grounded && Math.abs(s.x - m.x) < 13 && Math.abs(s.y - m.y) < 6) hurt(s, L, APK.PLANT_HURT, 'Nettles sting your shins', arts)
  // rolling stones (APK · Hazards b/d): a rumble, then one comes along the ground
  for (const m of [...(L.by.b ?? []), ...(L.by.d ?? [])]) {
    const r = rollerAt(s, m)
    const close = Math.abs(s.y - m.y) < 40 && s.x > (m.lane?.[0] ?? 0) - 160 && s.x < (m.lane?.[1] ?? 0) + 160
    if (r.phase === 'warn' && close && s.hitCycle[`w${m.key}`] !== r.cycle) { s.hitCycle[`w${m.key}`] = r.cycle; say(s, 'Rumble! A stone is coming along the scree. HOP it.', 'warn', 1.3) }
    if (r.phase === 'roll' && s.hitCycle[m.key] !== r.cycle && Math.abs(s.x - r.x) < 16 && s.y > m.y - 20 && Math.abs(s.y - m.y) < 40 && s.st !== 'climb') {
      s.hitCycle[m.key] = r.cycle
      if (s.guard <= 0) hurt(s, L, APK.ANT_HURT, 'The stone takes your legs', arts)
    }
  }
  // rockfall (APK · Hazards r): grit for 1.2 s, then a stone down the column. A hit is a slip; a helmet makes it −12.
  for (const m of L.by.r ?? []) {
    const r = rockAt(s, L, m)
    const inChute = Math.abs(s.x - m.x) < T * 1.5 - 2 && s.y > (m.lane?.[0] ?? 0) && s.y - BH < (m.lane?.[1] ?? 0)
    const nearChute = Math.abs(s.x - m.x) < T * 4 && s.y > (m.lane?.[0] ?? 0) && s.y - BH < (m.lane?.[1] ?? 0) + T
    if (r.phase === 'warn' && nearChute && s.hitCycle[`w${m.key}`] !== r.cycle) { s.hitCycle[`w${m.key}`] = r.cycle; say(s, 'Grit trickling down the rock step: get clear, or wait', 'warn', 1.2) }
    if (r.phase === 'fall' && inChute && s.hitCycle[m.key] !== r.cycle && r.y > s.y - BH - 6 && r.y < s.y + 6) {
      s.hitCycle[m.key] = r.cycle
      if (has(s, 'helmet')) hurt(s, L, APK.HELMET_HIT, 'Stone! The helmet took it', arts)
      else { slip(s, L, 'A falling stone knocks you off.', 'rock', arts); return }
    }
  }
  // the raven (APK · Creatures v): stand about under it and it calls, then dives where you were
  for (const m of L.by.v ?? []) {
    const inZone = Math.abs(s.x - m.x) < 6 * T && s.y > m.y && s.y < m.y + 9 * T
    const r = (s.ravens[m.key] ??= { ...freshRaven(), call: 0 })
    if (!inZone && r.phase === 'circle') { r.t += dt; continue }
    r.t += dt
    if (r.phase === 'circle') {
      if (s.t - s.movedAt > 0.15) r.still += dt; else if (r.still > 0) r.still = 0
      if (r.still > 2.2) { r.phase = 'call'; r.t = 0; r.tx = s.x; r.ty = s.y - 30; r.call = s.t; say(s, 'A raven calls overhead: keep moving!', 'warn', 1) }
    } else if (r.phase === 'call' && r.t >= APK.RAVEN_WARN) { r.phase = 'dive'; r.t = 0 }
    else if (r.phase === 'dive' && r.t >= APK.RAVEN_DIVE) {
      if (s.movedAt > r.call && Math.abs(s.x - r.tx) > 16) say(s, 'The raven misses. Keep moving under it.', 'good', 1.3)
      else {
        hurt(s, L, APK.RAVEN_HURT, 'The raven hits you', arts)
        const lost = s.carried.pop()
        if (lost !== undefined) { untakeArtifact(s, L, lost); s.toast = { kind: 'lost', title: `The raven took ${arts[lost]?.[0] ?? 'it'}`, body: 'It drops it back where you found it.', id: Date.now() } }
      }
      r.phase = 'back'; r.t = 0
    } else if (r.phase === 'back' && r.t >= 1) { r.phase = 'circle'; r.t = 0; r.still = -APK.RAVEN_REST }
  }
}

function pickups(s: Sim, L: Level, arts: [string, string][]) {
  for (const m of L.markers) {
    if (Math.abs(s.x - m.x) > 20 || s.y < m.y - 44 || s.y > m.y + 20) continue
    if (m.ch === 'K') {
      if (s.visited[m.key] === undefined) {
        s.visited[m.key] = Object.keys(s.visited).length
        const fresh = s.rests < APK.REST_LIMIT || s.restOpen
        s.rests = APK.REST_LIMIT; s.restOpen = false
        s.events.push({ k: 'cairn', m, n: s.visited[m.key] })
        if (s.visited[m.key] > 0) say(s, `Cairn${fresh ? ' · rests back to 2' : ''} · progress saves here`, 'good', 1.8)
      }
      s.checkpoint = [m.x, m.y]
      continue
    }
    if (m.ch === 'X') { if (!s.exited) { s.exited = true; s.events.push({ k: 'exit' }) } continue }
    if (s.taken[m.key]) continue
    if ('12345'.includes(m.ch)) {
      s.taken[m.key] = true
      const g = L.gear[Number(m.ch) - 1]
      if (!g) continue
      if (!s.gear.includes(g.kind)) s.gear.push(g.kind)
      if (g.kind === 'rope') s.spotter = true
      const effect = g.kind === 'rope' ? 'Clipped to your pack. It holds your next slip: that one will not count.' : GEAR[g.kind].effect
      s.toast = { kind: 'gear', title: `Found: ${GEAR[g.kind].label}`, body: `${g.where} ${effect}`, id: Date.now() }
    } else if (m.ch === 'A' || m.ch === 'B') {
      s.taken[m.key] = true
      const i = m.ch === 'A' ? 0 : 1
      s.carried.push(i)
      s.toast = { kind: 'artifact', title: `Artifact: ${arts[i]?.[0] ?? 'a find'}`, body: arts[i]?.[1] ?? '', id: Date.now() }
    } else if (m.ch === 'g') {
      s.taken[m.key] = true
      s.events.push({ k: 'find', m })
    }
  }
}

function untakeArtifact(s: Sim, L: Level, i: number) {
  const m = L.markers.find(mm => mm.ch === (i === 0 ? 'A' : 'B'))
  if (m) delete s.taken[m.key]
}

export function hurt(s: Sim, L: Level, amount: number, why: string, arts: [string, string][]) {
  s.hurt += amount; s.stamina -= amount; s.guard = 1
  s.events.push({ k: 'hurt', amount })
  if (s.st === 'ground') moveX(s, L, -s.facing * 20, false)
  say(s, `${why} (−${amount})`, 'bad', 1.8)
  if (s.stamina <= 0) { s.stamina = 0; slip(s, L, 'Too hurt to go on: you sit down hard.', 'hurt', arts) }
}

export function slip(s: Sim, L: Level, why: string, cause: SlipCause, arts: [string, string][]) {
  if (s.st === 'slip' || s.st === 'locked') return
  s.vx = s.vy = 0
  if (s.spotter) {
    s.spotter = false; s.caught++
    s.st = 'slip'; s.slipT = 0.7; s.slipTo = s.safe
    s.stamina = Math.max(s.stamina, s.barMax * 0.3)
    say(s, `${why} The rope holds: that slip doesn't count.`, 'good', 2.4)
    s.events.push({ k: 'slip', counted: false })
    return
  }
  s.slips++
  s.causes[cause] = (s.causes[cause] ?? 0) + 1
  if (s.carried.length) {
    const n = s.carried.length
    s.carried.forEach(a => untakeArtifact(s, L, a))
    s.carried = []
    s.toast = { kind: 'lost', title: n === 1 ? 'You drop the artifact' : 'You drop both artifacts', body: 'Back where you found them. Go back for them.', id: Date.now() }
  }
  s.events.push({ k: 'slip', counted: true })
  if (s.slips >= L.maxSlips) { s.st = 'locked'; s.events.push({ k: 'fail' }); say(s, `${why} Slip ${s.slips} of ${L.maxSlips}.`, 'bad', 3); void arts; return }
  s.st = 'slip'; s.slipT = 1; s.slipTo = s.checkpoint
  say(s, `${why} Back to the last cairn.`, 'bad', 2.4)
}

export function near(s: Sim, L: Level, chars: string, dist = 30): Marker | null {
  let best: Marker | null = null, bd = dist
  for (const m of L.markers) {
    if (!chars.includes(m.ch) || s.taken[m.key]) continue
    const d = Math.abs(s.x - m.x)
    if (d < bd && Math.abs(s.y - m.y) < 40) { bd = d; best = m }
  }
  return best
}

/** A slip or the end can be set by any of the calls above (TS cannot see through them). */
function halted(s: Sim) { const st: BodyState = s.st; return st === 'slip' || st === 'locked' }

function toward(v: number, t: number, d: number) { return v < t ? Math.min(t, v + d) : Math.max(t, v - d) }
function clamp(v: number, a: number, b: number) { return Math.max(a, Math.min(b, v)) }
