import React from 'react'
import { Pill, Cookie, Gem } from 'lucide-react'
import { PACK } from '../data/kili'

/** What the party carries into the next climb: medicine, snacks, gear found this attempt, artifacts. */
export function PackStrip() {
  return (
    <div className="flex h-12 items-center gap-3 rounded-full bg-scrim px-4 text-[13px] text-paper ring-1 ring-white/10">
      <span className="flex items-center gap-1.5" title="Medicine doses"><Pill size={16} className="text-[#e07a7a]" /><span className="tabular">{PACK.medicine}/{PACK.medicineMax}</span></span>
      <span className="flex items-center gap-1.5" title="Snacks"><Cookie size={16} className="text-[#d8a868]" /><span className="tabular">{PACK.snacks}</span></span>
      <span className="h-5 w-px bg-white/20" />
      <span className="flex items-center gap-1.5" title={PACK.gear.map(g => `${g.label}${g.found ? '' : ' (not found)'}`).join(', ')}>
        <span>Gear</span>
        <span className="flex gap-1">
          {PACK.gear.map(g => (
            <span key={g.id} className={`h-2.5 w-2.5 rounded-full ${g.found ? 'bg-paper' : 'border border-dashed border-white/50'}`} />
          ))}
        </span>
        <span className="tabular text-paper/75">{PACK.gear.filter(g => g.found).length}/{PACK.gear.length}</span>
      </span>
      <span className="h-5 w-px bg-white/20" />
      <span className="flex items-center gap-1.5" title="Artifacts carried"><Gem size={16} className="text-route" /><span className="tabular">{PACK.artifacts}</span></span>
    </div>
  )
}
