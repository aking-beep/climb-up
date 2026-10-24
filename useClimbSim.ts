import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { HoldType } from '../components/Icons'
import { Route } from '../data/routes'
import { HudState } from '../state/GameState'

/*
 * PROTOTYPE SIMULATION ONLY. A stand-in so the HUD can be felt in a browser.
 * It borrows the shape of the real rules (lead fall = 2 × height above the
 * last clip + slack, clips fill the rope-rest bar, shoes trade pace for
 * stamina, crimps drain a grip meter you squeeze below half) but none of the
 * numbers are the game's. Godot keeps climber.gd / crag_level.gd as-is.
 */

export const PX = 44 // px per metre in the prototype camera

export interface Hold { i: number; x: number; y: number; type: HoldType }
export interface BoltDef { i: number; y: number; x: number }
export type Mode = 'climb' | 'reach' | 'clip' | 'rest' | 'shake' | 'fall' | 'lesson' | 'complete' | 'paused'
export type Cause = 'pumped' | 'grip'

export interface Sim {
  idx: number
  stamina: number
  grip: number
  restBar: number
  /** Bolts clipped so far, in order. Every bolt must be clipped before climbing past it. */
  clips: number
  /**
   * Clipped into the top chains. The route only counts as sent (and the
   * climber only celebrates) once this is true: clipping the last bolt is not
   * enough, you climb on to the chains and clip in there.
   */
  anchored: boolean
  /** Legacy: always empty now. Bolts can no longer be skipped. */
  skipped: number[]
  falls: number
  seconds: number
  mode: Mode
  cause: Cause | null
  fallM: number
  ground: boolean
  wasted: number
  flip: boolean
  bodyOffset: number // extra drop in metres while falling / resting on the rope
}

const TYPES: HoldType[] = ['rock', 'rock', 'jug', 'crimp', 'crimp', 'rock', 'pocket', 'rock', 'jug', 'crimp', 'crimp', 'crimp', 'rock', 'sloper', 'rock', 'jug', 'crimp', 'crimp', 'rock', 'rock']
const COST: Record<HoldType, number> = { rock: 3, jug: 1.5, pocket: 2, crimp: 4.5, sloper: 4.5 }
const SHOE = { neutral: { pace: 480, stamina: 0.7 }, aggressive: { pace: 320, stamina: 1.35 } }

export function buildRoute(route: Route) {
  const step = (route.heightM - 1.9) / TYPES.length
  const holds: Hold[] = TYPES.map((type, i) => ({
    i, type, y: 1.9 + i * step,
    x: (i % 2 ? 30 : -30) + (((i * 37) % 17) - 8),
  }))
  const top = holds[holds.length - 1].y
  // The last bolt sits at hand height on the second-to-top hold: you climb up to
  // it and touch it to clip, then make one more move to the chains.
  const lastY = holds[holds.length - 2].y - 0.1
  const bolts: BoltDef[] = Array.from({ length: route.bolts }).map((_, i) => ({
    i, y: route.firstBoltM + ((lastY - route.firstBoltM) * i) / Math.max(1, route.bolts - 1), x: 6,
  }))
  return { holds, bolts, top }
}

const fresh = (): Sim => ({ idx: 0, stamina: 100, grip: 100, restBar: 0, clips: 0, anchored: false, skipped: [], falls: 0, seconds: 0, mode: 'climb', cause: null, fallM: 0, ground: false, wasted: 0, flip: false, bodyOffset: 0 })

export function useClimbSim(route: Route, shoes: 'neutral' | 'aggressive', hudState: HudState, intent: string | null) {
  const { holds, bolts, top } = useMemo(() => buildRoute(route), [route])
  const [sim, setSim] = useState<Sim>(fresh)
  const up = useRef(false)
  const lastMove = useRef(0)
  const live = hudState === 'live'

  const nearTop = useCallback((): Sim => ({ ...fresh(), idx: holds.length - 4, clips: bolts.length - 1, stamina: 64, restBar: 34, seconds: 96 }), [holds.length, bolts.length])

  /** Bolts the hand has already passed at hold `idx`: all of them must be clipped. */
  const passed = (idx: number) => bolts.filter(b => b.y < holds[Math.min(idx, holds.length - 1)].y).length

  // Reset for live play, or load a frozen preset for each documented HUD state.
  useEffect(() => {
    if (live) { setSim(intent === 'near-top' ? nearTop() : fresh()); return }
    const base: Sim = { ...fresh(), idx: 9, clips: 3, stamina: 72, restBar: 34, seconds: 41 }
    const presets: Record<Exclude<HudState, 'live'>, Sim> = {
      normal: { ...base, idx: 7, clips: 3, flip: true },
      reach: { ...base, idx: 9, mode: 'reach', grip: 82 },
      clip: { ...base, idx: 10, clips: 3, mode: 'clip', grip: 64 },
      rest: { ...base, idx: 8, mode: 'rest', stamina: 46, restBar: 0, bodyOffset: 0.6 },
      fall: { ...base, idx: 11, mode: 'lesson', cause: 'grip', fallM: 4.6, falls: 1, bodyOffset: 4.6, grip: 0, stamina: 38 },
      complete: { ...base, idx: holds.length - 1, clips: bolts.length, anchored: true, mode: 'complete', seconds: 142, stamina: 41 },
    }
    // Frozen states obey the same rule: no bolt below the hand is ever left unclipped.
    const p = presets[hudState]
    setSim({ ...p, clips: Math.max(p.clips, passed(p.idx)) })
  }, [live, hudState, intent, holds.length, bolts.length, nearTop])

  const hold = holds[Math.min(sim.idx, holds.length - 1)]
  const handY = hold.y
  const harnessY = handY - 1.1 - sim.bodyOffset
  const lastClipY = lastClip(sim, bolts)
  const clippedCount = sim.clips - sim.skipped.length
  const isClipped = (i: number) => i < sim.clips && !sim.skipped.includes(i)
  const nextBolt = sim.clips < bolts.length ? bolts[sim.clips] : null
  const atChains = chainGate(sim)
  const mustClip = clipGate(sim) || atChains
  const lastBoltNext = sim.clips === bolts.length - 1
  /** At the last bolt with the hand up on it: clip it here (never from below). */
  const atLastBolt = lastBoltNext && mustClip && !atChains
  /** Last bolt is just overhead: the earlier bolts would stop you here, this one wants you to climb up to it. */
  const belowLastBolt = lastBoltNext && !mustClip && sim.idx < holds.length - 1 && holds[sim.idx + 1].y >= bolts[bolts.length - 1].y
  // Earlier bolts clip from below (the hand is on the last hold under them); the last bolt clips once the hand is up on it; the chains from the top hold.
  const canClip = (!!nextBolt || atChains) && mustClip
  const onSmall = hold.type === 'crimp' || hold.type === 'sloper'
  const onGood = hold.type === 'jug' || hold.type === 'pocket'
  const potentialFall = 2 * Math.max(0, harnessY - lastClipY) + 1
  const groundRisk = potentialFall >= harnessY

  // Tick: grip drain, shake-outs, rope rests, the clock.
  useEffect(() => {
    if (!live) return
    const id = window.setInterval(() => {
      setSim(s => {
        if (s.mode === 'complete' || s.mode === 'lesson' || s.mode === 'paused') return s
        const h = holds[s.idx]
        const n = { ...s, seconds: s.seconds + 0.1 }
        if (s.mode === 'rest') {
          n.stamina = Math.min(100, s.stamina + 3.4)
          return n
        }
        if (s.mode === 'fall') return n
        const small = h.type === 'crimp' || h.type === 'sloper'
        if (small) {
          n.grip = Math.max(0, s.grip - 0.6 * 2.2 * (route.daily ? 1.1 : 1))
          n.stamina = Math.max(0, s.stamina - 0.15)
        } else if (h.type === 'jug' || h.type === 'pocket') {
          n.stamina = Math.min(100, s.stamina + 0.8)
          n.grip = 100
        } else {
          n.grip = 100
        }
        if (n.grip <= 0 || n.stamina <= 0) return startFall(n, n.grip <= 0 ? 'grip' : 'pumped')
        // stick held: one move per pace beat
        const now = performance.now()
        // The stick stops right under each bolt until it is clipped: the next move would take the hand past it.
        if (up.current && s.mode === 'climb' && !clipGate(s) && now - lastMove.current > SHOE[shoes].pace) {
          lastMove.current = now
          return stepUp(n)
        }
        return n
      })
    }, 100)
    return () => window.clearInterval(id)
  }, [live, holds, shoes, route.daily])

  /**
   * True when the climber is at the next unclipped bolt: the hand is on the
   * last hold below it and the next move would take the hand above it. You must
   * clip here, from below. Never earlier, never from above, never skipped.
   * Exception: the last bolt. You climb up until the hand is on it, then clip.
   */
  function clipGate(s: Sim): boolean {
    if (s.clips >= bolts.length) return false
    const b = bolts[s.clips]
    // The last bolt is different: climb up to it and touch it, then clip. No clipping it from below.
    if (s.clips === bolts.length - 1) return holds[s.idx].y >= b.y
    if (holds[s.idx].y > b.y) return true // already past it (should not happen): clip before anything else
    if (s.idx >= holds.length - 1) return false
    return holds[s.idx + 1].y > b.y
  }

  /**
   * True when every bolt is clipped and the hand is on the top hold, but the
   * climber has not clipped the chains yet. The send waits here: no celebrate
   * until CLIP puts the rope through the anchor.
   */
  function chainGate(s: Sim): boolean {
    return !s.anchored && s.clips >= bolts.length && s.idx >= holds.length - 1
  }

  /** One move up to the next hold. Refused while an unclipped bolt would be left behind. */
  function stepUp(s: Sim): Sim {
    if (s.idx >= holds.length - 1 || clipGate(s)) return s
    const small = holds[s.idx].type === 'crimp' || holds[s.idx].type === 'sloper'
    const nx = holds[s.idx + 1]
    const n: Sim = { ...s, idx: s.idx + 1, flip: !s.flip, mode: 'reach', skipped: [...s.skipped] }
    n.stamina = Math.max(0, s.stamina - COST[nx.type] * SHOE[shoes].stamina)
    if ((nx.type === 'crimp' || nx.type === 'sloper') && !small) n.grip = 100
    window.setTimeout(() => setSim(c => (c.mode === 'reach' ? { ...c, mode: 'climb' } : c)), 180)
    return n
  }

  function startFall(s: Sim, cause: Cause): Sim {
    const hY = holds[s.idx].y - 1.1
    const clipY = lastClip(s, bolts)
    const d = 2 * Math.max(0, hY - clipY) + 1
    const ground = d >= hY
    window.setTimeout(() => setSim(c => (c.mode === 'fall' ? { ...c, mode: 'lesson' } : c)), 650)
    return { ...s, mode: 'fall', cause, fallM: Math.min(d, hY - 0.2), ground, bodyOffset: Math.min(d, hY - 0.2), falls: s.falls + 1 }
  }

  /** Main thumb button: squeeze on small holds; at a bolt, clip it; otherwise one move up. */
  const act = useCallback(() => {
    if (!live) return
    setSim(s => {
      const h = holds[s.idx]
      if (s.mode !== 'climb') return s
      if (h.type === 'crimp' || h.type === 'sloper') {
        return { ...s, grip: 100, wasted: s.grip > 70 ? s.wasted + 1 : s.wasted }
      }
      if (clipGate(s) || chainGate(s)) return doClip(s)
      const now = performance.now()
      if (now - lastMove.current < 160) return s
      lastMove.current = now
      return stepUp(s)
    })
  }, [live, holds, bolts, shoes]) // eslint-disable-line react-hooks/exhaustive-deps

  /**
   * Clip the next bolt, or the chains at the top. Required: you cannot climb
   * past a bolt without clipping it, and the send only completes once the
   * chains are clipped.
   */
  function doClip(s: Sim): Sim {
    const h = holds[s.idx]
    if (s.mode !== 'climb') return s
    if (chainGate(s)) {
      // Rope through the chains: a short clip beat, then the celebrate.
      window.setTimeout(() => setSim(c => (c.mode === 'clip' && c.anchored ? { ...c, mode: 'complete' } : c)), 420)
      return { ...s, mode: 'clip', anchored: true }
    }
    if (!clipGate(s)) return s
    window.setTimeout(() => setSim(c => (c.mode === 'clip' ? { ...c, mode: 'climb' } : c)), 380)
    const cost = h.type === 'jug' || h.type === 'pocket' ? 0 : h.type === 'rock' ? 2 : 5
    return { ...s, mode: 'clip', clips: s.clips + 1, restBar: Math.min(100, s.restBar + 34), stamina: Math.max(0, s.stamina - cost) }
  }

  const clip = useCallback(() => {
    if (!live) return
    setSim(doClip)
  }, [live, holds, bolts]) // eslint-disable-line react-hooks/exhaustive-deps

  const rest = useCallback(() => {
    if (!live) return
    setSim(s => {
      if (s.mode !== 'climb' || s.clips - s.skipped.length === 0 || s.restBar < 34) return s
      window.setTimeout(() => setSim(c => (c.mode === 'rest' ? { ...c, mode: 'climb', bodyOffset: 0 } : c)), 1300)
      return { ...s, mode: 'rest', restBar: s.restBar - 34, bodyOffset: 0.6 }
    })
  }, [live])

  const climbOn = useCallback(() => {
    setSim(s => {
      const clipY = lastClip(s, bolts)
      let idx = 0
      const nb = s.clips < bolts.length ? bolts[s.clips] : null
      // Back on the wall below the clipped bolt, never above the next unclipped one.
      holds.forEach(h => { if (h.y - 1.1 <= clipY + 0.2 && (!nb || h.y <= nb.y)) idx = h.i })
      return { ...s, idx, skipped: [], mode: 'climb', bodyOffset: 0, grip: 100, stamina: Math.max(s.stamina, 55), cause: null }
    })
  }, [holds, bolts])

  const setUp = (v: boolean) => { up.current = v }
  const pause = (p: boolean) => setSim(s => ({ ...s, mode: p ? 'paused' : s.anchored ? 'complete' : 'climb' }))
  const restart = () => setSim(fresh())

  const context: 'CLIMB' | 'CLIP' | 'GRIP' | 'REST' =
    sim.mode === 'rest' ? 'REST' : onSmall ? 'GRIP' : mustClip ? 'CLIP' : 'CLIMB'

  return {
    sim, holds, bolts, top, hold, handY, harnessY, lastClipY, clippedCount, isClipped, nextBolt, canClip, mustClip, atChains, atLastBolt, belowLastBolt, onSmall, onGood,
    potentialFall, groundRisk, context, act, clip, rest, climbOn, setUp, pause, restart,
  }
}

/** Height of the highest bolt actually clipped (skipped bolts hold nothing). */
function lastClip(s: Sim, bolts: BoltDef[]) {
  if (s.anchored && bolts.length) return bolts[bolts.length - 1].y + 2.5 // the chains sit above the top hold
  for (let i = s.clips - 1; i >= 0; i--) if (!s.skipped.includes(i)) return bolts[i].y
  return 0
}

export type ClimbSim = ReturnType<typeof useClimbSim>
