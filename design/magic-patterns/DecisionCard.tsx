import React from 'react'
import { motion } from 'framer-motion'
import { Clock, X } from 'lucide-react'
import { Camp, Choice, KiliEvent } from '../data/kili'
import { PrimaryButton } from '../components/ui'

const RISK = {
  low: { label: 'Low risk', cls: 'bg-good/15 text-good' },
  med: { label: 'Medium risk', cls: 'bg-warn/20 text-[#7a5410]' },
  high: { label: 'High risk', cls: 'bg-bad/15 text-bad' },
}

/** The camp decision, unchanged in structure: choices show hours, deltas and a risk band; preview, then confirm. */
export function DecisionCard({ camp, event, preview, setPreview, onConfirm, onClose, rm }: {
  key?: React.Key;
  camp: Camp; event: KiliEvent; preview: Choice | null; setPreview: (c: Choice | null) => void; onConfirm: (c: Choice) => void; onClose: () => void; rm: boolean
}) {
  return (
    <motion.div
      initial={{ opacity: 0, x: 16 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: 12, transition: { duration: rm ? 0 : 0.16 } }}
      transition={{ duration: rm ? 0 : 0.24, ease: [0.23, 1, 0.32, 1] }}
      className="paper-grain absolute bottom-4 right-6 top-[76px] flex w-[372px] flex-col rounded-[12px] border border-paper-edge shadow-[0_16px_40px_rgb(0_0_0/0.45)]"
    >
      <div className="flex items-start justify-between px-4 pt-3">
        <div>
          <div className="text-[12px] font-medium text-ink-muted">{camp.name} · {camp.meters.toLocaleString()} m</div>
          <div className="font-display text-[22px] leading-tight text-ink">{event.title}</div>
        </div>
        <button onClick={onClose} aria-label="Close" className="-mr-2 -mt-1 grid h-12 w-12 place-items-center rounded-full text-ink-muted hover:bg-paper-sunk"><X size={20} /></button>
      </div>
      <p className="line-clamp-3 px-4 text-[13px] leading-snug text-ink-soft">{event.text}</p>

      <div className="no-scrollbar mt-2 flex min-h-0 flex-1 flex-col gap-1.5 overflow-y-auto px-4">
        {event.choices.map(c => {
          const sel = preview?.label === c.label
          return (
            <button
              key={c.label}
              onClick={() => setPreview(sel ? null : c)}
              aria-pressed={sel}
              className={`rounded-[8px] border px-3 py-2 text-left transition-colors duration-150 ${sel ? 'border-spruce bg-spruce/10' : 'border-paper-edge bg-paper-raised hover:border-ink-muted'}`}
            >
              <div className="font-display text-[15px] leading-tight text-ink">{c.label}</div>
              <div className="mt-0.5 text-[12px] text-ink-muted">{c.detail}</div>
              <div className="mt-1.5 flex flex-wrap items-center gap-1.5 text-[11px] font-medium">
                <span className="inline-flex h-5 items-center gap-1 rounded-full bg-paper-sunk px-2 text-ink-soft"><Clock size={11} /> {c.hours} h</span>
                <span className={`inline-flex h-5 items-center rounded-full px-2 ${RISK[c.risk].cls}`}>{RISK[c.risk].label}</span>
                <span className="text-ink-muted">{c.riskWhy}</span>
              </div>
            </button>
          )
        })}
      </div>

      <div className="border-t border-paper-edge px-4 py-3">
        <PrimaryButton className="w-full" disabled={!preview} onClick={() => preview && onConfirm(preview)}>
          {preview ? 'Confirm choice' : 'Pick a choice to preview it'}
        </PrimaryButton>
      </div>
    </motion.div>
  )
}
