import React from 'react'
import { motion } from 'framer-motion'
import { Star } from 'lucide-react'
import { Route, STYLE_LABEL, fmtTime } from '../data/routes'
import { Achievement } from '../data/achievements'
import { PaperButton, PrimaryButton } from '../components/ui'
import { BadgeGlyph } from '../components/Icons'

export interface Outcome {
  style: 'onsight' | 'flash' | 'redpoint' | 'top' | ''
  seconds: number
  falls: number
  stars: number
  starsBefore: number
  challengeDone: boolean
  achievements: Achievement[]
  unlocked: Route | null
  rank: string
}

/** Results reveal: headline style, then stars one by one (60 ms stagger), then what changed. */
export function ResultsCard({ route, o, onNext, onReplay, onCrag, rm }: { route: Route; o: Outcome; onNext: () => void; onReplay: () => void; onCrag: () => void; rm: boolean }) {
  const d = rm ? 0 : 1
  const head = o.style === '' ? 'Lowered off' : `${STYLE_LABEL[o.style]}!`
  return (
    <motion.div
      initial={{ opacity: 0, x: 16 }} animate={{ opacity: 1, x: 0 }}
      transition={{ duration: 0.24 * d, ease: [0.23, 1, 0.32, 1] }}
      className="paper-grain absolute bottom-4 right-6 top-4 z-30 flex w-[360px] flex-col rounded-[12px] border border-paper-edge p-5 shadow-[0_16px_40px_rgb(0_0_0/0.45)]"
    >
      <div className="text-[12px] font-medium text-ink-muted">Lion Rock · grade {route.grade}</div>
      <div className="font-display text-[34px] leading-[1.05] text-ink">{head}</div>
      <div className="font-display text-[18px] text-ink-soft">{route.name}</div>

      <div className="mt-3 flex items-center gap-4">
        <div className="flex gap-1">
          {[0, 1, 2].map(i => (
            <motion.span
              key={i}
              initial={{ opacity: 0, scale: 0.96, y: 4 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              transition={{ delay: (0.18 + i * 0.06) * d, duration: 0.2 * d, ease: [0.23, 1, 0.32, 1] }}
            >
              <Star size={30} strokeWidth={1.6} className={i < o.stars ? 'fill-star text-[#b07e1f]' : 'text-ink-muted/35'} />
            </motion.span>
          ))}
        </div>
        <div className="text-[12px] leading-tight text-ink-muted">Send · Clean ·<br />{route.challenge[0]} {o.challengeDone ? '✓' : '—'}</div>
      </div>

      <dl className="mt-3 grid grid-cols-3 divide-x divide-paper-edge border-y border-paper-edge py-2 text-center">
        <div><dt className="text-[11px] text-ink-muted">Time</dt><dd className="tabular text-[15px] font-semibold">{fmtTime(Math.round(o.seconds))}</dd></div>
        <div><dt className="text-[11px] text-ink-muted">Falls</dt><dd className="tabular text-[15px] font-semibold">{o.falls}</dd></div>
        <div><dt className="text-[11px] text-ink-muted">Your goes</dt><dd className="text-[15px] font-semibold">{o.rank}</dd></div>
      </dl>

      <div className="mt-3 flex min-h-0 flex-1 flex-col gap-2">
        {o.achievements.map(a => (
          <motion.div
            key={a.id}
            initial={{ opacity: 0, y: 4 }} animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.36 * d, duration: 0.2 * d }}
            className="flex items-center gap-3 rounded-[8px] bg-spruce px-3 py-2 text-spruce-ink"
          >
            <span className="grid h-9 w-9 shrink-0 place-items-center rounded-full border-2 border-dashed border-route text-route"><BadgeGlyph icon={a.icon} size={18} /></span>
            <span className="leading-tight"><span className="block text-[11px] text-spruce-ink/70">Achievement</span><span className="block font-display text-[16px]">{a.title}</span></span>
          </motion.div>
        ))}
        {o.unlocked && (
          <div className="rounded-[8px] border border-paper-edge bg-paper-raised px-3 py-2 text-[13px] leading-snug text-ink-soft">
            New route open: <span className="font-semibold text-ink">{o.unlocked.name} ({o.unlocked.grade})</span> · {o.unlocked.skill}
          </div>
        )}
        {!o.challengeDone && o.style !== '' && (
          <div className="text-[13px] leading-snug text-ink-muted">Challenge · {route.challenge[1]}</div>
        )}
      </div>

      <div className="mt-3 flex gap-2">
        <PaperButton onClick={onCrag} className="px-3">Crag</PaperButton>
        <PaperButton onClick={onReplay} className="px-3">Replay</PaperButton>
        <PrimaryButton onClick={onNext} className="flex-1">Next route</PrimaryButton>
      </div>
    </motion.div>
  )
}
