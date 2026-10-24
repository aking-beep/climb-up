import React, { useRef, useState } from 'react'
import { ArrowUp, Link2, Hand, Armchair } from 'lucide-react'
import { ClimbSim } from './useClimbSim'
import { SpecBox, SpecNote } from '../components/SpecNote'

interface Props {
  s: ClimbSim
  leftHanded: boolean
  scale: number
  disabled: boolean
  showSpecs: boolean
  onJump: () => void
}

const W = 915

/**
 * Floating stick (left) + one big context button with the grip meter on its
 * rim (right), JUMP and REST beside it, and a CLIP button that wakes
 * up when a bolt is in reach. Clipping is required: at each bolt the stick stops
 * and the big button turns into CLIP until the bolt is clipped. The last bolt
 * wakes CLIP only once the hand is up on it, not from below. Mirrors for
 * left-handed players.
 */
export function TouchControls({ s, leftHanded, scale, disabled, showSpecs, onJump }: Props) {
  const mx = (x: number) => (leftHanded ? W - x : x)
  const [stick, setStick] = useState<{ bx: number; by: number; kx: number; ky: number } | null>(null)
  const zone = useRef<HTMLDivElement>(null)
  const pressed = useRef(false)

  const start = (e: React.PointerEvent) => {
    if (disabled || !zone.current) return
    const r = zone.current.getBoundingClientRect()
    const k = r.width / (W * 0.42)
    const bx = (e.clientX - r.left) / k
    const by = (e.clientY - r.top) / k
    ;(e.target as HTMLElement).setPointerCapture(e.pointerId)
    pressed.current = true
    setStick({ bx, by, kx: 0, ky: 0 })
  }
  const move = (e: React.PointerEvent) => {
    if (!pressed.current || !stick || !zone.current) return
    const r = zone.current.getBoundingClientRect()
    const k = r.width / (W * 0.42)
    let dx = (e.clientX - r.left) / k - stick.bx
    let dy = (e.clientY - r.top) / k - stick.by
    const d = Math.hypot(dx, dy)
    const max = 44 * scale
    if (d > max) { dx = (dx / d) * max; dy = (dy / d) * max }
    setStick({ ...stick, kx: dx, ky: dy })
    s.setUp(dy < -16 * scale)
  }
  const end = () => { pressed.current = false; setStick(null); s.setUp(false) }

  const ctx = s.context
  const grip = Math.round(s.sim.grip)
  const gripCol = grip >= 50 ? '#7fa36b' : grip >= 25 ? '#d9a441' : '#c0573e'
  const R = 44 * scale
  const ring = 2 * Math.PI * (R + 7)
  const restReady = s.clippedCount > 0 && s.sim.restBar >= 34 && s.sim.mode === 'climb'
  const restR = 28 * scale
  const restRing = 2 * Math.PI * (restR + 5)

  const clipReady = s.canClip && s.sim.mode === 'climb'
  const clipR = 28 * scale
  const ctxIcon = ctx === 'GRIP' ? <Hand size={22} /> : ctx === 'REST' ? <Armchair size={22} /> : ctx === 'CLIP' ? <Link2 size={22} /> : <ArrowUp size={22} />
  const ctxX = mx(800), ctxY = 322
  const jumpX = mx(700), jumpY = 368
  const restX = mx(716), restY = 270
  const clipX = mx(800), clipY = 222

  return (
    <>
      {/* stick zone: lower 70% of the near-side 42% of the screen */}
      <div
        ref={zone}
        onPointerDown={start}
        onPointerMove={move}
        onPointerUp={end}
        onPointerCancel={end}
        className="absolute bottom-0 touch-none"
        style={{ width: W * 0.42, height: 412 * 0.7, [leftHanded ? 'right' : 'left']: 0 } as React.CSSProperties}
      >
        {(() => {
          const bx = stick ? stick.bx : leftHanded ? W * 0.42 - 116 : 116
          const by = stick ? stick.by : 412 * 0.7 - 92
          return (
            <>
              <div className="pointer-events-none absolute rounded-full border-2 border-white/35 bg-black/20" style={{ width: 120 * scale, height: 120 * scale, left: bx - 60 * scale, top: by - 60 * scale, opacity: stick ? 1 : 0.55 }}>
                <ArrowUp size={14} className="absolute left-1/2 top-1.5 -translate-x-1/2 text-white/60" />
              </div>
              <div className="pointer-events-none absolute rounded-full bg-paper/85 shadow-[0_2px_6px_rgb(0_0_0/0.4)]" style={{ width: 52 * scale, height: 52 * scale, left: bx - 26 * scale + (stick?.kx ?? 0), top: by - 26 * scale + (stick?.ky ?? 0), opacity: stick ? 1 : 0.55 }} />
            </>
          )
        })()}
      </div>

      {/* REST: sit back on the rope; the arc is the rest bar that clips fill */}
      <button
        onClick={s.rest}
        disabled={disabled || !restReady}
        aria-label="Rest on the rope"
        className="absolute grid place-items-center rounded-full bg-scrim text-paper ring-1 ring-white/20 transition-[transform,opacity] duration-[120ms] ease-out active:scale-[0.94] disabled:opacity-45"
        style={{ width: restR * 2, height: restR * 2, left: restX - restR, top: restY - restR }}
      >
        <svg className="pointer-events-none absolute -inset-[5px]" width={restR * 2 + 10} height={restR * 2 + 10} style={{ transform: 'rotate(-90deg)' }}>
          <circle cx={restR + 5} cy={restR + 5} r={restR + 3} fill="none" stroke="rgb(255 255 255 / 0.15)" strokeWidth="4" />
          <circle cx={restR + 5} cy={restR + 5} r={restR + 3} fill="none" stroke="#e9c46a" strokeWidth="4" strokeDasharray={`${(s.sim.restBar / 100) * restRing} ${restRing}`} />
        </svg>
        <span className="text-[12px] font-semibold">REST</span>
      </button>

      {/* CLIP: required. Lights up with a bolt in reach; you cannot climb past it unclipped. */}
      <button
        onClick={s.clip}
        disabled={disabled || !clipReady}
        aria-label={s.atChains ? 'Clip the chains' : 'Clip the bolt'}
        className={`absolute flex flex-col items-center justify-center rounded-full transition-[transform,opacity,background-color] duration-[120ms] ease-out active:scale-[0.94] disabled:opacity-45 ${clipReady ? 'bg-route text-ink' : 'bg-scrim text-paper ring-1 ring-white/20'} ${s.mustClip && clipReady ? 'ring-2 ring-paper' : ''}`}
        style={{ width: clipR * 2, height: clipR * 2, left: clipX - clipR, top: clipY - clipR }}
      >
        <Link2 size={16} />
        <span className="text-[11px] font-semibold leading-none">CLIP</span>
      </button>

      {/* JUMP */}
      <button
        onClick={onJump}
        disabled={disabled}
        aria-label="Jump"
        className="absolute grid place-items-center rounded-full bg-scrim text-paper ring-1 ring-white/20 transition-transform duration-[120ms] ease-out active:scale-[0.94] disabled:opacity-45"
        style={{ width: 60 * scale, height: 60 * scale, left: jumpX - 30 * scale, top: jumpY - 30 * scale }}
      >
        <span className="text-[13px] font-semibold">JUMP</span>
      </button>

      {/* Context action with the grip meter living on its rim */}
      <button
        onClick={s.act}
        disabled={disabled}
        aria-label={`Action: ${ctx}`}
        className={`absolute grid place-items-center rounded-full text-ink shadow-[0_3px_0_rgb(0_0_0/0.35)] transition-[transform,background-color] duration-[120ms] ease-out active:scale-[0.94] ${ctx === 'CLIP' ? 'bg-route' : 'bg-paper'}`}
        style={{ width: R * 2, height: R * 2, left: ctxX - R, top: ctxY - R }}
      >
        <svg className="pointer-events-none absolute" width={R * 2 + 20} height={R * 2 + 20} style={{ left: -10, top: -10, transform: 'rotate(-90deg)' }}>
          {(s.onSmall || ctx === 'GRIP') && (
            <>
              <circle cx={R + 10} cy={R + 10} r={R + 7} fill="none" stroke="rgb(0 0 0 / 0.45)" strokeWidth="7" />
              <circle cx={R + 10} cy={R + 10} r={R + 7} fill="none" stroke={gripCol} strokeWidth="7" strokeLinecap="round" strokeDasharray={`${(grip / 100) * ring} ${ring}`} style={{ transition: 'stroke-dasharray 100ms linear' }} />
              {/* half mark: squeeze once below here */}
              <line x1={R + 10} y1={R + 10 + R + 2} x2={R + 10} y2={R + 10 + R + 13} stroke="#f7f4ee" strokeWidth="2.5" />
            </>
          )}
        </svg>
        <span className="flex flex-col items-center leading-none">
          {ctxIcon}
          <span className="mt-1 font-display text-[16px]">{ctx}</span>
          {(s.onSmall || ctx === 'GRIP') && <span className="tabular mt-0.5 text-[11px] text-ink-muted">grip {grip}%</span>}
        </span>
      </button>

      {showSpecs && (
        <>
          <SpecBox x={leftHanded ? W - W * 0.42 : 0} y={412 * 0.3} w={W * 0.42} h={412 * 0.7} label="Stick zone · floating · 42% × 70%" />
          <SpecBox x={ctxX - R} y={ctxY - R} w={R * 2} h={R * 2} label="Context 88 dp" />
          <SpecBox x={jumpX - 30} y={jumpY - 30} w={60} h={60} label="Jump 60" />
          <SpecBox x={restX - restR} y={restY - restR} w={restR * 2} h={restR * 2} label="Rest 56" />
          <SpecBox x={clipX - clipR} y={clipY - clipR} w={clipR * 2} h={clipR * 2} label="Clip 56 · required at every bolt" />
          <SpecNote x={leftHanded ? 60 : 560} y={150} w={200}>Grip ring on context rim; white tick = 50% (squeeze below)</SpecNote>
        </>
      )}
    </>
  )
}
