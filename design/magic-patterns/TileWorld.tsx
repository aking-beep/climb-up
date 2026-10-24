import React, { useMemo } from 'react'
import { Level, Marker, Sim, T, antX, isClimb, isSolid, rockAt, rollerAt } from './engine'
import { ArtifactFind, GearFind, RavenSprite } from '../StageKit'
import { GEAR } from '../stageData'

const INK = '#1c1915'

export interface Pal {
  rock: string; deep: string; speck: string; cap: string; frost: string; ink: string
  face: string; hold: string; loose: string; pebble: string; scr: string
  ice: string; iceTop: string; water: string; slab: string; post: string; board: string; boardInk: string
}

export const KARANGA_PAL: Pal = {
  rock: '#5a4e42', deep: '#4a4037', speck: '#6b5d4e', cap: '#9a8a70', frost: '#c9c3b4', ink: '#2a231d',
  face: '#75685a', hold: '#3a322a', loose: '#8a7a66', pebble: '#b3a48c', scr: '#7d7062',
  ice: '#cfe0e8', iceTop: '#eef5f8', water: '#6f9cb4', slab: '#b3a48c', post: '#5a3d2e', board: '#efe6d2', boardInk: '#1c1915',
}

export const SUMMIT_PAL: Pal = {
  rock: '#2e3346', deep: '#232738', speck: '#3a4056', cap: '#8b93a8', frost: '#d9e1ea', ink: '#0f1220',
  face: '#3f4558', hold: '#1c2030', loose: '#4f5466', pebble: '#7b8296', scr: '#454b5e',
  ice: '#bcd3df', iceTop: '#eef5f8', water: '#5d7f99', slab: '#9b927f', post: '#5a3d2e', board: '#2d5a4b', boardInk: '#e9c46a',
}

const hash = (x: number, y: number) => { const h = Math.sin(x * 127.1 + y * 311.7) * 43758.5453; return h - Math.floor(h) }

/** Static ground: drawn once per level as a handful of merged paths, never re-rendered while you play. */
export function TerrainLayer({ L, pal }: { L: Level; pal: Pal }) {
  return useMemo(() => {
    const c = (x: number, y: number) => (x < 0 || x >= L.w ? '#' : y < 0 || y >= L.h ? '.' : L.cells[y][x])
    let rock = '', deep = '', speck = '', cap = '', frost = '', edge = '', ice = '', iceCap = '', face = '', holds = '', loose = '', peb = '', scr = '', scrLine = '', water = '', waterTop = ''
    const r = (x: number, y: number, w: number, h: number) => `M${x} ${y}h${w}v${h}h${-w}z`
    for (let y = 0; y < L.h; y++) {
      let run = -1
      for (let x = 0; x <= L.w; x++) {
        const ch = x < L.w ? L.cells[y][x] : '.'
        if (ch === '#' && run < 0) run = x
        if (ch !== '#' && run >= 0) { rock += r(run * T, y * T, (x - run) * T, T); run = -1 }
      }
      for (let x = 0; x < L.w; x++) {
        const ch = L.cells[y][x]
        const X = x * T, Y = y * T
        if (ch === '#' || ch === 'i') {
          const up = c(x, y - 1)
          const open = !isSolid(up) && !isClimb(up)
          if (ch === '#') {
            let allIn = true
            for (let dy = -1; dy <= 1 && allIn; dy++) for (let dx = -1; dx <= 1; dx++) if (!isSolid(c(x + dx, y + dy))) { allIn = false; break }
            if (allIn && y > 0 && isSolid(c(x, y - 2))) deep += r(X, Y, T, T)
            else if (hash(x, y) < 0.22) { const h = hash(y, x); speck += `M${X + 6 + h * 12} ${Y + 12}l7 -4l7 3l-2 7l-9 1z` }
            if (open) { if (up === 'E') frost += r(X, Y, T, 6); else cap += r(X, Y, T, 6); if (hash(x, y + 9) < 0.5) peb += `M${X + 4 + hash(x, 1) * 20} ${Y + 9}a2 1.6 0 1 0 0.1 0z` }
          } else {
            ice += r(X, Y, T, T)
            if (open) iceCap += r(X, Y, T, 5)
          }
          if (!isSolid(c(x, y - 1))) edge += `M${X} ${Y}h${T}`
          if (!isSolid(c(x, y + 1))) edge += `M${X} ${Y + T}h${T}`
          if (!isSolid(c(x - 1, y))) edge += `M${X} ${Y}v${T}`
          if (!isSolid(c(x + 1, y))) edge += `M${X + T} ${Y}v${T}`
        } else if (ch === 'C') {
          face += r(X, Y, T, T)
          const a = hash(x, y), b = hash(y, x)
          holds += `M${X + 6 + a * 8} ${Y + 8}a3.5 2.6 0 1 0 0.1 0zM${X + 18 + b * 6} ${Y + 22}a3.5 2.6 0 1 0 0.1 0z`
        } else if (ch === 'L') {
          loose += r(X, Y, T, T)
          for (let i = 0; i < 4; i++) peb += `M${X + 4 + hash(x + i, y) * 24} ${Y + 4 + hash(y + i, x) * 24}a2.4 1.8 0 1 0 0.1 0z`
        } else if (ch === 's') {
          scr += r(X, Y, T, T)
          scrLine += `M${X + 2} ${Y + 18}l10 -12l14 2l4 12M${X + 4} ${Y + 30}l8 -8l12 1`
        } else if (ch === '~') {
          water += r(X, Y, T, T)
          if (c(x, y - 1) !== '~') waterTop += `M${X} ${Y + 3}q8 -4 16 0t16 0`
        }
      }
    }
    return (
      <svg width={L.w * T} height={L.h * T} className="pointer-events-none absolute left-0 top-0" aria-hidden>
        <path d={face} fill={pal.face} />
        <path d={holds} fill={pal.hold} />
        <path d={loose} fill={pal.loose} />
        <path d={scr} fill={pal.scr} />
        <path d={scrLine} fill="none" stroke={pal.hold} strokeWidth={1.4} strokeLinejoin="round" />
        <path d={rock} fill={pal.rock} />
        <path d={deep} fill={pal.deep} />
        <path d={speck} fill={pal.speck} />
        <path d={ice} fill={pal.ice} />
        <path d={cap} fill={pal.cap} />
        <path d={frost} fill={pal.frost} />
        <path d={iceCap} fill={pal.iceTop} />
        <path d={peb} fill={pal.pebble} />
        <path d={edge} fill="none" stroke={pal.ink} strokeWidth={2} strokeLinecap="square" />
        <path d={water} fill={pal.water} opacity={0.92} />
        <path d={waterTop} fill="none" stroke="#d6e6ee" strokeWidth={1.6} />
      </svg>
    )
  }, [L, pal])
}

/** Water drawn again in front of the hero, so wading reads as wading. */
export function WaterFront({ L, pal }: { L: Level; pal: Pal }) {
  return useMemo(() => {
    let d = ''
    for (let y = 0; y < L.h; y++) for (let x = 0; x < L.w; x++) if (L.cells[y][x] === '~') d += `M${x * T} ${y * T + 6}h${T}v${T - 6}h${-T}z`
    return <svg width={L.w * T} height={L.h * T} className="pointer-events-none absolute left-0 top-0" aria-hidden><path d={d} fill={pal.water} opacity={0.55} /></svg>
  }, [L, pal])
}

/** Static props: cairns, signs, tents, rest stones, the stream spring, the Uhuru board. */
export function PropLayer({ L, pal }: { L: Level; pal: Pal }) {
  return useMemo(() => (
    <svg width={L.w * T} height={L.h * T} className="pointer-events-none absolute left-0 top-0" aria-hidden>
      {L.markers.map(m => {
        switch (m.ch) {
          case 'K': return <Cairn key={m.key} m={m} />
          case 'S': return <Sign key={m.key} m={m} pal={pal} label={L.signs[`${m.cx},${m.cy}`]?.label ?? ''} />
          case 'T': return <Tent key={m.key} m={m} />
          case 'R': return <g key={m.key} transform={`translate(${m.x} ${m.y})`} stroke={INK} strokeWidth={1.2}><path d="M-20 0 Q-18 -16 0 -17 Q18 -16 20 0 Z" fill="#7d7a72" /><path d="M-10 -9 Q0 -13 9 -9" fill="none" stroke="#a5a197" strokeWidth={2} /></g>
          case 'F': return <Spring key={m.key} m={m} />
          case 'U': return <Uhuru key={m.key} m={m} />
          default: return null
        }
      })}
    </svg>
  ), [L, pal])
}

/** Everything that moves or can be taken: slabs, finds, creatures, stones, the raven. */
export function DynLayer({ L, s, pal, rm, glove }: { L: Level; s: Sim; pal: Pal; rm: boolean; glove?: boolean }) {
  const near = (m: Marker) => Math.abs(m.x - s.x) < 150 && Math.abs(m.y - s.y) < 120
  const slabs: React.ReactNode[] = []
  for (let y = 0; y < L.h; y++) for (let x = 0; x < L.w; x++) {
    if (L.cells[y][x] !== 'c' || (s.gone[`${x},${y}`] ?? 0) > 0) continue
    const hot = s.slabHold > 0 && s.slabKey.endsWith(`,${y}`)
    slabs.push(
      <g key={`c${x},${y}`} transform={`translate(${x * T} ${y * T})`}>
        <rect width={T} height={12} fill={hot ? '#d98b5f' : pal.slab} stroke={pal.ink} strokeWidth={1.6} />
        <path d={`M${6 + (x % 3) * 6} 0 l4 5 l-3 4 l5 3`} stroke={INK} strokeWidth={1.1} fill="none" />
      </g>,
    )
  }
  return (
    <svg width={L.w * T} height={L.h * T} className="pointer-events-none absolute left-0 top-0" aria-hidden>
      {slabs}
      {L.markers.map(m => {
        if (s.taken[m.key]) return null
        if ('12345'.includes(m.ch)) { const g = L.gear[Number(m.ch) - 1]; return g ? <GearFind key={m.key} x={m.x} y={m.y - 16} near={near(m)} label={GEAR[g.kind].label} /> : null }
        if (m.ch === 'A' || m.ch === 'B') return <ArtifactFind key={m.key} x={m.x} y={m.y - 16} near={near(m)} />
        if (m.ch === 'g' && glove) return <Glove key={m.key} x={m.x} y={m.y - 10} near={near(m)} />
        if (m.ch === 'n') return <g key={m.key} transform={`translate(${m.x} ${m.y})`} stroke="#4f6b3a" strokeWidth={2.2} strokeLinecap="round"><path d="M0 0 L-8 -16 M0 0 L0 -20 M0 0 L8 -16 M-4 -9 L-11 -12 M4 -9 L11 -12 M-2 -15 L-6 -18 M2 -15 L6 -18" /><circle cx={0} cy={-21} r={2.6} fill="#8a5a9e" stroke="none" /></g>
        if (m.ch === 'a') { const ax = antX(s.t, m); return <g key={m.key}>{Array.from({ length: 11 }).map((_, i) => <ellipse key={i} cx={ax - 13 + i * 2.6} cy={m.y - 2 + (rm ? 0 : Math.sin(s.t * 20 + i) * 0.7)} rx={1.5} ry={1.1} fill={INK} />)}</g> }
        if (m.ch === 'b' || m.ch === 'd') {
          const r = rollerAt(s, m)
          if (r.phase === 'warn') return <g key={m.key}>{[0, 1, 2].map(i => <circle key={i} cx={m.x + (i - 1) * 7} cy={m.y - 6 - ((s.t * 20 + i * 5) % 10)} r={1.6} fill="#cbbda6" />)}</g>
          if (r.phase === 'roll') return <g key={m.key} transform={`translate(${r.x} ${m.y - 10}) rotate(${rm ? 0 : (r.x * 3) % 360})`}><circle r={10} fill="#6b5d4e" stroke={INK} strokeWidth={1.5} /><path d="M-5 -3 L3 -6" stroke="#9a8a70" strokeWidth={1.4} /></g>
          return null
        }
        if (m.ch === 'r') {
          const r = rockAt(s, L, m)
          const [top, bot] = m.lane ?? [m.y, m.y]
          return (
            <g key={m.key}>
              <rect x={m.x - T * 1.5} y={top} width={T * 3} height={bot - top} fill={r.phase === 'idle' ? 'none' : '#d9572b'} opacity={0.14} stroke={r.phase === 'idle' ? 'none' : '#d9572b'} strokeDasharray="5 4" />
              {r.phase === 'warn' && Array.from({ length: 8 }).map((_, i) => <circle key={i} cx={m.x - T + ((i * 13) % (T * 2))} cy={top + ((s.t * 90 + i * 23) % (bot - top))} r={1.4} fill="#cbbda6" />)}
              {r.phase === 'fall' && <path transform={`translate(${m.x} ${r.y})`} d="M-9 -6 L6 -10 L10 3 L-5 7 Z" fill="#6b6257" stroke={INK} strokeWidth={1.4} />}
            </g>
          )
        }
        if (m.ch === 'v') {
          const rv = s.ravens[m.key]
          if (!rv) return <g key={m.key}><RavenSprite r={{ phase: 'circle', t: s.t, still: 0, tx: 0, ty: 0 }} home={[m.x, m.y - 40]} rm={rm} /></g>
          return <g key={m.key}><RavenSprite r={rv} home={[clampN(s.x, m.x - 150, m.x + 150), m.y - 40]} rm={rm} /></g>
        }
        return null
      })}
    </svg>
  )
}

function clampN(v: number, a: number, b: number) { return Math.max(a, Math.min(b, v)) }

function Cairn({ m }: { key?: React.Key; m: Marker }) {
  return (
    <g transform={`translate(${m.x} ${m.y})`} stroke={INK} strokeWidth={1.1}>
      <ellipse cy={-5} rx={13} ry={5} fill="#8f8577" />
      <ellipse cy={-14} rx={10} ry={4.5} fill="#a3988a" />
      <ellipse cy={-22} rx={7} ry={3.6} fill="#b3a998" />
      <ellipse cy={-28} rx={4} ry={2.6} fill="#c4baa8" />
    </g>
  )
}

function Sign({ m, pal, label }: { key?: React.Key; m: Marker; pal: Pal; label: string }) {
  const w = Math.max(44, label.length * 6.2 + 14)
  return (
    <g transform={`translate(${m.x} ${m.y})`}>
      <rect x={-2} y={-40} width={4} height={40} fill={pal.post} />
      <rect x={-w / 2} y={-56} width={w} height={20} rx={3} fill={pal.board} stroke={INK} strokeWidth={1.2} />
      <text x={0} y={-42} textAnchor="middle" fontFamily="Fraunces" fontSize={11} fill={pal.boardInk}>{label}</text>
    </g>
  )
}

function Tent({ m }: { key?: React.Key; m: Marker }) {
  const c = m.cx % 3 === 0 ? '#c98a2e' : m.cx % 3 === 1 ? '#a8432a' : '#3f6f8a'
  return (
    <g transform={`translate(${m.x} ${m.y})`} stroke={INK} strokeWidth={1.4}>
      <path d="M-26 0 L0 -36 L26 0 Z" fill={c} />
      <path d="M0 -36 L0 0" strokeOpacity={0.4} />
      <path d="M-6 0 L0 -14 L6 0 Z" fill="#2a231d" stroke="none" />
    </g>
  )
}

function Spring({ m }: { key?: React.Key; m: Marker }) {
  return (
    <g transform={`translate(${m.x} ${m.y})`} stroke={INK} strokeWidth={1}>
      <ellipse cy={-3} rx={14} ry={4} fill="#8f8577" />
      <path d="M-4 -6 Q0 -16 4 -6" fill="#9cc3d6" />
      <circle cy={-20} r={2} fill="#9cc3d6" stroke="none" />
    </g>
  )
}

function Uhuru({ m }: { key?: React.Key; m: Marker }) {
  return (
    <g transform={`translate(${m.x} ${m.y})`}>
      <rect x={-34} y={-62} width={5} height={62} fill="#5a3d2e" />
      <rect x={29} y={-62} width={5} height={62} fill="#5a3d2e" />
      <rect x={-48} y={-92} width={96} height={38} rx={3} fill="#2f5d3a" stroke={INK} strokeWidth={1.4} />
      <text x={0} y={-76} textAnchor="middle" fontFamily="Fraunces" fontSize={12} fill="#e9c46a">UHURU PEAK</text>
      <text x={0} y={-62} textAnchor="middle" fontFamily="Fraunces" fontSize={10} fill="#e9c46a">5,895 m</text>
      {['#3a78c8', '#f2efe6', '#d64a3a', '#3f8a4a', '#f4c542'].map((f, i) => <path key={f} d={`M${-46 + i * 20} -96 l8 -2 l-1 8 z`} fill={f} stroke={INK} strokeWidth={0.6} />)}
    </g>
  )
}

function Glove({ x, y, near }: { key?: React.Key; x: number; y: number; near: boolean }) {
  return (
    <g transform={`translate(${x} ${y})`}>
      <circle r={13} fill="none" stroke="#e9c46a" strokeWidth={near ? 2 : 1.2} strokeDasharray="3 3" />
      <path d="M-6 6 L-6 -2 Q-6 -6 -3 -6 L-3 -8 Q-3 -10 -1 -10 Q1 -10 1 -8 L1 -9 Q1 -11 3 -11 Q5 -11 5 -8 L5 -1 L8 -4 Q10 -5 10 -2 L5 6 Z" fill="#c98a2e" stroke={INK} strokeWidth={1.1} strokeLinejoin="round" />
      {near && <text y={-18} textAnchor="middle" fontSize={10} fontFamily="Outfit" fontWeight={600} fill="#f7f4ee" style={{ paintOrder: 'stroke', stroke: 'rgb(0 0 0 / 0.6)', strokeWidth: 3 }}>Jun's glove</text>}
    </g>
  )
}
