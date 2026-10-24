import React, { useEffect, useState } from 'react'
import { Flame } from 'lucide-react'

/** Today's route as a torn ticket: same route for every climber, resets at 00:00 UTC. */
export function DailyTicket({ onClick }: { onClick: () => void }) {
  const left = useCountdown()
  return (
    <button
      onClick={onClick}
      className="group relative flex h-[72px] items-stretch overflow-hidden rounded-[10px] bg-paper-raised text-left shadow-[0_3px_0_#cdc2ad,0_14px_30px_rgb(0_0_0/0.3)] transition-[transform] duration-[120ms] ease-out active:translate-y-[1px] active:scale-[0.98]"
    >
      <span className="flex flex-col justify-center pl-4 pr-4">
        <span className="block text-[12px] font-semibold text-ember">Daily route</span>
        <span className="block font-display text-[19px] leading-tight text-ink">Ember Ribbon · 6a+</span>
        <span className="tabular block text-[12px] text-ink-muted">New route in {left}</span>
      </span>
      {/* perforation */}
      <span className="relative w-0 border-l-2 border-dashed border-paper-edge">
        <span className="absolute -left-[7px] -top-[6px] h-3 w-3 rounded-full bg-[#141210]/0 shadow-[0_0_0_20px_transparent]" />
      </span>
      <span className="flex w-[72px] flex-col items-center justify-center bg-paper-sunk">
        <Flame size={20} className="text-ember" />
        <span className="tabular font-display text-[20px] leading-none text-ink">4</span>
        <span className="text-[11px] text-ink-muted">day streak</span>
      </span>
    </button>
  )
}

function useCountdown() {
  const [now, setNow] = useState(() => Date.now())
  useEffect(() => {
    const id = window.setInterval(() => setNow(Date.now()), 1000)
    return () => window.clearInterval(id)
  }, [])
  const d = new Date(now)
  const end = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() + 1)
  const s = Math.max(0, Math.floor((end - now) / 1000))
  const h = Math.floor(s / 3600)
  const m = Math.floor((s % 3600) / 60)
  const sec = s % 60
  return `${h}:${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}`
}
