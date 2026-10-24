import React, { useLayoutEffect, useRef, useState } from 'react'
import { Lock } from 'lucide-react'
import { useGame } from '../state/GameState'
import { DAILY, ROUTES, Route, isUnlocked } from '../data/routes'

interface Props {
  selected: string
  recommended: string
  onSelect: (id: string) => void
  dimmed?: boolean
}

/** Chalk topo drawn on the crag photo-plate: every route is a line you can tap. */
export function RouteTopo({ selected, recommended, onSelect, dimmed }: Props) {
  const { progress } = useGame()
  const all = [...ROUTES, DAILY]
  return (
    <svg viewBox="0 0 915 412" className={`absolute inset-0 h-full w-full transition-opacity duration-200 ${dimmed ? 'opacity-30' : 'opacity-100'}`}>
      <g transform="translate(36 -10)">
        {all.filter(r => r.id !== selected).map(r => (
          <RouteLine key={r.id} r={r} state={isUnlocked(r.id, progress) ? 'open' : 'locked'} onSelect={onSelect} recommended={r.id === recommended} />
        ))}
        {all.filter(r => r.id === selected).map(r => (
          <RouteLine key={r.id} r={r} state="selected" onSelect={onSelect} recommended={r.id === recommended} sent={(progress[r.id]?.sends ?? 0) > 0} highBolt={progress[r.id]?.highBolt ?? 0} />
        ))}
      </g>
    </svg>
  )
}

function RouteLine({ r, state, onSelect, recommended, sent, highBolt = 0 }: { key?: React.Key; r: Route; state: 'open' | 'locked' | 'selected'; onSelect: (id: string) => void; recommended: boolean; sent?: boolean; highBolt?: number }) {
  const pathRef = useRef<SVGPathElement>(null)
  const [bolts, setBolts] = useState<{ x: number; y: number }[]>([])

  useLayoutEffect(() => {
    const p = pathRef.current
    if (!p) return
    const L = p.getTotalLength()
    const start = L * 0.16
    const pts = Array.from({ length: r.bolts }).map((_, i) => {
      const pt = p.getPointAtLength(start + ((L - start) * (i + 0.5)) / r.bolts)
      return { x: pt.x, y: pt.y }
    })
    setBolts(pts)
  }, [r])

  const sel = state === 'selected'
  const locked = state === 'locked'
  const daily = !!r.daily

  return (
    <g className="cursor-pointer" onClick={() => onSelect(r.id)}>
      {/* generous invisible hit stroke */}
      <path d={r.path} fill="none" stroke="transparent" strokeWidth="26" />
      {sel && <path d={r.path} fill="none" stroke="#1c1915" strokeOpacity="0.55" strokeWidth="7" strokeLinecap="round" />}
      <path
        ref={pathRef}
        d={r.path}
        fill="none"
        stroke={daily ? '#f2c14e' : '#f7f4ee'}
        strokeOpacity={sel ? 1 : locked ? 0.35 : 0.7}
        strokeWidth={sel ? 3.5 : 2}
        strokeDasharray={locked ? '2 6' : sel ? undefined : '7 5'}
        strokeLinecap="round"
      />
      {sel && bolts.map((b, i) => (
        <g key={i}>
          <circle cx={b.x} cy={b.y} r="4.5" fill={i < highBolt || sent ? '#f7f4ee' : '#1c1915'} stroke="#f7f4ee" strokeWidth="1.6" />
        </g>
      ))}
      {sel && !sent && highBolt > 0 && bolts[highBolt - 1] && (
        <g transform={`translate(${bolts[highBolt - 1].x + 10} ${bolts[highBolt - 1].y})`}>
          <rect x="0" y="-9" width="70" height="18" rx="4" fill="#1c1915" fillOpacity="0.75" />
          <text x="6" y="4" fill="#f7f4ee" fontSize="11" fontFamily="Outfit" fontWeight="600">High point</text>
        </g>
      )}
      {/* grade flag at the anchor */}
      <g transform={`translate(${r.tagX} ${r.tagY})`}>
        <rect x="-24" y="-24" width="48" height="48" fill="transparent" />
        <rect x="-18" y="-13" width="36" height="22" rx="4" fill={sel ? '#1f3d34' : daily ? '#f2c14e' : '#faf7f0'} stroke="#1c1915" strokeOpacity="0.6" />
        {locked ? (
          <foreignObject x="-7" y="-9" width="14" height="14"><Lock size={13} color="#6b6257" /></foreignObject>
        ) : (
          <text x="0" y="3" textAnchor="middle" fontFamily="Fraunces" fontWeight="600" fontSize={r.grade.length > 3 ? 10 : 13} fill={sel ? '#e8f0e8' : '#1c1915'}>{r.grade === 'Lesson' ? 'L' : r.grade}</text>
        )}
        {recommended && !sel && (
          <g transform="translate(22 -2)">
            <rect x="0" y="-9" width="54" height="18" rx="9" fill="#a8432a" />
            <text x="27" y="4" textAnchor="middle" fill="#f3efe6" fontSize="11" fontFamily="Outfit" fontWeight="600">Next up</text>
          </g>
        )}
      </g>
    </g>
  )
}
