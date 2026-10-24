import React from 'react'

/** Redline annotation shown when the rail's "Spec overlay" is on. Not game UI. */
export function SpecNote({ x, y, w = 180, children }: { x: number; y: number; w?: number; children: React.ReactNode }) {
  return (
    <div
      className="pointer-events-none absolute z-50 rounded-[4px] border border-[#ff3b7f] bg-[#ff3b7f]/90 px-1.5 py-1 font-body text-[11px] font-medium leading-snug text-white"
      style={{ left: x, top: y, width: w }}
    >
      {children}
    </div>
  )
}

/** Outline a hit area with its size. */
export function SpecBox({ x, y, w, h, label }: { x: number; y: number; w: number; h: number; label: string }) {
  return (
    <div className="pointer-events-none absolute z-50 border border-dashed border-[#ff3b7f]" style={{ left: x, top: y, width: w, height: h }}>
      <span className="absolute -top-4 left-0 whitespace-nowrap bg-[#ff3b7f] px-1 text-[10px] font-semibold text-white">{label}</span>
    </div>
  )
}
