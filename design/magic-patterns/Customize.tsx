import React, { useState } from 'react'
import { motion } from 'framer-motion'
import { useGame } from '../state/GameState'
import { BackButton, PaperButton, PrimaryButton, SimTag } from '../components/ui'
import { Climber, Pose } from '../components/Climber'
import { RopeCoil } from '../components/Icons'
import { HUB_PLATE } from './Hub'
import { SlotTabs, Slot } from '../customize/SlotTabs'
import { OptionGrid } from '../customize/OptionGrid'
import { DEFAULT_LOOK, DEFAULT_LOOK_F } from '../data/cosmetics'

/** Screen 5 — cosmetic only. Locks are skill conditions; there is nothing to buy. */
export function Customize() {
  const g = useGame()
  const [slot, setSlot] = useState<Slot>('body')
  const [view, setView] = useState<'front' | 'back'>('front')
  const [pose, setPose] = useState<Pose>('idle')
  const rm = g.settings.reducedMotion

  const pick = (s: Slot) => {
    setSlot(s)
    // show the part where it is visible
    if (s === 'pack' || s === 'chalk') setView('back')
    else if (s === 'jacket' || s === 'harness' || s === 'body') setView('front')
  }

  return (
    <div className="absolute inset-0 overflow-hidden bg-[#2a241d]">
      <img src={HUB_PLATE} alt="" className="absolute inset-0 h-full w-full scale-110 object-cover object-[25%_50%] blur-[4px] brightness-[0.62]" />
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(40%_60%_at_27%_55%,rgb(255_220_170/0.22),transparent_70%)]" />

      <div className="absolute left-7 top-4 flex items-center gap-3">
        <BackButton dark label="Profile" onClick={() => g.go('profile')} />
        <div className="world-text">
          <div className="font-display text-[24px] leading-none text-paper">Your climber</div>
          <div className="mt-1 text-[12px] text-paper/80">Male or female · cosmetic only · nothing to buy</div>
        </div>
      </div>

      {/* live preview on a ledge */}
      <div className="absolute bottom-0 left-0 top-0 w-[460px]">
        <svg viewBox="0 0 460 90" className="absolute bottom-0 left-0 w-full" aria-hidden>
          <path d="M40 90 Q50 40 120 34 L330 30 Q400 34 420 90 Z" fill="#6f4a31" stroke="#2a1c12" strokeWidth="2" />
          <path d="M120 34 L330 30 Q360 32 372 44 L110 48 Q112 38 120 34 Z" fill="#9c6a45" />
        </svg>
        <motion.div
          key={view}
          initial={{ opacity: rm ? 1 : 0.4, scaleX: rm ? 1 : 0.92 }}
          animate={{ opacity: 1, scaleX: 1 }}
          transition={{ duration: rm ? 0 : 0.16, ease: [0.23, 1, 0.32, 1] }}
          className="absolute bottom-[50px] left-[130px]"
        >
          <Climber look={g.look} pose={pose} view={view} size={180} reducedMotion={rm} className={pose === 'idle' && !rm ? 'anim-breathe' : ''} />
        </motion.div>
        <div className="absolute bottom-[56px] left-[330px]">
          <RopeCoil color={g.look.rope} size={56} />
        </div>

        <div className="absolute bottom-[78px] left-7"><SimTag className="!bg-paper/90">Simulated save</SimTag></div>
        <div className="absolute bottom-4 left-7 flex gap-2">
          <Seg value={view} set={v => setView(v as 'front' | 'back')} items={[['front', 'Front'], ['back', 'Back']]} />
          <Seg value={pose} set={v => setPose(v as Pose)} items={[['idle', 'Stand'], ['climbA', 'Climb'], ['celebrate', 'Summit']]} />
          <button onClick={() => g.go('character')} className="h-12 rounded-full bg-scrim px-4 text-[14px] font-medium text-paper ring-1 ring-white/10 transition-colors duration-150 hover:bg-black/70">All moves</button>
        </div>
      </div>

      <div className="paper-grain absolute bottom-4 right-6 top-4 flex w-[420px] overflow-hidden rounded-[12px] border border-paper-edge shadow-[0_16px_40px_rgb(0_0_0/0.45)]">
        <SlotTabs slot={slot} onPick={pick} />
        <div className="flex min-w-0 flex-1 flex-col">
          {/* options scroll inside the page; Reset / Done stay pinned below them */}
          <div className="brief-scroll min-h-0 flex-1 overflow-y-auto px-4 pb-2 pt-4">
            <OptionGrid slot={slot} />
          </div>
          <div className="flex shrink-0 items-center gap-2 border-t border-paper-edge px-4 py-3">
            <PaperButton onClick={() => g.setLook(g.look.body === 'f' ? DEFAULT_LOOK_F : DEFAULT_LOOK)} className="px-3">Reset</PaperButton>
            <PrimaryButton className="flex-1" onClick={() => g.go('profile')}>Done</PrimaryButton>
          </div>
        </div>
      </div>
    </div>
  )
}

function Seg({ value, set, items }: { value: string; set: (v: string) => void; items: [string, string][] }) {
  return (
    <div className="flex rounded-full bg-scrim p-1 ring-1 ring-white/10">
      {items.map(([k, l]) => (
        <button key={k} onClick={() => set(k)} aria-pressed={value === k}
          className={`h-10 rounded-full px-3.5 text-[14px] font-medium transition-colors duration-150 ${value === k ? 'bg-paper text-ink' : 'text-paper/85 hover:text-paper'}`}>{l}</button>
      ))}
    </div>
  )
}
