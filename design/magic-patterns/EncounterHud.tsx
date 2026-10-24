import React from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import { Pause } from 'lucide-react'
import { IconButton } from '../components/ui'

/**
 * Shared top band for every Phase 2 encounter. Same anatomy as the crag HUD:
 * stamina top-left (colour + word, bar length = what the trek left you),
 * one caption centre-top, progress and pause top-right.
 */
export function EncounterHud({ title, sub, stamina, barMax = 100, note, caption, captionTone = 'info', right, onPause }: {
  title: string
  sub: string
  stamina: number
  /** Bar length set by camp condition (existing Condition.of coupling). */
  barMax?: number
  note?: string
  caption?: string | null
  captionTone?: 'info' | 'warn' | 'bad' | 'good'
  right?: React.ReactNode
  onPause: () => void
}) {
  const pct = Math.max(0, Math.min(100, (stamina / barMax) * 100))
  const word = pct >= 60 ? 'Steady' : pct >= 30 ? 'Tiring' : 'Spent'
  const fill = pct >= 60 ? 'bg-stam-high' : pct >= 30 ? 'bg-stam-mid' : 'bg-stam-low'
  const tone = captionTone === 'bad' ? 'bg-bad text-paper' : captionTone === 'warn' ? 'bg-warn text-ink' : captionTone === 'good' ? 'bg-good text-paper' : 'bg-scrim text-paper ring-1 ring-white/15'
  return (
    <>
      <div className="absolute left-7 top-3 z-20 w-[224px]">
        <div className="world-text flex items-baseline justify-between gap-2 text-paper">
          <span className="truncate font-display text-[15px]">{title}</span>
          <span className="tabular shrink-0 text-[12px] text-paper/80">{sub}</span>
        </div>
        <div className="mt-1.5 rounded-full bg-scrim p-[3px] ring-1 ring-white/10" style={{ width: `${Math.max(48, barMax)}%` }}>
          <div className="relative h-[10px] overflow-hidden rounded-full bg-black/40">
            <div className={`absolute inset-y-0 left-0 rounded-full ${fill} ${pct < 30 ? 'anim-pulse-low' : ''}`} style={{ width: `${pct}%`, transition: 'width 120ms linear' }} />
          </div>
        </div>
        <div className="world-text mt-1 flex justify-between gap-2 text-[12px] text-paper">
          <span className="whitespace-nowrap">Stamina · <span className="font-semibold">{word}</span></span>
          {note && <span className="truncate text-paper/80">{note}</span>}
        </div>
      </div>

      <div className="pointer-events-none absolute left-1/2 top-3 z-20 -translate-x-1/2">
        <AnimatePresence mode="wait">
          {caption && (
            <motion.div key={caption} initial={{ opacity: 0, y: -4 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} transition={{ duration: 0.16, ease: [0.23, 1, 0.32, 1] }}
              className={`max-w-[360px] rounded-full px-4 py-2 text-center text-[13px] font-medium leading-tight ${tone}`}>
              {caption}
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      <div className="absolute right-6 top-3 z-20 flex items-start gap-2">
        {right}
        <IconButton dark label="Pause" onClick={onPause}><Pause size={20} className="fill-paper" /></IconButton>
      </div>
    </>
  )
}
