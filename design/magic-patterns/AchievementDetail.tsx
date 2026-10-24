import React from 'react'
import { useGame } from '../state/GameState'
import { Achievement } from '../data/achievements'
import { Modal } from '../overlays/Modal'
import { BadgeGlyph } from '../components/Icons'
import { NewDataTag } from '../components/ui'

export function AchievementDetail({ a, onClose }: { a: Achievement; onClose: () => void }) {
  const { earned } = useGame()
  const held = earned.includes(a.id)
  return (
    <Modal kicker={a.mode === 'crag' ? 'Lion Rock achievement' : 'Expedition achievement · proposed'} title={a.title} onClose={onClose} width={440}>
      <div className="flex items-center gap-4">
        <span className={`grid h-20 w-20 shrink-0 place-items-center rounded-full ${held ? 'bg-spruce text-route ring-[3px] ring-star ring-offset-[3px] ring-offset-paper' : 'border-[3px] border-dashed border-paper-edge text-ink-muted'}`}>
          <BadgeGlyph icon={a.icon} size={36} />
        </span>
        <div>
          <p className="text-[15px] leading-snug text-ink">{a.how}</p>
          <p className="mt-1 text-[13px] text-ink-muted">
            {held ? 'Earned 2 April · logged in the crag save' : a.proposed ? 'Not in the game. Would be checked by the expedition engine at the end of a run.' : 'Not earned yet.'}
          </p>
          {a.proposed && <div className="mt-2"><NewDataTag /></div>}
        </div>
      </div>
    </Modal>
  )
}
