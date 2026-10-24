import React from 'react'
import { Pause } from 'lucide-react'
import { Route } from '../data/routes'
import { ClimbSim } from './useClimbSim'
import { IconButton } from '../components/ui'
import { QuickdrawIcon } from '../components/Icons'

/**
 * Top band, kept thin so the wall above the climber stays visible.
 * Left: stamina (colour + word). Centre: rope state. Right: pause.
 */
export function HudTop({ s, route, onPause, leftHanded }: { s: ClimbSim; route: Route; onPause: () => void; leftHanded: boolean }) {
  const { sim } = s
  const st = Math.round(sim.stamina)
  const word = st >= 50 ? 'Steady' : st >= 25 ? 'Tiring' : 'Pumped'
  const fill = st >= 50 ? 'bg-stam-high' : st >= 25 ? 'bg-stam-mid' : 'bg-stam-low'
  const fall = s.potentialFall
  const ropeTone = s.groundRisk ? 'text-[#ff9a80]' : fall > 4 ? 'text-route' : 'text-paper'

  return (
    <>
      <div className={`absolute top-3 ${leftHanded ? 'right-[88px]' : 'left-7'} w-[210px]`}>
        <div className="world-text flex items-baseline justify-between text-paper">
          <span className="font-display text-[15px]">{route.name} · {route.grade}</span>
          <span className="tabular text-[12px] text-paper/80">{fmt(sim.seconds)}</span>
        </div>
        <div className="mt-1.5 rounded-full bg-scrim p-[3px] ring-1 ring-white/10">
          <div className="relative h-[10px] overflow-hidden rounded-full bg-black/40">
            <div className={`absolute inset-y-0 left-0 rounded-full ${fill} ${st < 25 ? 'anim-pulse-low' : ''}`} style={{ width: `${st}%`, transition: 'width 120ms linear' }} />
          </div>
        </div>
        <div className="world-text mt-1 flex justify-between text-[12px] text-paper">
          <span>Stamina · <span className="font-semibold">{word}</span></span>
          <span className="tabular text-paper/80">falls {sim.falls} of {route.falls}</span>
        </div>
      </div>

      {/* rope: what a fall would cost right now */}
      <div className="absolute left-1/2 top-3 -translate-x-1/2">
        <div className="flex h-9 items-center gap-2 rounded-full bg-scrim px-3 text-[13px] text-paper ring-1 ring-white/10">
          <QuickdrawIcon size={16} className="text-paper/80" />
          <span className="tabular">Clipped <span className="font-semibold">{s.clippedCount}</span> of {s.bolts.length}</span>
          <span className="h-4 w-px bg-white/20" />
          <span className={`tabular ${ropeTone}`}>
            {sim.anchored ? 'Clipped to the chains' : s.atChains ? 'Clip the chains' : s.groundRisk ? 'Ground fall possible' : `Fall now ≈ ${fall.toFixed(1)} m`}
          </span>
        </div>
      </div>

      <div className={`absolute top-3 ${leftHanded ? 'left-7' : 'right-6'}`}>
        <IconButton dark label="Pause" onClick={onPause}><Pause size={20} className="fill-paper" /></IconButton>
      </div>
    </>
  )
}

function fmt(s: number) {
  const t = Math.floor(s)
  return `${Math.floor(t / 60)}:${String(t % 60).padStart(2, '0')}`
}
