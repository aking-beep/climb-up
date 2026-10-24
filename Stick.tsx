import React, { useEffect, useRef, useState } from 'react'

export interface StickV { x: number; y: number }

/**
 * Floating virtual stick (existing TouchStick behaviour): the base appears
 * where the thumb lands inside the zone; 44 dp travel; WASD / arrows mirror
 * it on desktop. Emits a normalised vector, y negative = up.
 */
export function Stick({ onChange, zoneW = 360, zoneH = 260, left = 0, axis = 'xy', label }: {
  onChange: (v: StickV) => void
  zoneW?: number
  zoneH?: number
  left?: number
  axis?: 'x' | 'xy'
  label?: string
}) {
  const [s, setS] = useState<{ bx: number; by: number; kx: number; ky: number } | null>(null)
  const zone = useRef<HTMLDivElement>(null)
  const keys = useRef(new Set<string>())
  const cb = useRef(onChange)
  cb.current = onChange

  useEffect(() => {
    const emit = () => {
      const k = keys.current
      const x = (k.has('ArrowRight') || k.has('d') ? 1 : 0) - (k.has('ArrowLeft') || k.has('a') ? 1 : 0)
      const y = axis === 'x' ? 0 : (k.has('ArrowDown') || k.has('s') ? 1 : 0) - (k.has('ArrowUp') || k.has('w') ? 1 : 0)
      cb.current({ x, y })
    }
    const down = (e: KeyboardEvent) => { if (['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'a', 'd', 'w', 's'].includes(e.key)) { keys.current.add(e.key); emit() } }
    const up = (e: KeyboardEvent) => { if (keys.current.delete(e.key)) emit() }
    window.addEventListener('keydown', down)
    window.addEventListener('keyup', up)
    return () => { window.removeEventListener('keydown', down); window.removeEventListener('keyup', up) }
  }, [axis])

  const scaleK = () => { const r = zone.current!.getBoundingClientRect(); return { r, k: r.width / zoneW } }
  const start = (e: React.PointerEvent) => {
    if (!zone.current) return
    const { r, k } = scaleK()
    ;(e.target as HTMLElement).setPointerCapture(e.pointerId)
    setS({ bx: (e.clientX - r.left) / k, by: (e.clientY - r.top) / k, kx: 0, ky: 0 })
  }
  const move = (e: React.PointerEvent) => {
    if (!s || !zone.current) return
    const { r, k } = scaleK()
    let dx = (e.clientX - r.left) / k - s.bx
    let dy = axis === 'x' ? 0 : (e.clientY - r.top) / k - s.by
    const d = Math.hypot(dx, dy)
    if (d > 44) { dx = (dx / d) * 44; dy = (dy / d) * 44 }
    setS({ ...s, kx: dx, ky: dy })
    const dead = 6
    cb.current({ x: Math.abs(dx) < dead ? 0 : dx / 44, y: Math.abs(dy) < dead ? 0 : dy / 44 })
  }
  const end = () => { setS(null); cb.current({ x: 0, y: 0 }) }

  const bx = s ? s.bx : 110
  const by = s ? s.by : zoneH - 90
  return (
    <div ref={zone} onPointerDown={start} onPointerMove={move} onPointerUp={end} onPointerCancel={end}
      className="absolute bottom-0 z-20 touch-none" style={{ width: zoneW, height: zoneH, left }}>
      <div className="pointer-events-none absolute rounded-full border-2 border-white/40 bg-black/25" style={{ width: 120, height: 120, left: bx - 60, top: by - 60, opacity: s ? 1 : 0.6 }}>
        {axis === 'x' && <div className="absolute inset-x-3 top-1/2 h-px -translate-y-1/2 bg-white/30" />}
      </div>
      <div className="pointer-events-none absolute rounded-full bg-paper/90 shadow-[0_2px_6px_rgb(0_0_0/0.4)]" style={{ width: 52, height: 52, left: bx - 26 + (s?.kx ?? 0), top: by - 26 + (s?.ky ?? 0), opacity: s ? 1 : 0.6 }} />
      {label && !s && <div className="world-text pointer-events-none absolute text-[11px] text-paper/80" style={{ left: bx - 60, top: by + 64, width: 120, textAlign: 'center' }}>{label}</div>}
    </div>
  )
}
