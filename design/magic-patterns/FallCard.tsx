import React from 'react'
import { motion } from 'framer-motion'
import { Route } from '../data/routes'
import { ClimbSim } from './useClimbSim'
import { PaperButton, PrimaryButton } from '../components/ui'

const LESSON = {
  grip: { title: 'Your grip ran out on the tiny holds', fix: 'Squeeze GRIP once when the ring drops below the white mark. Not before, and not in a flurry.' },
  pumped: { title: 'Pumped out', fix: 'Big holds refill stamina while you stay still on them. After a clip, sit back on the rope with REST.' },
}

/** Every fall names its cause and the fix (existing fall-lesson rule). */
export function FallCard({ s, route, onLower, reducedMotion }: { s: ClimbSim; route: Route; onLower: () => void; reducedMotion: boolean }) {
  const l = LESSON[s.sim.cause ?? 'grip']
  const out = s.sim.falls >= route.falls
  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }}
      transition={{ duration: reducedMotion ? 0 : 0.22, ease: [0.23, 1, 0.32, 1] }}
      className="paper-grain absolute left-1/2 top-[62px] z-30 w-[400px] -translate-x-1/2 rounded-[12px] border border-paper-edge p-4 shadow-[0_16px_40px_rgb(0_0_0/0.45)]"
    >
      <div className="flex items-center justify-between text-[12px] font-medium">
        <span className={s.sim.ground ? 'text-bad' : 'text-ember'}>{s.sim.ground ? 'Ground fall' : `Fell ${s.sim.fallM.toFixed(1)} m onto the rope`}</span>
        <span className="tabular text-ink-muted">Fall {s.sim.falls} of {route.falls}</span>
      </div>
      <div className="mt-1 font-display text-[21px] leading-tight text-ink">{l.title}</div>
      <p className="mt-1.5 text-[14px] leading-snug text-ink-soft">{l.fix}</p>
      <div className="mt-3 flex gap-2">
        {out ? (
          <PrimaryButton className="flex-1" onClick={onLower}>Lower off · see the go</PrimaryButton>
        ) : (
          <>
            <PaperButton onClick={onLower}>Lower off</PaperButton>
            <PrimaryButton className="flex-1" onClick={s.climbOn}>Climb on from {s.clippedCount ? `bolt ${s.clippedCount}` : 'the ground'}</PrimaryButton>
          </>
        )}
      </div>
    </motion.div>
  )
}
