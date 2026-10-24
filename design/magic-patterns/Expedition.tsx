import React, { createContext, useCallback, useContext, useMemo, useState } from 'react'
import {
  BARAFU_EVENT, CAMPS, Choice, CURRENT_INDEX, ENCOUNTERS, EncounterId, EVENTS, GATE_EVENT, HARD_HOUR_EVENT,
  KiliEvent, START_STATS, StatKey, UHURU_EVENT, WALL_EVENT,
} from '../data/kili'
import { ScreenId, useGame } from './GameState'

export type CampPhase = 'day' | 'evening' | 'night'
export type MapWeather = 'clear' | 'wind' | 'fog' | 'snow'
export type RunEnd = null | 'descent' | 'home' | 'turned'

/**
 * Prototype stand-in for the `Expedition` autoload. It only sequences the
 * engine's own cards (copied from kilimanjaro.json) and applies their own
 * deltas. In Godot every value here comes from the engine; nothing in this
 * file is logic to port.
 */
const QUEUE: Record<number, KiliEvent[]> = {
  0: [GATE_EVENT],
  4: [WALL_EVENT],
  5: [EVENTS[0], EVENTS[1]],
  6: [BARAFU_EVENT, HARD_HOUR_EVENT],
  7: [UHURU_EVENT],
}
const EVENT_PHASE: Record<string, CampPhase> = {
  'kili-gate': 'day', 'kili-wall': 'day', 'kili-karanga-day': 'day', 'kili-karanga-break': 'day',
  'kili-barafu-rest': 'day', 'kili-hard-hour': 'night', 'kili-uhuru': 'day',
}

export const ENCOUNTER_SCREEN: Record<EncounterId, ScreenId> = {
  'barranco-wall': 'enc-barranco', 'karanga-ridge': 'enc-karanga', 'summit-approach': 'enc-summit',
}

interface Pending { id: EncounterId; choice: Choice | null }

interface ExpCtx {
  at: number
  day: number
  days: number
  routeName: string
  stats: Record<StatKey, number>
  event: KiliEvent | null
  weather: MapWeather
  setWeather: (w: MapWeather) => void
  phase: CampPhase
  setPhase: (p: CampPhase) => void
  climbs: Record<EncounterId, { stars: number; done: boolean }>
  pending: Pending | null
  summit: boolean
  ended: RunEnd
  log: string[]
  toast: string | null
  say: (t: string) => void
  /** Confirm a card choice (retreat confirmation is the caller's job). */
  apply: (c: Choice) => void
  launch: (id: EncounterId, choice: Choice | null) => void
  /** Start a climb for real: party at its start camp, the engine's own launching choice pending. */
  play: (id: EncounterId) => void
  land: (result: 'complete' | 'retreat' | 'fail', stars: number) => void
  finishDescent: () => void
  startNew: (name: string, days: number) => void
  jump: (to: 'barranco' | 'karanga' | 'barafu' | 'night' | 'summit') => void
}

const Ctx = createContext<ExpCtx | null>(null)

export function ExpeditionProvider({ children }: { children: React.ReactNode }) {
  const g = useGame()
  const [at, setAt] = useState(CURRENT_INDEX)
  const [idx, setIdx] = useState(0)
  const [day, setDay] = useState(6)
  const [days, setDays] = useState(13)
  const [routeName, setRouteName] = useState('Lemosho')
  const [stats, setStats] = useState(START_STATS)
  const [weather, setWeather] = useState<MapWeather>('wind')
  const [phase, setPhase] = useState<CampPhase>('day')
  const [climbs, setClimbs] = useState<ExpCtx['climbs']>({
    'barranco-wall': { stars: 3, done: true }, 'karanga-ridge': { stars: 0, done: false }, 'summit-approach': { stars: 0, done: false },
  })
  const [pending, setPending] = useState<Pending | null>(null)
  const [summit, setSummit] = useState(false)
  const [ended, setEnded] = useState<RunEnd>(null)
  const [log, setLog] = useState<string[]>([
    'Day 5 · You took the wall in the morning and pitched at Karanga as the light went.',
    'Day 4 · Lava Tower for the air, then down to sleep at Barranco.',
  ])
  const [toast, setToast] = useState<string | null>(null)

  const event = ended ? null : QUEUE[at]?.[idx] ?? null

  const say = useCallback((t: string) => { setToast(t); window.setTimeout(() => setToast(null), 2800) }, [])

  const arrive = useCallback((i: number) => {
    setAt(i); setIdx(0); setPhase('evening')
    if (i === CAMPS.length - 1) setSummit(true)
  }, [])

  const apply = useCallback((c: Choice) => {
    setStats(s => {
      const n = { ...s }
      ;(Object.keys(c.deltas) as StatKey[]).forEach(k => { n[k] = Math.max(0, Math.min(100, n[k] + (c.deltas[k] ?? 0))) })
      return n
    })
    if (c.hours >= 12) setDay(d => d + 1)
    setLog(l => [`Day ${day} · ${c.note}`, ...l])
    if (c.climb) {
      setPending({ id: c.climb, choice: c })
      g.go(ENCOUNTER_SCREEN[c.climb])
      return
    }
    if (c.move === 'retreat') { setEnded('turned'); g.go('scorecard'); return }
    if (c.move === 'down') { setEnded('descent'); g.go('scorecard'); return }
    if (c.move === 'up' || c.move === 'summit') { arrive(Math.min(CAMPS.length - 1, at + 1)); say(`${c.note} (simulated)`); return }
    setIdx(i => i + 1)
    const next = QUEUE[at]?.[idx + 1]
    if (next) setPhase(EVENT_PHASE[next.id] ?? 'day')
    say(`${c.note} (simulated)`)
  }, [at, idx, day, g, arrive, say])

  const launch = useCallback((id: EncounterId, choice: Choice | null) => {
    setPending({ id, choice })
    g.go(ENCOUNTER_SCREEN[id])
  }, [g])

  const play = useCallback((id: EncounterId) => {
    const launching: Record<EncounterId, { at: number; idx: number; day: number; phase: CampPhase; ev: KiliEvent }> = {
      'barranco-wall': { at: 4, idx: 0, day: 5, phase: 'day', ev: WALL_EVENT },
      'karanga-ridge': { at: 5, idx: 1, day: 7, phase: 'day', ev: EVENTS[1] },
      'summit-approach': { at: 6, idx: 1, day: 9, phase: 'night', ev: HARD_HOUR_EVENT },
    }
    const l = launching[id]
    setEnded(null); setSummit(false)
    setAt(l.at); setIdx(l.idx); setDay(l.day); setPhase(l.phase)
    setPending({ id, choice: l.ev.choices.find(c => c.climb === id) ?? null })
    g.go(ENCOUNTER_SCREEN[id])
  }, [g])

  const land = useCallback((result: 'complete' | 'retreat' | 'fail', stars: number) => {
    const p = pending
    setPending(null)
    if (!p) { g.go('expedition'); return }
    setClimbs(c => ({ ...c, [p.id]: { stars: Math.max(c[p.id].stars, stars), done: c[p.id].done || result === 'complete' } }))
    const enc = ENCOUNTERS[p.id]
    if (result === 'complete' && p.choice && at === enc.from) {
      arrive(enc.to)
      say(`${CAMPS[enc.to].name} reached. The engine lands the climb outcome once (simulated).`)
    } else if (p.choice && result !== 'complete') {
      say('The day is spent at camp. The expedition goes on (existing retreat rule).')
    } else {
      say('Replay recorded. Best stars kept; the run is unchanged.')
    }
    g.go('expedition')
  }, [pending, at, arrive, g, say])

  const finishDescent = useCallback(() => setEnded('home'), [])

  const startNew = useCallback((name: string, d: number) => {
    setRouteName(name); setDays(d); setAt(0); setIdx(0); setDay(1); setSummit(false); setEnded(null)
    setStats({ ...START_STATS, health: 92, energy: 90, acclimatization: 10, teamCondition: 80, supplies: 96 })
    setLog([]); setPhase('day')
    g.setExpeditionStarted(true)
  }, [g])

  const jump = useCallback((to: 'barranco' | 'karanga' | 'barafu' | 'night' | 'summit') => {
    setEnded(null); setPending(null)
    if (to === 'barranco') { setAt(4); setIdx(0); setDay(5); setPhase('day'); setSummit(false) }
    if (to === 'karanga') { setAt(5); setIdx(0); setDay(6); setPhase('day'); setSummit(false) }
    if (to === 'barafu') { setAt(6); setIdx(0); setDay(8); setPhase('evening'); setSummit(false) }
    if (to === 'night') { setAt(6); setIdx(1); setDay(9); setPhase('night'); setSummit(false) }
    if (to === 'summit') { setAt(7); setIdx(0); setDay(10); setPhase('day'); setSummit(true) }
  }, [])

  const value = useMemo<ExpCtx>(() => ({
    at, day, days, routeName, stats, event, weather, setWeather, phase, setPhase, climbs, pending, summit, ended, log, toast, say,
    apply, launch, play, land, finishDescent, startNew, jump,
  }), [at, day, days, routeName, stats, event, weather, phase, climbs, pending, summit, ended, log, toast, say, apply, launch, play, land, finishDescent, startNew, jump])

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>
}

export function useExpedition() {
  const c = useContext(Ctx)
  if (!c) throw new Error('useExpedition outside ExpeditionProvider')
  return c
}
