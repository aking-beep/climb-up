import React from 'react'
import { Flag } from 'lucide-react'
import { CAMPS } from '../data/kili'

/** The objective, always in view: how far, how many camps, what stands in the way. */
export function SummitCard({ at }: { at: number }) {
  const here = CAMPS[at]
  const summit = CAMPS[CAMPS.length - 1]
  const toGo = summit.meters - here.meters
  const camps = CAMPS.length - 1 - at
  const pct = (here.meters - CAMPS[0].meters) / (summit.meters - CAMPS[0].meters)
  return (
    <div className="w-[208px] rounded-[12px] bg-scrim p-3 text-paper ring-1 ring-white/10">
      <div className="flex items-center gap-2">
        <Flag size={16} className="text-route" />
        <span className="font-display text-[16px] leading-none">Uhuru Peak</span>
        <span className="tabular ml-auto text-[12px] text-paper/80">5,895 m</span>
      </div>
      <div className="mt-2 h-[6px] overflow-hidden rounded-full bg-black/40">
        <div className="h-full rounded-full bg-route" style={{ width: `${pct * 100}%`, transition: 'width 280ms cubic-bezier(0.23,1,0.32,1)' }} />
      </div>
      <div className="tabular mt-1.5 text-[12px] text-paper/85">{toGo.toLocaleString()} m to go · {camps} camp{camps === 1 ? '' : 's'} · summit night ahead</div>
    </div>
  )
}
