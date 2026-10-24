import React, { useEffect, useState } from 'react'
import { AnimatePresence } from 'framer-motion'
import { Shirt } from 'lucide-react'
import { useGame } from '../state/GameState'
import { BackButton, PaperButton } from '../components/ui'
import { Climber } from '../components/Climber'
import { HUB_PLATE } from './Hub'
import { ProfileSummary } from '../profile/ProfileSummary'
import { Passport } from '../profile/Passport'
import { AchievementWall } from '../profile/AchievementWall'
import { AchievementDetail } from '../profile/AchievementDetail'
import { Achievement } from '../data/achievements'

type Tab = 'summary' | 'passport' | 'achievements'

/** Screen 4 — one climber across both modes, as a field-journal spread. */
export function Profile() {
  const g = useGame()
  const [tab, setTab] = useState<Tab>(g.intent === 'achievements' ? 'achievements' : 'summary')
  const [open, setOpen] = useState<Achievement | null>(null)
  useEffect(() => { if (g.intent === 'achievements') setTab('achievements') }, [g.intent])

  return (
    <div className="absolute inset-0 overflow-hidden bg-[#2a241d]">
      <img src={HUB_PLATE} alt="" className="absolute inset-0 h-full w-full scale-110 object-cover blur-[6px] brightness-[0.55]" />

      <div className="absolute left-7 right-6 top-4 flex items-center gap-3">
        <BackButton dark label="Hub" onClick={() => g.go('hub')} />
        <div className="world-text font-display text-[24px] text-paper">Climber’s journal</div>
      </div>

      <div className="paper-grain absolute bottom-4 left-7 right-6 top-[72px] flex overflow-hidden rounded-[12px] border border-paper-edge shadow-[0_16px_40px_rgb(0_0_0/0.45)]">
        {/* left page: who you are */}
        <div className="relative flex w-[248px] shrink-0 flex-col border-r border-paper-edge">
          <button onClick={() => g.go('customize')} aria-label="Edit your climber" className="group relative block h-[168px] shrink-0 overflow-hidden text-left">
            <img src={HUB_PLATE} alt="" className="absolute inset-0 h-full w-full object-cover object-[20%_40%]" />
            <svg viewBox="0 0 248 60" className="absolute bottom-0 left-0 w-full" preserveAspectRatio="none" aria-hidden>
              <path d="M0 60 L0 34 Q40 18 90 24 Q140 30 170 20 Q210 10 248 26 L248 60 Z" fill="#7a5638" />
              <path d="M0 60 L0 44 Q60 34 124 40 Q190 46 248 38 L248 60 Z" fill="#5c412a" />
            </svg>
            <div className="absolute bottom-[22px] left-1/2 -translate-x-1/2">
              <Climber look={g.look} pose="idle" size={92} reducedMotion={g.settings.reducedMotion} />
            </div>
            <span className="absolute right-2 top-2 rounded-full bg-scrim px-2.5 py-1 text-[12px] font-medium text-paper ring-1 ring-white/15 transition-colors duration-150 group-hover:bg-black/70">Edit climber</span>
          </button>
          <div className="flex min-h-0 flex-1 flex-col px-4 pb-4 pt-2.5">
            <div className="font-display text-[22px] leading-tight text-ink">Your climber</div>
            <div className="text-[12.5px] leading-snug text-ink-muted">{g.look.body === 'f' ? 'Female' : 'Male'} · Lead · Lion Rock and Kilimanjaro</div>
            <div className="mt-auto pt-2">
              <PaperButton className="w-full" onClick={() => g.go('customize')}><Shirt size={18} /> Customize climber</PaperButton>
            </div>
          </div>
        </div>

        {/* right page: tabs swap in place */}
        <div className="flex min-w-0 flex-1 flex-col px-5 pt-3">
          <div className="flex items-center gap-1 border-b border-paper-edge">
            {([['summary', 'Summary'], ['passport', 'World Passport'], ['achievements', 'Achievements']] as [Tab, string][]).map(([k, l]) => (
              <button key={k} onClick={() => setTab(k)} aria-pressed={tab === k}
                className={`-mb-px h-12 border-b-2 px-3 font-display text-[16px] transition-colors duration-150 ${tab === k ? 'border-spruce text-ink' : 'border-transparent text-ink-muted hover:text-ink'}`}>
                {l}
              </button>
            ))}
          </div>
          <div className="brief-scroll min-h-0 flex-1 overflow-y-auto pb-2 pt-3">
            {tab === 'summary' && <ProfileSummary />}
            {tab === 'passport' && <Passport />}
            {tab === 'achievements' && <AchievementWall onOpen={setOpen} />}
          </div>
        </div>
      </div>

      <AnimatePresence>{open && <AchievementDetail a={open} onClose={() => setOpen(null)} />}</AnimatePresence>
    </div>
  )
}
