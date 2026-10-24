import React from 'react'
import { motion } from 'framer-motion'
import { Eye, Lock, Sun } from 'lucide-react'
import { useGame } from '../state/GameState'
import { Route, ROUTES, STYLE_LABEL, fmtTime } from '../data/routes'
import { Chip, JournalPanel, PaperButton, PrimaryButton, Stars } from '../components/ui'
import { QuickdrawIcon, RopeCoil, ShoeIcon } from '../components/Icons'

interface Props {
  key?: React.Key
  route: Route
  locked: boolean
  recommended: boolean
  onRead: () => void
  onTieIn: () => void
  coach?: boolean
}

/** The objective, as a page in the climbing journal. */
export function RouteCard({ route, locked, recommended, onRead, onTieIn, coach }: Props) {
  const g = useGame()
  const rec = g.progress[route.id]
  const prev = ROUTES[ROUTES.findIndex(r => r.id === route.id) - 1]
  const protection = route.longestM >= 5 ? 'run-out' : route.longestM >= 3.5 ? 'spaced' : 'well bolted'

  return (
    <JournalPanel className="flex h-full flex-col p-4">
      <motion.div
        className="flex min-h-0 flex-1 flex-col"
        initial={{ opacity: 0, y: 6 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: g.settings.reducedMotion ? 0 : 0.18, ease: [0.23, 1, 0.32, 1] }}
      >
        <div className="flex items-center justify-between">
          <span className="text-[12px] font-medium text-ink-muted">
            {route.daily ? 'Daily route · same for every climber' : route.grade === 'Lesson' ? 'Lion Rock · lesson' : `Lion Rock · ${route.level} moves`}
          </span>
          {recommended && !route.daily && <Chip tone="bad" className="!bg-ember !text-paper">Next up</Chip>}
          {route.daily && <Chip tone="route"><Sun size={12} /> 4-day streak</Chip>}
        </div>

        <div className="mt-1 flex items-end gap-3">
          <div className="font-display text-[50px] leading-[0.9] text-ink">{route.grade === 'Lesson' ? 'L' : route.grade}</div>
          <div className="pb-1">
            <div className="font-display text-[23px] leading-tight text-ink">{route.name}</div>
            <div className="text-[13px] text-ink-muted">Skill · {route.skill}</div>
          </div>
        </div>

        {/* topo facts: three separate axes, as crag.gd describes them */}
        <dl className="mt-2.5 grid grid-cols-4 divide-x divide-paper-edge border-y border-paper-edge py-1.5 text-center">
          <Fact k="Height" v={`${route.heightM} m`} />
          <Fact k="Bolts" v={String(route.bolts)} />
          <Fact k="1st bolt" v={`${route.firstBoltM} m`} />
          <Fact k="Bolting" v={protection} />
        </dl>

        <p className="mt-2 line-clamp-1 text-[13px] leading-snug text-ink-soft"><span className="font-semibold text-ink">Crux · </span>{route.crux}</p>

        {locked ? (
          <div className="mt-3 flex flex-1 items-center gap-3 rounded-[8px] bg-paper-sunk p-3">
            <Lock size={20} className="shrink-0 text-ink-muted" />
            <p className="text-[13px] leading-snug text-ink-soft">Send <span className="font-semibold text-ink">{prev?.name}</span> to open this route. Routes open one at a time, easiest first.</p>
          </div>
        ) : (
          <>
            <div className="mt-2.5 flex items-center justify-between">
              <div>
                <div className="text-[12px] text-ink-muted">Your record</div>
                <div className="text-[14px] font-medium text-ink">
                  {rec && rec.sends > 0
                    ? `${STYLE_LABEL[rec.best]} · ${fmtTime(rec.bestSeconds)}`
                    : rec && rec.attempts > 0
                      ? `${rec.attempts} go${rec.attempts > 1 ? 's' : ''} · high point bolt ${rec.highBolt} of ${route.bolts}`
                      : route.daily ? 'First go today: climb it clean to onsight' : 'Not tried · first go can onsight'}
                </div>
              </div>
              <div className="text-right">
                <Stars n={rec?.stars ?? 0} size={15} />
                <div className="text-[11px] text-ink-muted">Send · Clean · {route.challenge[0]}</div>
              </div>
            </div>

            {/* equipment: shoes are the only gear with an effect, and they already exist */}
            <div className="mt-2.5">
              <div className="mb-1 flex items-center justify-between text-[12px] text-ink-muted">
                <span>Shoes</span>
                <span className="flex items-center gap-2">
                  <span className="flex items-center gap-1"><QuickdrawIcon size={14} /> {route.bolts} draws</span>
                  <button onClick={() => g.go('customize')} className="flex items-center gap-1 rounded-full pr-1 hover:text-ink" aria-label="Rope colour (cosmetic)">
                    <RopeCoil color={g.look.rope} size={18} /> rope
                  </button>
                </span>
              </div>
              <div className="grid grid-cols-2 gap-1.5">
                {(['neutral', 'aggressive'] as const).map(s => (
                  <button
                    key={s}
                    onClick={() => g.setShoes(s)}
                    aria-pressed={g.shoes === s}
                    className={`flex h-12 items-center gap-2 rounded-[8px] border px-2 text-left transition-colors duration-150 ${g.shoes === s ? 'border-spruce bg-spruce/10' : 'border-paper-edge bg-paper-raised hover:border-ink-muted'}`}
                  >
                    <ShoeIcon aggressive={s === 'aggressive'} size={26} />
                    <span className="leading-tight">
                      <span className="block text-[13px] font-semibold text-ink">{s === 'neutral' ? 'Neutral' : 'Aggressive'}</span>
                      <span className="block text-[11px] text-ink-muted">{s === 'neutral' ? 'Slower · less stamina' : 'Faster · more stamina'}</span>
                    </span>
                  </button>
                ))}
              </div>
            </div>
          </>
        )}

        <div className="relative mt-auto flex gap-2 pt-3">
          <PaperButton onClick={onRead} disabled={locked} className="px-3"><Eye size={18} /> Read</PaperButton>
          <PrimaryButton onClick={onTieIn} disabled={locked} className="flex-1">Tie in</PrimaryButton>
          {coach && !locked && (
            <motion.span
              initial={{ opacity: 0, y: 4 }} animate={{ opacity: 1, y: 0 }}
              className="pointer-events-none absolute -top-6 right-2 rounded-full bg-ember px-2.5 py-0.5 text-[12px] font-semibold text-paper"
            >Tap Tie in to start ↓</motion.span>
          )}
        </div>
      </motion.div>
    </JournalPanel>
  )
}

function Fact({ k, v }: { k: string; v: string }) {
  return (
    <div className="px-1">
      <dt className="text-[11px] text-ink-muted">{k}</dt>
      <dd className="whitespace-nowrap text-[13px] font-semibold text-ink">{v}</dd>
    </div>
  )
}
