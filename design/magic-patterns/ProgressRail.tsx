import React from 'react'
import { ClimbSim } from './useClimbSim'

/** Vertical route progress on the screen edge: bolts, high point, you, the anchor. */
export function ProgressRail({ s, highBolt, side }: { s: ClimbSim; highBolt: number; side: 'left' | 'right' }) {
  const H = 150
  const pct = (m: number) => H - (m / (s.top + 1)) * H
  const you = Math.max(0, s.handY - 1.1 - s.sim.bodyOffset)
  const hp = highBolt > 0 ? s.bolts[highBolt - 1]?.y : null
  return (
    <div className={`absolute top-[76px] ${side === 'right' ? 'right-[30px]' : 'left-[30px]'} flex flex-col items-center`} aria-label="Route progress">
      <div className="world-text mb-1 text-[11px] font-semibold text-paper">Top</div>
      <div className="relative w-[18px] rounded-full bg-scrim ring-1 ring-white/10" style={{ height: H }}>
        <div className="absolute left-1/2 top-0 bottom-0 w-[2px] -translate-x-1/2 bg-white/25" />
        <div className="absolute bottom-0 left-1/2 w-[2px] -translate-x-1/2 bg-route" style={{ height: H - pct(you), transition: 'height 200ms cubic-bezier(0.23,1,0.32,1)' }} />
        {s.bolts.map(b => (
          <span key={b.i} className={`absolute left-1/2 h-[6px] w-[6px] -translate-x-1/2 -translate-y-1/2 rounded-full border ${s.isClipped(b.i) ? 'border-route bg-route' : 'border-paper/70 bg-transparent'}`} style={{ top: pct(b.y) }} />
        ))}
        <span className={`absolute left-1/2 top-[4px] h-[9px] w-[9px] -translate-x-1/2 -translate-y-1/2 rounded-full border-2 ${s.sim.anchored ? 'border-route bg-route' : 'border-paper/80 bg-transparent'}`} title="Top chains" />
        {hp != null && <span className="absolute left-[-5px] right-[-5px] h-[2px] -translate-y-1/2 bg-chalk" style={{ top: pct(hp) }} title="Your high point" />}
        <span className="absolute left-1/2 h-[12px] w-[12px] -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-paper bg-ember" style={{ top: pct(you), transition: 'top 200ms cubic-bezier(0.23,1,0.32,1)' }} />
      </div>
      <div className="world-text mt-1 text-[11px] tabular text-paper/85">{Math.round(you)} m</div>
    </div>
  )
}
