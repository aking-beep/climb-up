import React from 'react'
import { useGame, Settings } from '../state/GameState'
import { Modal } from './Modal'

/** One Settings sheet, reachable from the hub, menus and pause (fixes B3). */
export function SettingsSheet() {
  const g = useGame()
  const s = g.settings
  const set = (patch: Partial<Settings>) => g.setSettings({ ...s, ...patch })

  return (
    <Modal kicker="Settings" title="Sound, controls and display" onClose={() => g.setOverlay(null)} width={640}>
      <div className="grid grid-cols-2 gap-x-6">
        <section>
          <H>Sound</H>
          <Slider label="Music" value={s.music} min={0} max={100} unit="%" onChange={v => set({ music: v })} />
          <Slider label="Effects" value={s.effects} min={0} max={100} unit="%" onChange={v => set({ effects: v })} />
          <Row label="Vibration" on={s.vibration} set={v => set({ vibration: v })} />
          <H>Display</H>
          <Row label="Reduced motion" hint="No parallax, sway or camera kick" on={s.reducedMotion} set={v => set({ reducedMotion: v })} />
          <div className="flex h-12 items-center justify-between">
            <span className="text-[14px] text-ink">Graphics</span>
            <div className="flex rounded-full bg-paper-sunk p-1">
              {(['low', 'high'] as const).map(q => (
                <button key={q} onClick={() => set({ graphics: q })} className={`h-9 rounded-full px-3 text-[13px] font-medium capitalize transition-colors duration-150 ${s.graphics === q ? 'bg-spruce text-spruce-ink' : 'text-ink-soft'}`}>{q}</button>
              ))}
            </div>
          </div>
        </section>
        <section>
          <H>Controls</H>
          <Slider label="Control size" value={s.controlSize} min={85} max={130} unit="%" onChange={v => set({ controlSize: v })} />
          <Row label="Left-handed layout" hint="Stick on the right, actions on the left" on={s.leftHanded} set={v => set({ leftHanded: v })} />
          {/* live preview of the control cluster at the chosen size */}
          <div className="mt-2 flex h-[86px] items-center justify-center gap-3 rounded-[8px] bg-ink/85" style={{ flexDirection: s.leftHanded ? 'row-reverse' : 'row' }}>
            <span className="rounded-full border-2 border-white/40" style={{ width: 60 * s.controlSize / 100, height: 60 * s.controlSize / 100 }} />
            <span className="flex-1" />
            <span className="rounded-full bg-paper" style={{ width: 44 * s.controlSize / 100, height: 44 * s.controlSize / 100 }} />
          </div>
          <p className="mt-2 text-[12px] leading-snug text-ink-muted">Usage log and FPS counter stay in Advanced, as today.</p>
        </section>
      </div>
    </Modal>
  )
}

function H({ children }: { children: React.ReactNode }) {
  return <div className="mt-2 mb-0.5 text-[12px] font-semibold text-ember">{children}</div>
}

function Row({ label, hint, on, set }: { label: string; hint?: string; on: boolean; set: (v: boolean) => void }) {
  return (
    <button onClick={() => set(!on)} role="switch" aria-checked={on} className="flex min-h-12 w-full items-center justify-between py-1 text-left">
      <span>
        <span className="block text-[14px] text-ink">{label}</span>
        {hint && <span className="block text-[12px] text-ink-muted">{hint}</span>}
      </span>
      <span className={`relative h-7 w-12 shrink-0 rounded-full transition-colors duration-150 ${on ? 'bg-spruce' : 'bg-ink/20'}`}>
        <span className={`absolute top-1 h-5 w-5 rounded-full bg-paper-raised shadow transition-transform duration-150 ease-out ${on ? 'translate-x-6' : 'translate-x-1'}`} />
      </span>
    </button>
  )
}

function Slider({ label, value, min, max, unit, onChange }: { label: string; value: number; min: number; max: number; unit: string; onChange: (v: number) => void }) {
  return (
    <label className="block py-1.5">
      <span className="flex justify-between text-[14px] text-ink"><span>{label}</span><span className="tabular text-ink-muted">{value}{unit}</span></span>
      <input type="range" min={min} max={max} value={value} onChange={e => onChange(Number(e.target.value))} className="mt-1 h-6 w-full accent-[#1f3d34]" />
    </label>
  )
}
