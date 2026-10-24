import React from 'react'
import { Lock, Sun } from 'lucide-react'
import { useGame } from '../state/GameState'
import { ROUTES, isUnlocked } from '../data/routes'

/** Fast, thumb-reachable route switching; mirrors the topo lines. */
export function GradeStrip({ selected, recommended, onSelect }: { selected: string; recommended: string; onSelect: (id: string) => void }) {
  const { progress } = useGame()
  return (
    <div className="flex items-center gap-1 rounded-[12px] bg-scrim p-1 ring-1 ring-white/10">
      {ROUTES.map(r => {
        const open = isUnlocked(r.id, progress)
        const stars = progress[r.id]?.stars ?? 0
        const sel = r.id === selected
        return (
          <button
            key={r.id}
            onClick={() => onSelect(r.id)}
            aria-label={`${r.name} ${r.grade}${open ? '' : ', locked'}`}
            className={`relative flex h-12 w-[50px] flex-col items-center justify-center rounded-[8px] transition-colors duration-150 ${sel ? 'bg-paper text-ink' : 'text-paper hover:bg-white/10'}`}
          >
            {open ? (
              <span className="font-display text-[17px] leading-none">{r.grade === 'Lesson' ? 'L' : r.grade}</span>
            ) : (
              <Lock size={15} className={sel ? 'text-ink-muted' : 'text-paper/60'} />
            )}
            <span className="mt-1 flex gap-[2px]">
              {[0, 1, 2].map(i => (
                <span key={i} className={`h-[5px] w-[5px] rounded-full ${i < stars ? 'bg-star' : sel ? 'bg-ink/15' : 'bg-white/20'}`} />
              ))}
            </span>
            {r.id === recommended && <span className="absolute -top-1 right-0.5 h-2.5 w-2.5 rounded-full border-2 border-[#2a2018] bg-ember" />}
          </button>
        )
      })}
      <span className="mx-1 h-8 w-px bg-white/15" />
      <button
        onClick={() => onSelect('daily')}
        className={`flex h-12 items-center gap-1.5 rounded-[8px] px-3 transition-colors duration-150 ${selected === 'daily' ? 'bg-route text-ink' : 'text-route hover:bg-white/10'}`}
      >
        <Sun size={17} />
        <span className="font-display text-[16px]">Daily</span>
      </button>
    </div>
  )
}
