import React from 'react'
import { ChevronRight } from 'lucide-react'

interface Props {
  left: string
  top: string
  align: 'left' | 'right'
  place: string
  mode: string
  line: string
  extra?: React.ReactNode
  onClick: () => void
}

/**
 * A mode entrance pinned to a real place in the art: a survey pin on the
 * landmark and a field-journal tag hung beside it.
 */
export function Destination({ left, top, align, place, mode, line, extra, onClick }: Props) {
  return (
    <div className="absolute" style={{ left, top }}>
      {/* survey pin */}
      <span className="absolute -left-[7px] -top-[7px] block h-[14px] w-[14px] rounded-full border-[3px] border-paper bg-ember shadow-[0_1px_3px_rgb(0_0_0/0.5)]" />
      <span className={`absolute top-0 block h-px w-8 bg-paper/90 ${align === 'right' ? 'left-[7px]' : 'right-[7px]'}`} />
      <button
        onClick={onClick}
        className={`group absolute -top-6 flex items-stretch overflow-hidden rounded-[8px] border border-paper-edge bg-paper-raised/95 text-left shadow-[0_10px_24px_rgb(0_0_0/0.35)] transition-[transform] duration-[160ms] ease-[cubic-bezier(0.23,1,0.32,1)] hover:-translate-y-0.5 active:scale-[0.97] ${align === 'right' ? 'left-10' : 'right-10'}`}
        style={{ transformOrigin: align === 'right' ? 'left center' : 'right center' }}
      >
        <span className="w-1.5 bg-spruce" />
        <span className="py-2 pl-3 pr-2">
          <span className="block text-[12px] font-semibold text-ember">{mode}</span>
          <span className="block font-display text-[22px] leading-[1.05] text-ink">{place}</span>
          <span className="mt-1 block whitespace-nowrap text-[13px] text-ink-soft">{line}</span>
          {extra && <span className="mt-0.5 block whitespace-nowrap text-[12px] text-ink-muted">{extra}</span>}
        </span>
        <span className="grid w-9 place-items-center text-ink-muted transition-colors duration-150 group-hover:text-spruce">
          <ChevronRight size={22} />
        </span>
      </button>
    </div>
  )
}
