import React, { useEffect, useMemo, useRef, useState } from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import { useGame } from '../state/GameState'
import { DAILY, ROUTES, isUnlocked } from '../data/routes'
import { ACHIEVEMENTS } from '../data/achievements'
import { useClimbSim } from '../climb/useClimbSim'
import { ClimbWorld } from '../climb/ClimbWorld'
import { HudTop } from '../climb/HudTop'
import { ProgressRail } from '../climb/ProgressRail'
import { TouchControls } from '../climb/TouchControls'
import { FallCard } from '../climb/FallCard'
import { Outcome, ResultsCard } from '../climb/ResultsCard'
import { PauseMenu } from '../climb/PauseMenu'
import { SimTag } from '../components/ui'

/** Screen 3 — the climb. HUD hugs the edges; the wall and climber own the middle. */
export function CragClimb() {
  const g = useGame()
  const route = g.routeId === 'daily' ? DAILY : ROUTES.find(r => r.id === g.routeId) ?? ROUTES[0]
  const s = useClimbSim(route, g.shoes, g.hudState, g.intent)
  const [paused, setPaused] = useState(false)
  const [hint, setHint] = useState<string | null>(null)
  const recorded = useRef(false)
  const lh = g.settings.leftHanded
  const prior = g.progress[route.id]
  const highBolt = prior?.sends ? 0 : prior?.highBolt ?? 0

  // keyboard stand-ins for the touch controls (desktop review only)
  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.key === 'w' || e.key === 'ArrowUp') s.setUp(true)
      if (e.key === ' ') { e.preventDefault(); s.act() }
      if (e.key === 'r') s.rest()
      if (e.key === 'c') s.clip()
    }
    const up = (e: KeyboardEvent) => { if (e.key === 'w' || e.key === 'ArrowUp') s.setUp(false) }
    window.addEventListener('keydown', down)
    window.addEventListener('keyup', up)
    return () => { window.removeEventListener('keydown', down); window.removeEventListener('keyup', up) }
  }, [s])

  const outcome: Outcome | null = useMemo(() => {
    if (s.sim.mode !== 'complete') return null
    const attempts = prior?.attempts ?? 0
    const style: Outcome['style'] = s.sim.falls === 0 ? (attempts === 0 ? 'onsight' : 'redpoint') : 'top'
    const challengeDone = s.sim.falls === 0 && s.sim.wasted === 0
    const stars = 1 + (style !== 'top' ? 1 : 0) + (challengeDone && style !== 'top' ? 1 : 0)
    const idx = ROUTES.findIndex(r => r.id === route.id)
    const next = idx >= 0 && idx < ROUTES.length - 1 ? ROUTES[idx + 1] : null
    const unlocked = next && !isUnlocked(next.id, g.progress) ? next : null
    const newIds: string[] = []
    if (style === 'redpoint' && !g.earned.includes('redpoint')) newIds.push('redpoint')
    if (route.id === 'the-pinch' && challengeDone && !g.earned.includes('economy')) newIds.push('economy')
    if (route.daily && style !== 'top' && attempts === 0 && !g.earned.includes('daily-clean')) newIds.push('daily-clean')
    return {
      style, seconds: s.sim.seconds, falls: s.sim.falls, stars, starsBefore: prior?.stars ?? 0, challengeDone,
      achievements: ACHIEVEMENTS.filter(a => newIds.includes(a.id)), unlocked, rank: attempts ? `best of ${attempts + 1}` : 'first go',
    }
  }, [s.sim.mode]) // eslint-disable-line react-hooks/exhaustive-deps

  // persist the send once, in live play only
  useEffect(() => {
    if (outcome && g.hudState === 'live' && !recorded.current) {
      recorded.current = true
      window.setTimeout(() => {
        g.recordSend(route.id, outcome.style, Math.round(outcome.seconds), outcome.stars)
        g.earn(outcome.achievements.map(a => a.id))
      }, 50)
    }
    if (!outcome) recorded.current = false
  }, [outcome]) // eslint-disable-line react-hooks/exhaustive-deps

  const flash = (t: string) => { setHint(t); window.setTimeout(() => setHint(null), 1800) }
  const blocked = paused || s.sim.mode === 'lesson' || s.sim.mode === 'complete' || g.hudState !== 'live'
  const lowerOff = () => g.go('crag')

  return (
    <div className="absolute inset-0 overflow-hidden">
      <ClimbWorld s={s} highBolt={highBolt} />

      {s.sim.mode !== 'complete' && (
        <>
          <HudTop s={s} route={route} onPause={() => { setPaused(true); s.pause(true) }} leftHanded={lh} />
          <ProgressRail s={s} highBolt={highBolt} side={lh ? 'left' : 'right'} />
          <TouchControls
            s={s}
            leftHanded={lh}
            scale={g.settings.controlSize / 100}
            disabled={blocked}
            showSpecs={g.settings.showSpecs}
            onJump={() => flash('No blank rock above. JUMP is for leaps (Leap of Faith, Thunderhead).')}
          />
        </>
      )}

      {/* state captions and transient hints, centred above the climber */}
      <AnimatePresence>
        {(hint || s.sim.mode === 'rest' || s.sim.mode === 'clip' || (s.mustClip && s.sim.mode === 'climb') || (s.belowLastBolt && s.sim.mode === 'climb') || (s.onGood && s.sim.stamina < 95 && s.sim.mode === 'climb')) && (
          <motion.div
            key={hint ?? (s.mustClip && s.sim.mode === 'climb' ? (s.atChains ? 'must-anchor' : s.atLastBolt ? 'must-clip-last' : 'must-clip') : s.belowLastBolt && s.sim.mode === 'climb' ? 'below-last' : s.sim.anchored ? 'anchored' : s.sim.mode)}
            initial={{ opacity: 0, y: 4 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }}
            transition={{ duration: 0.16, ease: [0.23, 1, 0.32, 1] }}
            className="world-text pointer-events-none absolute left-1/2 top-[58px] -translate-x-1/2 whitespace-nowrap text-[14px] font-medium text-paper"
          >
            {hint ?? (s.sim.mode === 'rest' ? 'Resting on the rope · stamina coming back' : s.sim.mode === 'clip' ? (s.sim.anchored ? 'Clipped into the chains · route sent' : 'Clipped · rest bar +1') : s.atChains ? 'At the top · clip into the chains to finish (CLIP or C)' : s.atLastBolt ? 'Hand on the last bolt · clip it now (CLIP or C)' : s.belowLastBolt ? 'Last bolt · climb up and touch it before you clip' : s.mustClip ? 'Bolt above · clip it from below to climb on (CLIP or C)' : 'Shaking out on a big hold')}
          </motion.div>
        )}
      </AnimatePresence>

      {g.hudState !== 'live' && s.sim.mode !== 'complete' && (
        <div className="absolute bottom-3 left-1/2 -translate-x-1/2"><SimTag>State preview · choose “Live sim” to play</SimTag></div>
      )}
      {g.hudState === 'live' && s.sim.mode === 'climb' && s.sim.idx === 0 && s.sim.seconds < 6 && (
        <div className="world-text pointer-events-none absolute bottom-[150px] left-1/2 -translate-x-1/2 text-center text-[14px] text-paper">
          Hold the stick up or tap CLIMB <span className="text-paper/70">(W / ↑ / space)</span><br />
          <span className="text-paper/70">Every bolt is mandatory · you stop right under it until you tap CLIP (or C)</span><br />
          <span className="text-paper/70">The last bolt is different · climb up and touch it, then clip</span><br />
          <span className="text-paper/70">The send counts once you clip the chains at the top</span><br /><SimTag className="mt-1">Simulated climbing</SimTag>
        </div>
      )}

      {s.sim.mode === 'lesson' && <FallCard s={s} route={route} onLower={lowerOff} reducedMotion={g.settings.reducedMotion} />}

      {outcome && (
        <ResultsCard
          route={route}
          o={outcome}
          rm={g.settings.reducedMotion}
          onCrag={() => g.go('crag')}
          onReplay={() => { g.setIntent(null); g.setHudState('normal'); window.setTimeout(() => g.setHudState('live'), 0) }}
          onNext={() => { if (outcome.unlocked) g.setRouteId(outcome.unlocked.id); g.go('crag') }}
        />
      )}

      <AnimatePresence>
        {paused && (
          <PauseMenu
            route={route}
            onResume={() => { setPaused(false); s.pause(false) }}
            onSettings={() => g.setOverlay('settings')}
            onLower={lowerOff}
          />
        )}
      </AnimatePresence>
    </div>
  )
}
