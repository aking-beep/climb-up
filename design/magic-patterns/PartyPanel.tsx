import React, { useState } from 'react'
import { Choice, PARTY, STATS, StatKey } from '../data/kili'
import { Meter } from '../components/ui'

const RING: Record<string, string> = { ok: '#8fd16b', tired: '#c9922e', sick: '#b06ad0', down: '#b8432a' }
const WORD: Record<string, string> = { ok: 'Well', tired: 'Tired', sick: 'Unwell', down: 'Sent down' }

/** Party and condition, always visible; a previewed choice shows its deltas here first. */
export function PartyPanel({ stats, preview }: { stats: Record<StatKey, number>; preview: Choice | null }) {
  const [focus, setFocus] = useState<string | null>(null)
  const f = PARTY.find(m => m.id === focus)
  return (
    <div className="relative flex h-full flex-col rounded-[12px] bg-scrim p-3 text-paper ring-1 ring-white/10">
      <div className="text-[12px] font-semibold text-route">Party</div>
      <div className="mt-1.5 flex justify-between">
        {PARTY.map(m => (
          <button key={m.id} onClick={() => setFocus(focus === m.id ? null : m.id)} className="flex w-12 flex-col items-center" aria-label={`${m.name}, ${WORD[m.state]}`}>
            <span className="relative grid h-10 w-10 place-items-center rounded-full" style={{ boxShadow: `0 0 0 3px ${RING[m.state]}` }}>
              <span className="grid h-10 w-10 place-items-center rounded-full font-display text-[15px] text-paper" style={{ background: m.color }}>{m.name[0]}</span>
            </span>
            <span className="mt-1 text-[12px] leading-none">{m.name}</span>
            <span className="mt-0.5 text-[11px] leading-none" style={{ color: RING[m.state] }}>{WORD[m.state]}</span>
          </button>
        ))}
      </div>
      {f && (
        <div className="absolute left-3 right-3 top-[96px] z-10 rounded-[8px] bg-paper-raised p-2.5 text-[12px] leading-snug text-ink shadow-lg">
          <span className="font-semibold">{f.name}, {f.role}.</span> {f.note}
        </div>
      )}
      <div className="mt-3 text-[12px] font-semibold text-route">Condition</div>
      <div className="mt-1 flex flex-1 flex-col justify-between">
        {STATS.map(s => (
          <Meter key={s.key} dark label={s.label} value={stats[s.key]} badHigh={s.badHigh} preview={preview?.deltas[s.key] ?? 0} />
        ))}
      </div>
    </div>
  )
}
