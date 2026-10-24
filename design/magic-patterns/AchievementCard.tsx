import React from 'react'
import { Achievement } from '../data/achievements'
import { BadgeGlyph } from './Icons'

/**
 * Achievement card. Held: inked stamp with a gold ring. Not yet: faded, dashed.
 * Proposed: blue dashed edge so it is never mistaken for a shipped rule.
 */
export function AchievementCard({ a, held, compact, onClick }: { key?: React.Key; a: Achievement; held: boolean; compact?: boolean; onClick?: () => void }) {
  const proposed = !!a.proposed
  return (
    <button
      onClick={onClick}
      className={`flex w-full items-center gap-2.5 rounded-[8px] border text-left transition-[transform,border-color] duration-[120ms] ease-out active:scale-[0.97] ${compact ? 'min-h-[56px] p-2' : 'p-3'} ${
        proposed ? 'border-dashed border-[#4a7593] bg-[#4a7593]/5' : held ? 'border-paper-edge bg-paper-raised hover:border-spruce' : 'border-dashed border-paper-edge bg-transparent hover:border-ink-muted'
      }`}
    >
      <span
        className={`grid shrink-0 place-items-center rounded-full ${compact ? 'h-10 w-10' : 'h-14 w-14'} ${
          held ? 'bg-spruce text-route ring-2 ring-star ring-offset-2 ring-offset-paper-raised' : proposed ? 'border-2 border-dashed border-[#4a7593] text-[#4a7593]' : 'border-2 border-dashed border-paper-edge text-ink-muted/70'
        }`}
      >
        <BadgeGlyph icon={a.icon} size={compact ? 19 : 26} />
      </span>
      <span className="min-w-0">
        <span className={`block truncate font-display ${compact ? 'text-[14px]' : 'text-[18px]'} leading-tight ${held ? 'text-ink' : 'text-ink-soft'}`}>{a.title}</span>
        <span className="block text-[11px] text-ink-muted">{held ? 'Earned' : proposed ? 'Proposed' : 'Not yet'}</span>
      </span>
    </button>
  )
}
