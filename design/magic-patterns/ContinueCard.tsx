import React from 'react'
import { Play } from 'lucide-react'

/** The primary action on the hub: resume the last session, whichever mode it was. */
export function ContinueCard({ onClick }: { onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      className="group flex h-[72px] items-center gap-3 rounded-[10px] bg-spruce pl-3 pr-5 text-left text-spruce-ink shadow-[0_3px_0_#0f211b,0_14px_30px_rgb(0_0_0/0.35)] transition-[transform,background-color] duration-[120ms] ease-out hover:bg-spruce-hover active:translate-y-[1px] active:scale-[0.98]"
    >
      <span className="grid h-12 w-12 place-items-center rounded-full bg-spruce-ink text-spruce">
        <Play size={22} className="ml-0.5 fill-spruce" />
      </span>
      <span>
        <span className="block text-[12px] text-spruce-ink/75">Continue · Expedition</span>
        <span className="block font-display text-[21px] leading-tight">Kilimanjaro, Day 6</span>
        <span className="block text-[13px] text-spruce-ink/80">Karanga Camp · “The extra day” is waiting</span>
      </span>
    </button>
  )
}
