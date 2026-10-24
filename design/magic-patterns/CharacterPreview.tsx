import React, { useState } from 'react'
import { useGame } from '../state/GameState'
import { Hero, HeroPose, HeroView, BUILDS } from '../components/Hero'
import { BackButton, SimTag } from '../components/ui'
import { HUB_PLATE } from './Hub'
import { Kit } from '../components/Hero'

const CLIPS: { id: HeroPose; label: string; view: HeroView; kit: Kit; seat?: boolean }[] = [
  { id: 'idle', label: 'Idle breathing', view: 'front', kit: 'climb' },
  { id: 'walk', label: 'Walk', view: 'side', kit: 'trek' },
  { id: 'run', label: 'Run', view: 'side', kit: 'trek' },
  { id: 'climb', label: 'Climb', view: 'back', kit: 'climb' },
  { id: 'reach', label: 'Reach', view: 'back', kit: 'climb' },
  { id: 'mantle', label: 'Mantle', view: 'back', kit: 'climb' },
  { id: 'rest', label: 'Rest', view: 'side', kit: 'trek' },
  { id: 'fall', label: 'Fall', view: 'front', kit: 'climb' },
  { id: 'celebrate', label: 'Celebrate', view: 'front', kit: 'climb' },
  { id: 'talk', label: 'Talk', view: 'front', kit: 'camp' },
  { id: 'sit', label: 'Sit at camp', view: 'side', kit: 'camp', seat: true },
]

/** Updated character gameplay preview: the climber at gameplay scale, every clip, and the dialogue close-up. */
export function CharacterPreview() {
  const g = useGame()
  const rm = g.settings.reducedMotion
  const [clip, setClip] = useState(0)
  const c = CLIPS[clip]
  const b = BUILDS[g.build]
  return (
    <div className="absolute inset-0 overflow-hidden bg-night">
      <img src={HUB_PLATE} alt="" className="absolute inset-0 h-full w-full object-cover opacity-70" />
      <div className="absolute left-7 top-4 z-10 flex items-center gap-3">
        <BackButton dark label="Climber" onClick={() => g.go('customize')} />
        <div className="world-text text-paper">
          <div className="font-display text-[22px] leading-none">Your climber</div>
          <div className="mt-1 text-[13px] text-paper/85">{g.look.body === 'f' ? 'Female' : 'Male'} · {b.name} · every move</div>
        </div>
      </div>

      {/* gameplay scale: the climber as it appears in a level */}
      <div className="absolute bottom-[96px] left-7 top-[84px] w-[300px] overflow-hidden rounded-[12px] bg-[#4a453f] ring-1 ring-white/10">
        <div className="absolute inset-x-0 bottom-0 h-[64px] bg-[#5a4e42]" />
        <div className="absolute inset-x-0 bottom-[60px] h-[5px] bg-[#9a8a70]" />
        <div className="absolute bottom-[62px] left-1/2 -translate-x-1/2">
          <Hero look={g.look} pose={c.id} view={c.view} size={96} kit={c.kit} seat={c.seat} reducedMotion={rm} />
        </div>
        <div className="absolute left-3 top-2 rounded-full bg-scrim px-2.5 py-1 text-[12px] text-paper">Gameplay scale · 96 dp</div>
      </div>

      {/* dialogue close-up */}
      <div className="paper-grain absolute bottom-[96px] left-[344px] right-6 top-[84px] flex gap-4 rounded-[12px] border border-paper-edge p-4">
        <div className="relative w-[190px] shrink-0 overflow-hidden rounded-[10px] bg-paper-sunk">
          <Hero look={g.look} pose={c.id === 'talk' ? 'talk' : 'idle'} view="front" crop="bust" size={190} kit={c.kit} expression={c.id === 'fall' ? 'worried' : c.id === 'celebrate' ? 'happy' : c.id === 'rest' ? 'tired' : c.id === 'climb' || c.id === 'reach' || c.id === 'mantle' ? 'effort' : 'talk'} reducedMotion={rm} className="absolute bottom-0" />
        </div>
        <div className="flex min-w-0 flex-1 flex-col">
          <div className="text-[12px] font-medium text-ink-muted">Close-up dialogue view · expression follows the clip</div>
          <div className="mt-1 font-display text-[22px] leading-tight text-ink">{c.label}</div>
          <p className="mt-1 text-[14px] leading-snug text-ink-soft">One rig drives every view. Hands and feet are solved per frame, so on the wall they land on holds; at camp the same body sits, talks and walks. Cosmetic slots from Customize ride on every clip.</p>
          <div className="mt-auto flex items-center gap-2">
            <button onClick={() => g.go('customize')} className="h-11 rounded-[6px] border border-paper-edge bg-paper-raised px-4 font-display text-[15px] text-ink transition-[transform,border-color] duration-[120ms] ease-out hover:border-spruce active:scale-[0.97]">Customize look</button>
            <SimTag>Vector reference · final art from characters_hd.py</SimTag>
          </div>
        </div>
      </div>

      <div className="no-scrollbar absolute bottom-4 left-7 right-6 flex gap-1.5 overflow-x-auto">
        {CLIPS.map((k, i) => (
          <button key={k.id} onClick={() => setClip(i)}
            className={`h-12 shrink-0 whitespace-nowrap rounded-[6px] px-3 text-[14px] font-medium transition-colors duration-150 ${i === clip ? 'bg-paper text-ink' : 'bg-scrim text-paper ring-1 ring-white/15 hover:bg-black/70'}`}>
            {k.label}
          </button>
        ))}
      </div>
    </div>
  )
}
