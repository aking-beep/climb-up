import React from 'react'
import { motion } from 'framer-motion'
import { Star } from 'lucide-react'
import { PaperButton, PrimaryButton, SimTag } from '../components/ui'

/** Marks a behaviour that does not exist in Godot yet and needs implementation. */
export function MechanicTag({ children = 'Proposed mechanic · needs Godot work', className = '' }: { children?: React.ReactNode; className?: string }) {
  return <span className={`inline-flex h-5 items-center whitespace-nowrap rounded-sm border border-dashed border-[#4a7593] bg-[#4a7593]/10 px-1.5 text-[11px] font-semibold text-[#2f5772] ${className}`}>{children}</span>
}

/** Marks behaviour the connected repo already ships (godot/ · APK). Re-implemented here only to be played. */
export function ApkTag({ children = 'Exists in APK', className = '' }: { children?: React.ReactNode; className?: string }) {
  return <span className={`inline-flex h-5 items-center whitespace-nowrap rounded-sm border border-[#2d5a4b] bg-[#2d5a4b]/10 px-1.5 text-[11px] font-semibold text-[#24493d] ${className}`}>{children}</span>
}

/** The existing climb brief (ClimbLevel.brief), restyled: what this climb asks, then Start or back off. */
export function BriefCard({ kicker, title, text, rows, mechanics, existing, onStart, onBack, backLabel, rm }: {
  kicker: string
  title: string
  text: string
  rows: [string, string, 'good' | 'warn' | 'bad' | 'neutral'][]
  mechanics: string[]
  /** Verbs and hazards the APK already has, listed apart from the proposals. */
  existing?: string[]
  onStart: () => void
  onBack: () => void
  backLabel: string
  rm: boolean
}) {
  const tone = { good: 'text-good', warn: 'text-[#7a5410]', bad: 'text-bad', neutral: 'text-ink-soft' }
  return (
    <div className="absolute inset-0 z-40 bg-scrim-soft">
      <motion.div
        role="dialog" aria-modal="true" aria-labelledby="brief-title"
        onKeyDown={e => { if (e.key === 'Escape') onBack() }}
        initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: rm ? 0 : 0.24, ease: [0.23, 1, 0.32, 1] }}
        className="paper-grain absolute bottom-4 right-6 top-4 flex w-[440px] flex-col overflow-hidden rounded-[12px] border border-paper-edge shadow-[0_16px_40px_rgb(0_0_0/0.45)]"
      >
        <div className="shrink-0 px-5 pt-4">
          <div className="flex items-center justify-between gap-2">
            <div className="truncate text-[12px] font-medium text-ink-muted">{kicker}</div>
            <SimTag className="shrink-0">Simulated</SimTag>
          </div>
          <div id="brief-title" className="font-display text-[24px] leading-tight text-ink">{title}</div>
        </div>
        {/* body scrolls; the Start / back-off row below stays pinned and always reachable */}
        <div className="brief-scroll min-h-0 flex-1 overflow-y-auto px-5 pb-3" tabIndex={0} aria-label="Climb briefing">
          <p className="mt-1 text-[13px] leading-snug text-ink-soft">{text}</p>
          <dl className="mt-2.5 divide-y divide-paper-edge border-y border-paper-edge">
            {rows.map(([k, v, t]) => (
              <div key={k} className="grid grid-cols-[124px_1fr] items-baseline gap-3 py-1.5 text-[12.5px] leading-snug">
                <dt className="text-ink-muted">{k}</dt>
                <dd className={`text-right font-semibold ${tone[t]}`}>{v}</dd>
              </div>
            ))}
          </dl>
          {existing && existing.length > 0 && (
            <div className="mt-2.5">
              <ApkTag>Exists in APK · re-played here</ApkTag>
              <ul className="mt-1.5 space-y-0.5 text-[12px] leading-snug text-ink-soft">
                {existing.map(m => <li key={m}>· {m}</li>)}
              </ul>
            </div>
          )}
          <div className="mt-2.5">
            <MechanicTag />
            <ul className="mt-1.5 space-y-0.5 text-[12px] leading-snug text-ink-soft">
              {mechanics.map(m => <li key={m}>· {m}</li>)}
            </ul>
          </div>
        </div>
        <div className="flex shrink-0 gap-2 border-t border-paper-edge px-5 py-3">
          <PaperButton onClick={onBack} className="px-3">{backLabel}</PaperButton>
          <PrimaryButton autoFocus onClick={onStart} className="flex-1">Start climb</PrimaryButton>
        </div>
      </motion.div>
    </div>
  )
}

/** Completion state: headline, stars (60 ms stagger), three facts, what lands on the expedition. */
export function EncounterResult({ kicker, head, sub, stars, facts, lines, primary, onPrimary, onReplay, rm }: {
  kicker: string
  head: string
  sub: string
  stars: number
  facts: [string, string][]
  lines: string[]
  primary: string
  onPrimary: () => void
  onReplay: () => void
  rm: boolean
}) {
  const d = rm ? 0 : 1
  return (
    <motion.div
      initial={{ opacity: 0, x: 16 }} animate={{ opacity: 1, x: 0 }} transition={{ duration: 0.24 * d, ease: [0.23, 1, 0.32, 1] }}
      className="paper-grain absolute bottom-4 right-6 top-4 z-40 flex w-[360px] flex-col rounded-[12px] border border-paper-edge p-5 shadow-[0_16px_40px_rgb(0_0_0/0.45)]"
    >
      <div className="flex items-center justify-between">
        <div className="text-[12px] font-medium text-ink-muted">{kicker}</div>
        <SimTag>Simulated result</SimTag>
      </div>
      <div className="mt-1 font-display text-[30px] leading-[1.05] text-ink">{head}</div>
      <div className="font-display text-[16px] text-ink-soft">{sub}</div>
      <div className="mt-3 flex gap-1">
        {[0, 1, 2].map(i => (
          <motion.span key={i} initial={{ opacity: 0, scale: 0.96, y: 4 }} animate={{ opacity: 1, scale: 1, y: 0 }}
            transition={{ delay: (0.18 + i * 0.06) * d, duration: 0.2 * d, ease: [0.23, 1, 0.32, 1] }}>
            <Star size={28} strokeWidth={1.6} className={i < stars ? 'fill-star text-[#b07e1f]' : 'text-ink-muted/35'} />
          </motion.span>
        ))}
      </div>
      <dl className="mt-3 grid grid-cols-3 divide-x divide-paper-edge border-y border-paper-edge py-2 text-center">
        {facts.map(([k, v]) => <div key={k}><dt className="text-[11px] text-ink-muted">{k}</dt><dd className="tabular text-[15px] font-semibold">{v}</dd></div>)}
      </dl>
      <ul className="mt-3 min-h-0 flex-1 space-y-1.5 overflow-hidden text-[13px] leading-snug text-ink-soft">
        {lines.map(l => <li key={l}>{l}</li>)}
      </ul>
      <div className="mt-3 flex gap-2">
        <PaperButton onClick={onReplay} className="px-3">Replay</PaperButton>
        <PrimaryButton onClick={onPrimary} className="flex-1">{primary}</PrimaryButton>
      </div>
    </motion.div>
  )
}

/** Big round context button (88 dp), same family as the crag context button. */
export function ActionButton({ label, sub, onClick, disabled, tone = 'paper', x, y, size = 88, onDown, onUp }: {
  label: string; sub?: string; onClick?: () => void; disabled?: boolean; tone?: 'paper' | 'route' | 'scrim'; x: number; y: number; size?: number
  onDown?: () => void; onUp?: () => void
}) {
  const bg = tone === 'route' ? 'bg-route text-ink' : tone === 'scrim' ? 'bg-scrim text-paper ring-1 ring-white/20' : 'bg-paper text-ink'
  return (
    <button
      onClick={onClick}
      onPointerDown={onDown}
      onPointerUp={onUp}
      onPointerLeave={onUp}
      disabled={disabled}
      className={`absolute z-20 grid touch-none place-items-center rounded-full shadow-[0_3px_0_rgb(0_0_0/0.35)] transition-[transform,opacity] duration-[120ms] ease-out active:scale-[0.94] disabled:opacity-45 ${bg}`}
      style={{ width: size, height: size, left: x - size / 2, top: y - size / 2 }}
    >
      <span className="flex flex-col items-center leading-none">
        <span className={`font-display ${size >= 80 ? 'text-[17px]' : 'text-[13px]'}`}>{label}</span>
        {sub && <span className="mt-1 text-[11px] opacity-70">{sub}</span>}
      </span>
    </button>
  )
}
