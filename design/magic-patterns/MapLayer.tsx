import React, { useEffect, useState } from 'react'
import { animate, motion, useMotionValue } from 'framer-motion'
import { Tent, Flag } from 'lucide-react'
import { CAMPS, CHALLENGE_MARKS, EncounterId, PARTY } from '../data/kili'

export const KILI_PLATE = 'https://cdn.magicpatterns.com/patterns/generated-images/1ebae632-12c4-48bf-a181-744866de8bae.jpg'
export type Weather = 'clear' | 'wind' | 'fog' | 'snow'

const W = 1180
const H = 664
const VIEW_W = 915
const VIEW_H = 412
// the party sits right of the left panel, left of the decision card
const FOCUS_X = 440
const FOCUS_Y = 230

/** Three-quarter painted plate of the mountain, with the route, camps and party on it. Drag to pan. */
export function MapLayer({ at, weather, rm, onCamp, onPlay }: { at: number; weather: Weather; rm: boolean; onCamp: (i: number) => void; onPlay?: (id: EncounterId) => void }) {
  const px = (c: { x: number; y: number }) => ({ x: (c.x / 100) * W, y: (c.y / 100) * H })
  const x = useMotionValue(clampX(FOCUS_X - px(CAMPS[at]).x))
  const y = useMotionValue(clampY(FOCUS_Y - px(CAMPS[at]).y))
  const [pop, setPop] = useState<null | { i: number; kind: 'camp' | 'challenge' }>(null)

  // recentre on the party after a move
  useEffect(() => {
    const p = px(CAMPS[at])
    const o = { duration: rm ? 0 : 0.28, ease: [0.65, 0, 0.35, 1] as [number, number, number, number] }
    animate(x, clampX(FOCUS_X - p.x), o)
    animate(y, clampY(FOCUS_Y - p.y), o)
  }, [at]) // eslint-disable-line react-hooks/exhaustive-deps

  const pts = CAMPS.map(px)
  const done = pts.slice(0, at + 1)
  const ahead = pts.slice(at)
  const line = (ps: { x: number; y: number }[]) => ps.map((p, i) => `${i ? 'L' : 'M'}${p.x} ${p.y}`).join(' ')
  const party = pts[at]

  return (
    <motion.div
      className="absolute left-0 top-0 cursor-grab active:cursor-grabbing"
      style={{ width: W, height: H, x, y }}
      drag
      dragConstraints={{ left: VIEW_W - W, right: 0, top: VIEW_H - H, bottom: 0 }}
      dragElastic={0.06}
      dragMomentum={!rm}
      onTap={() => setPop(null)}
    >
      <img src={KILI_PLATE} alt="" draggable={false} className="pointer-events-none absolute inset-0 h-full w-full object-cover" />
      {/* key light from dawn side + cool shadow side for HD-2D depth */}
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(50%_60%_at_15%_10%,rgb(255_214_160/0.22),transparent_70%)]" />

      <svg width={W} height={H} className="absolute inset-0" aria-hidden>
        {/* zone contour labels */}
        {[['Rainforest', 74], ['Heath & moorland', 56], ['Alpine desert', 40], ['Arctic summit', 18]].map(([l, yy]) => (
          <text key={l as string} x={W - 24} y={((yy as number) / 100) * H} textAnchor="end" fontFamily="Fraunces" fontSize="15" fill="#f7f4ee" opacity="0.85" style={{ paintOrder: 'stroke', stroke: 'rgb(0 0 0 / 0.45)', strokeWidth: 3 }}>{l}</text>
        ))}
        <path d={line(ahead)} fill="none" stroke="#1c1915" strokeOpacity="0.45" strokeWidth="6" strokeLinecap="round" strokeLinejoin="round" />
        <path d={line(ahead)} fill="none" stroke="#f7f4ee" strokeWidth="2.5" strokeDasharray="2 7" strokeLinecap="round" strokeLinejoin="round" />
        <path d={line(done)} fill="none" stroke="#1c1915" strokeOpacity="0.55" strokeWidth="7" strokeLinecap="round" strokeLinejoin="round" />
        <path d={line(done)} fill="none" stroke="#e9c46a" strokeWidth="3.5" strokeLinecap="round" strokeLinejoin="round" />
      </svg>

      {/* challenge climbs: diamonds with their best stars */}
      {CHALLENGE_MARKS.map((c, i) => {
        const p = px(c)
        return (
          <button key={c.id} onClick={e => { e.stopPropagation(); setPop({ i, kind: 'challenge' }) }} className="absolute grid h-12 w-12 -translate-x-1/2 -translate-y-1/2 place-items-center" style={{ left: p.x, top: p.y }} aria-label={c.name}>
            <span className={`block h-5 w-5 rotate-45 border-2 ${c.godot === 'proposed' ? 'border-dashed border-route' : 'border-paper'} ${c.done ? 'bg-ember' : 'bg-ink/70'}`} />
          </button>
        )
      })}

      {/* camps */}
      {CAMPS.map((c, i) => {
        const p = pts[i]
        const past = i < at
        const here = i === at
        const summit = c.id === 'summit'
        return (
          <div key={c.id} className="absolute" style={{ left: p.x, top: p.y }}>
            <button
              onClick={e => { e.stopPropagation(); if (here) onCamp(i); else setPop({ i, kind: 'camp' }) }}
              aria-label={c.name}
              className="absolute grid h-12 w-12 -translate-x-1/2 -translate-y-1/2 place-items-center"
            >
              <span className={`grid place-items-center rounded-full border-2 ${summit ? 'h-8 w-8 border-paper bg-spruce text-route' : here ? 'h-7 w-7 border-paper bg-ember text-paper' : past ? 'h-6 w-6 border-paper bg-route text-ink' : 'h-6 w-6 border-paper/80 bg-ink/60 text-paper'}`}>
                {summit ? <Flag size={15} /> : <Tent size={12} />}
              </span>
            </button>
            {(here || summit || i === at + 1) && (
              <div className={`world-text pointer-events-none absolute whitespace-nowrap text-paper ${summit ? 'left-5 -top-3' : 'left-4 top-2'}`}>
                <div className="font-display text-[14px] leading-tight">{c.name}</div>
                <div className="tabular text-[11px] text-paper/85">{c.meters.toLocaleString()} m</div>
              </div>
            )}
          </div>
        )
      })}

      {/* party marker: four walkers on a flag, ease-in-out between camps */}
      <motion.div
        className="pointer-events-none absolute"
        animate={{ left: party.x - 26, top: party.y - 54 }}
        transition={{ duration: rm ? 0 : 0.28, ease: [0.65, 0, 0.35, 1] }}
      >
        <div className="flex items-end gap-[2px] rounded-full bg-paper-raised px-1.5 py-1 shadow-[0_3px_8px_rgb(0_0_0/0.45)] ring-1 ring-paper-edge">
          {PARTY.map(m => (
            <span key={m.id} className={`block rounded-full ring-1 ring-ink/40 ${m.id === 'you' ? 'h-4 w-4' : 'h-3.5 w-3.5'}`} style={{ background: m.color }} />
          ))}
        </div>
        <div className="mx-auto h-4 w-[2px] bg-paper-raised" />
      </motion.div>

      <WeatherLayer weather={weather} rm={rm} />

      {pop && <MapPopover pop={pop} at={at} px={px} onPlay={onPlay} />}
    </motion.div>
  )
}

function MapPopover({ pop, at, px, onPlay }: { pop: { i: number; kind: 'camp' | 'challenge' }; at: number; px: (c: { x: number; y: number }) => { x: number; y: number }; onPlay?: (id: EncounterId) => void }) {
  if (pop.kind === 'challenge') {
    const c = CHALLENGE_MARKS[pop.i]
    const p = px(c)
    return (
      <div className="paper-grain absolute z-10 w-[220px] rounded-[8px] border border-paper-edge p-2.5 text-[13px] shadow-lg" style={{ left: p.x + 18, top: p.y - 20 }} onClick={e => e.stopPropagation()} onPointerDown={e => e.stopPropagation()}>
        <div className="flex items-center justify-between gap-2">
          <div className="font-display text-[16px] text-ink">{c.name}</div>
          <span className={`rounded-sm px-1.5 text-[10px] font-semibold ${c.godot === 'proposed' ? 'border border-dashed border-[#4a7593] text-[#2f5772]' : 'bg-paper-sunk text-ink-muted'}`}>{c.godot === 'proposed' ? 'Proposed' : 'In game'}</span>
        </div>
        <div className="text-ink-soft">{c.done ? `Played climb · best ${'★'.repeat(c.stars)}${'☆'.repeat(3 - c.stars)}` : 'Played climb · ahead of you'}</div>
        {c.encounter && onPlay && (
          <button onClick={() => onPlay(c.encounter!)} className="mt-2 h-10 w-full rounded-[6px] bg-spruce font-display text-[15px] text-spruce-ink transition-transform duration-[120ms] ease-out active:scale-[0.97]">
            {c.done ? 'Replay climb' : 'Play climb'}
          </button>
        )}
      </div>
    )
  }
  const c = CAMPS[pop.i]
  const p = px(c)
  const past = pop.i < at
  return (
    <div className="paper-grain absolute z-10 w-[220px] rounded-[8px] border border-paper-edge p-2.5 text-[13px] shadow-lg" style={{ left: p.x + 18, top: p.y - 20 }} onClick={e => e.stopPropagation()}>
      <div className="text-[11px] text-ink-muted">{c.zone} · {c.meters.toLocaleString()} m</div>
      <div className="font-display text-[16px] text-ink">{c.name}</div>
      <div className="text-ink-soft">{past ? `Day ${pop.i + 1} · camp log: the team slept here.${c.challenge ? ` ${c.challenge} climbed.` : ''}` : 'Not reached yet.'}</div>
    </div>
  )
}

/** Weather on the map. Wind is built today; fog and snow are designed states (visual only, engine dice untouched). */
function WeatherLayer({ weather, rm }: { weather: Weather; rm: boolean }) {
  if (weather === 'clear') return null
  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden">
      {weather === 'wind' && (
        <svg width={W} height={H} className={rm ? '' : 'anim-drift'} aria-hidden>
          {Array.from({ length: 14 }).map((_, i) => (
            <path key={i} d={`M${(i * 173) % W} ${(i * 97) % H} q40 -6 80 0 t80 0`} fill="none" stroke="#f7f4ee" strokeOpacity="0.45" strokeWidth="1.6" strokeLinecap="round" />
          ))}
        </svg>
      )}
      {weather === 'fog' && <div className="absolute inset-0 bg-[#e8eef0]/45" />}
      {weather === 'snow' && (
        <div className="absolute inset-0 bg-[#dfe8ef]/20">
          <svg width={W} height={H} style={{ animation: rm ? 'none' : 'snowfall 9s linear infinite' }} aria-hidden>
            {Array.from({ length: 90 }).map((_, i) => <circle key={i} cx={(i * 131) % W} cy={(i * 71) % H} r={1 + (i % 3) * 0.6} fill="#fff" opacity="0.8" />)}
          </svg>
        </div>
      )}
    </div>
  )
}

function clampX(v: number) { return Math.max(VIEW_W - W, Math.min(0, v)) }
function clampY(v: number) { return Math.max(VIEW_H - H, Math.min(0, v)) }
