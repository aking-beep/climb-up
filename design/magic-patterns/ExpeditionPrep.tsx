import React from 'react'
import { useGame } from '../state/GameState'
import { useExpedition } from '../state/Expedition'
import { Hero } from '../components/Hero'
import { BackButton, Chip, PrimaryButton, SimTag } from '../components/ui'
import { PACK, PARTY } from '../data/kili'
import { KILI_PLATE } from '../expedition/MapLayer'
import { TEAM_LOOKS } from '../encounter/team'
import { NPCS } from '../camp/campData'

/**
 * Expedition preparation: between choosing Kilimanjaro and the trek map.
 * Shows the route, the team (including the camp crew by name), the pack.
 * All read-only from existing data; "Begin" opens the gate card on the map.
 */
export function ExpeditionPrep() {
  const g = useGame()
  const x = useExpedition()
  const rm = g.settings.reducedMotion
  const crew = NPCS.filter(n => n.support || n.id === 'neema')
  return (
    <div className="absolute inset-0 overflow-hidden bg-night">
      <img src={KILI_PLATE} alt="" className="absolute inset-0 h-full w-full object-cover opacity-60" />
      <div className="absolute left-7 top-4 z-10 flex items-center gap-3">
        <BackButton dark label="Map" onClick={() => g.go('expedition')} />
        <div className="world-text text-paper">
          <div className="font-display text-[22px] leading-none">Preparation · {x.routeName}</div>
          <div className="mt-1 text-[13px] text-paper/85">{x.days} days · Londorossi Gate, 2,100 m</div>
        </div>
      </div>

      <div className="paper-grain absolute bottom-4 left-7 right-6 top-[78px] grid grid-cols-[1.25fr_1fr] gap-6 rounded-[12px] border border-paper-edge p-5 shadow-[0_16px_40px_rgb(0_0_0/0.45)]">
        <div className="flex min-h-0 flex-col">
          <div className="text-[13px] font-semibold text-ink">The team</div>
          <div className="mt-2 flex items-end gap-1">
            <Figure look={g.look} name="You" role="Lead" rm={rm} />
            {PARTY.filter(m => m.id !== 'you').map((m, i) => <Figure key={m.id} look={TEAM_LOOKS[i]} name={m.name} role={m.role} rm={rm} />)}
          </div>
          <div className="mt-4 text-[13px] font-semibold text-ink">Camp crew <span className="font-normal text-ink-muted">· they carry, cook and set every camp</span></div>
          <div className="mt-2 flex items-end gap-1">
            {crew.map(n => <Figure key={n.id} look={n.look} name={n.name} role={n.role} rm={rm} />)}
          </div>
          <p className="mt-auto text-[12px] text-ink-muted">Crew members are named characters with their own dialogue in camp. They do not change any engine value.</p>
        </div>
        <div className="flex min-h-0 flex-col">
          <div className="text-[13px] font-semibold text-ink">Pack</div>
          <div className="mt-2 flex flex-wrap gap-1.5">{PACK.gear.map(gr => <Chip key={gr.id} tone="neutral">{gr.label} · found on the way</Chip>)}</div>
          <dl className="mt-3 divide-y divide-paper-edge border-y border-paper-edge text-[14px]">
            <div className="flex justify-between py-2"><dt className="text-ink-muted">Medicine</dt><dd className="font-semibold">{PACK.medicineMax} doses</dd></div>
            <div className="flex justify-between py-2"><dt className="text-ink-muted">Food & supplies</dt><dd className="font-semibold">{x.stats.supplies}</dd></div>
            <div className="flex justify-between py-2"><dt className="text-ink-muted">Played climbs on this route</dt><dd className="font-semibold">Lava Tower · Barranco · Karanga Ridge* · Summit</dd></div>
          </dl>
          <p className="mt-2 text-[12px] text-ink-muted">* Karanga Ridge is a proposed encounter (presentation only).</p>
          <div className="mt-auto flex items-center gap-2">
            <SimTag>Values from existing route data</SimTag>
            <PrimaryButton className="ml-auto" size="lg" onClick={() => { g.setIntent('open-decision'); g.go('expedition') }}>Begin at the gate</PrimaryButton>
          </div>
        </div>
      </div>
    </div>
  )
}

function Figure({ look, name, role, rm }: { key?: React.Key; look: Parameters<typeof Hero>[0]['look']; name: string; role: string; rm: boolean }) {
  return (
    <div className="flex w-[78px] flex-col items-center">
      <Hero look={look} pose="idle" view="front" size={62} kit="trek" phase={name.length * 0.4} reducedMotion={rm} />
      <div className="mt-0.5 font-display text-[14px] leading-tight text-ink">{name}</div>
      <div className="text-center text-[11px] leading-tight text-ink-muted">{role}</div>
    </div>
  )
}
