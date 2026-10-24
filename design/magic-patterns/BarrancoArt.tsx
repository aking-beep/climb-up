import React from 'react'
import { Hero } from '../components/Hero'
import { CHECKPOINTS, GULLY_BAND, GULLY_X, HOLDS, Hold, WALL_H } from './barrancoData'
import { DEFAULT_LOOK } from '../data/cosmetics'

const INK = '#1c1915'

/** The face: basalt planes, a cool shadow side, cracks, ledges, the gully. Solid fills only. */
export function WallArt() {
  const left = 'M520 95 L500 150 L532 220 L505 300 L522 380 L494 470 L512 560 L556 640 L572 700 L528 780 L470 862 L452 905 L380 962 L350 1050 L332 1150 L300 1240'
  const right = 'L860 1240 L800 900 L812 640 L768 420 L792 200 L770 95 Z'
  return (
    <svg width={915} height={WALL_H} className="pointer-events-none absolute inset-0" aria-hidden>
      <path d={left + ' ' + right} fill="#4a453f" />
      {/* lit planes (key light upper-left) */}
      <path d="M520 95 L600 95 L585 180 L532 220 Z" fill="#5b544b" />
      <path d="M505 300 L590 280 L610 360 L522 380 Z" fill="#57504786" />
      <path d="M494 470 L540 455 L556 520 L512 560 Z" fill="#5b544b" />
      <path d="M528 780 L600 760 L590 850 L470 862 Z" fill="#5a5349" />
      <path d="M380 962 L470 950 L480 1040 L350 1050 Z" fill="#5a5349" />
      <path d="M332 1150 L430 1130 L450 1200 L300 1240 Z" fill="#544d45" />
      {/* cool shadow side */}
      <path d="M730 95 L770 95 L792 200 L768 420 L812 640 L800 900 L860 1240 L760 1240 L740 900 L752 640 L720 420 L742 200 Z" fill="#35312d" />
      {/* the gully: recessed, darker, scree */}
      <path d={`M${GULLY_X[0] - 6} ${GULLY_BAND[0] - 20} L${GULLY_X[1] + 4} ${GULLY_BAND[0] - 30} L${GULLY_X[1] + 10} ${GULLY_BAND[1]} L${GULLY_X[0] - 12} ${GULLY_BAND[1] + 10} Z`} fill="#3a352f" />
      {Array.from({ length: 26 }).map((_, i) => (
        <circle key={i} cx={GULLY_X[0] + ((i * 37) % (GULLY_X[1] - GULLY_X[0]))} cy={GULLY_BAND[0] + ((i * 53) % (GULLY_BAND[1] - GULLY_BAND[0]))} r={1.2 + (i % 3) * 0.5} fill="#6b6257" opacity={0.7} />
      ))}
      {/* cracks and strata */}
      <g fill="none" stroke="#2a2723" strokeWidth={1.6} strokeLinecap="round">
        <path d="M560 120 L572 170 L566 230 L580 290" />
        <path d="M700 160 L690 240 L705 330" />
        <path d="M640 470 L655 530 L648 600" />
        <path d="M720 520 L712 600 L726 690" />
        <path d="M430 1000 L445 1060 L436 1120" />
        <path d="M610 880 L600 940 L615 1000" />
      </g>
      <g fill="none" stroke="#6b6257" strokeOpacity={0.45} strokeWidth={1.2}>
        {[200, 330, 520, 760, 1000, 1110].map(y => <path key={y} d={`M${480} ${y} Q${620} ${y - 10} ${780} ${y + 6}`} />)}
      </g>
      {/* groundsel and grass tufts in the cracks */}
      <g stroke="#7d9460" strokeWidth={1.6} strokeLinecap="round">
        {[[512, 1180], [366, 1090], [700, 640], [548, 330], [745, 980]].map(([x, y]) => (
          <g key={`${x}${y}`}><path d={`M${x} ${y} l-4 -8 M${x} ${y} l0 -10 M${x} ${y} l4 -8`} /></g>
        ))}
      </g>
      {/* ledges (shelves where the cairns are) */}
      {CHECKPOINTS.map((c, i) => {
        const xs = [HOLDS[c.limbs[0]].x, HOLDS[c.limbs[1]].x]
        const a = Math.min(...xs) - 44, b = Math.max(...xs) + 44
        return (
          <g key={c.name}>
            <path d={`M${a} ${c.y + 2} L${b} ${c.y + 2} L${b - 6} ${c.y + 14} L${a + 8} ${c.y + 14} Z`} fill="#3d3833" />
            <path d={`M${a} ${c.y + 2} L${b} ${c.y + 2}`} stroke="#8a8072" strokeWidth={3} strokeLinecap="round" />
            {i > 0 && <Cairn x={b - 14} y={c.y + 1} />}
          </g>
        )
      })}
      {/* the top lip */}
      <path d="M505 99 L780 99" stroke="#8a8072" strokeWidth={4} strokeLinecap="round" />
    </svg>
  )
}

function Cairn({ x, y }: { x: number; y: number }) {
  return (
    <g transform={`translate(${x} ${y})`} stroke={INK} strokeWidth={0.8}>
      <ellipse cx={0} cy={-3} rx={7} ry={3.2} fill="#8f8577" />
      <ellipse cx={0} cy={-8.5} rx={5.4} ry={2.8} fill="#a3988a" />
      <ellipse cx={0.5} cy={-13} rx={3.6} ry={2.2} fill="#b3a998" />
    </g>
  )
}

/** Natural holds, readable by shape first: incut flake, thin edge, dome, hole, shelf, cracked block. */
export function HoldGlyph({ h, i, reachable, aimed, used, broken, onTap, tested = true }: { key?: React.Key; h: Hold; i: number; reachable: boolean; aimed: boolean; used: boolean; broken: boolean; onTap: () => void; tested?: boolean }) {
  // A cracked hold nobody has tested reads as a plain block with a hairline and grit below: the tell, not a warning.
  const suspect = h.type === 'loose' && !tested
  return (
    <g transform={`translate(${h.x} ${h.y})`} onClick={onTap} style={{ cursor: reachable ? 'pointer' : 'default' }} data-hold={i}>
      <circle r={22} fill="transparent" />
      {broken ? (
        <path d="M-9 -4 L8 -5 L10 3 L-8 4 Z" fill="#2a2723" />
      ) : (
        <>
          {h.type !== 'ledge' && h.type !== 'top' && h.type !== 'loose' && <ellipse cx={0} cy={1} rx={10} ry={5} fill="#f7f4ee" opacity={0.22} />}
          {h.type === 'jug' && <><path d="M-12 0 Q0 -9 12 0 Q6 6 0 6 Q-6 6 -12 0 Z" fill="#a39380" stroke={INK} strokeWidth={1.3} /><path d="M-8 1.5 Q0 -3 8 1.5" fill="none" stroke="#2a2723" strokeWidth={2.4} strokeLinecap="round" /></>}
          {h.type === 'crimp' && <><path d="M-10 0 L10 -1.5 L9 2.4 L-9 2.4 Z" fill="#c4b298" stroke={INK} strokeWidth={1.2} strokeLinejoin="round" /><line x1={-9} y1={3.6} x2={9} y2={3.6} stroke="#2a2723" strokeWidth={1.2} /></>}
          {h.type === 'sloper' && <><path d="M-12 4 Q-12 -8 0 -8 Q12 -8 12 4 Z" fill="#8f8e86" stroke={INK} strokeWidth={1.2} /><path d="M-6 -4 Q0 -6.5 5 -4.5" fill="none" stroke="#fff" strokeOpacity={0.4} strokeWidth={1.4} /></>}
          {h.type === 'pocket' && <><ellipse rx={9} ry={6.5} fill="#7a6d5e" stroke={INK} strokeWidth={1.2} /><ellipse cy={1} rx={5.5} ry={3.8} fill="#1f1b18" /></>}
          {suspect && (
            <>
              <path d="M-10 -6 L9 -7 L11 5 L-9 6 Z" fill="#958676" stroke={INK} strokeWidth={1.2} />
              <path d="M-1 -6 L1 -1 L-1 4" fill="none" stroke="#3a342c" strokeWidth={0.9} strokeLinecap="round" />
              {[[-3, 10], [4, 12]].map(([x, y]) => <circle key={`${x}${y}`} cx={x} cy={y} r={0.9} fill="#b8a890" />)}
            </>
          )}
          {h.type === 'loose' && !suspect && (
            <>
              <path d="M-10 -6 L9 -7 L11 5 L-9 6 Z" fill="#8a6a52" stroke={INK} strokeWidth={1.2} />
              <path d="M-2 -7 L1 -2 L-2 2 L2 6" fill="none" stroke="#d9572b" strokeWidth={1.6} strokeLinecap="round" strokeLinejoin="round" />
              <path d="M5 -6.5 L7 0" stroke="#d9572b" strokeWidth={1.2} strokeLinecap="round" />
              {[[-4, 10], [2, 13], [6, 9]].map(([x, y]) => <circle key={`${x}${y}`} cx={x} cy={y} r={1} fill="#b8a890" />)}
            </>
          )}
          {h.type === 'top' && <path d="M-40 4 L40 4" stroke="#e9c46a" strokeWidth={2} strokeDasharray="3 4" />}
          {h.type === 'ledge' && <ellipse cy={1} rx={8} ry={2.4} fill="#f7f4ee" opacity={0.25} />}
        </>
      )}
      {reachable && !used && !broken && (
        <circle r={aimed ? 17 : 15} fill="none" stroke={h.type === 'loose' && !suspect ? '#d9572b' : '#e9c46a'} strokeWidth={aimed ? 3 : 1.8} strokeDasharray={aimed ? undefined : '4 3'} />
      )}
    </g>
  )
}

/** Gully hazard: the column is outlined while grit trickles, then one stone drops through it. */
export function StoneFall({ stone, gully, band, rm }: { stone: { phase: 'idle' | 'warn' | 'fall'; t: number }; gully: [number, number]; band: [number, number]; rm: boolean }) {
  if (stone.phase === 'idle') return null
  const cx = (gully[0] + gully[1]) / 2
  return (
    <g pointerEvents="none">
      <rect x={gully[0] - 6} y={band[0] - 40} width={gully[1] - gully[0] + 12} height={band[1] - band[0] + 60} fill="#d9572b" opacity={stone.phase === 'warn' ? 0.12 : 0.2} stroke="#d9572b" strokeDasharray="5 4" strokeWidth={1.5} />
      {stone.phase === 'warn' && Array.from({ length: 10 }).map((_, i) => (
        <circle key={i} cx={gully[0] + 6 + ((i * 17) % (gully[1] - gully[0] - 10))} cy={band[0] - 30} r={1.4} fill="#cbbda6"
          style={{ animation: rm ? 'none' : `grit 0.9s linear ${i * 0.09}s infinite` }} />
      ))}
      {stone.phase === 'fall' && (
        <g style={{ animation: rm ? 'none' : 'stone 0.5s linear forwards' }}>
          <path d={`M${cx - 9} ${band[0] - 40} L${cx + 6} ${band[0] - 44} L${cx + 10} ${band[0] - 32} L${cx - 6} ${band[0] - 28} Z`} fill="#6b6257" stroke={INK} strokeWidth={1.4} />
        </g>
      )}
    </g>
  )
}

export function WindStreaks({ on, strong, rm }: { on: boolean; strong: boolean; rm: boolean }) {
  if (!on) return null
  return (
    <svg width={915} height={412} className="pointer-events-none absolute inset-0 z-10" aria-hidden style={{ opacity: strong ? 0.9 : 0.45 }}>
      <g style={{ animation: rm ? 'none' : `gust ${strong ? 0.7 : 1.3}s linear infinite` }}>
        {Array.from({ length: strong ? 18 : 9 }).map((_, i) => (
          <path key={i} d={`M${(i * 151) % 915} ${40 + ((i * 89) % 330)} q30 -5 60 0 t60 0`} fill="none" stroke="#f7f4ee" strokeWidth={1.6} strokeLinecap="round" />
        ))}
      </g>
    </svg>
  )
}

/** Other parties on the valley trail far below: the mountain is shared. */
export function DistantClimbers({ t }: { t: number }) {
  const look = { ...DEFAULT_LOOK, pack: 'expedition' as const }
  return (
    <div className="pointer-events-none absolute inset-0" style={{ opacity: 0.85 }}>
      {[0, 1, 2, 3].map(i => {
        const x = 40 + ((t * 9 + i * 34) % 260)
        return (
          <div key={i} className="absolute" style={{ left: x, top: 286 - x * 0.12 }}>
            <Hero look={{ ...look, jacket: ['#3f6f8a', '#c98a2e', '#a8432a', '#6f7a3f'][i], packColor: ['#3a342c', '#1f3d34', '#c98a2e', '#4a7593'][i] }} pose="walk" view="side" size={20} kit="trek" time={t + i * 0.37} />
          </div>
        )
      })}
    </div>
  )
}
