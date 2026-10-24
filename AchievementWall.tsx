import React from 'react'
import { motion } from 'framer-motion'
import { useGame } from '../state/GameState'
import { ACHIEVEMENTS, Achievement } from '../data/achievements'
import { AchievementCard } from '../components/AchievementCard'

/** 12 crag achievements (existing, protected) + 4 proposed expedition ones. */
export function AchievementWall({ onOpen }: { onOpen: (a: Achievement) => void }) {
  const { earned, settings } = useGame()
  const crag = ACHIEVEMENTS.filter(a => a.mode === 'crag')
  const exp = ACHIEVEMENTS.filter(a => a.mode === 'expedition')
  return (
    <div>
      <div className="mb-2 flex items-baseline justify-between">
        <span className="text-[12px] font-semibold text-ember">Lion Rock</span>
        <span className="tabular text-[12px] text-ink-muted">{crag.filter(a => earned.includes(a.id)).length} of {crag.length} · earned by how you climb, never by repeats</span>
      </div>
      <div className="grid grid-cols-4 gap-2">
        {crag.map((a, i) => (
          <motion.div key={a.id} initial={{ opacity: 0, y: 4 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: settings.reducedMotion ? 0 : Math.min(i, 8) * 0.03, duration: settings.reducedMotion ? 0 : 0.18 }}>
            <AchievementCard a={a} held={earned.includes(a.id)} compact onClick={() => onOpen(a)} />
          </motion.div>
        ))}
      </div>
      <div className="mb-2 mt-4 flex items-baseline justify-between">
        <span className="text-[12px] font-semibold text-[#2f5772]">Expeditions · proposed, additive</span>
        <span className="text-[12px] text-ink-muted">Needs approval: achievements are a protected area</span>
      </div>
      <div className="grid grid-cols-4 gap-2">
        {exp.map(a => <AchievementCard key={a.id} a={a} held={false} compact onClick={() => onOpen(a)} />)}
      </div>
    </div>
  )
}
