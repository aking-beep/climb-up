import React from 'react'

export type HoldType = 'jug' | 'crimp' | 'sloper' | 'pocket' | 'rock'

/** Holds read by SHAPE first, colour second (colour-blind safe). */
export function HoldShape({ type, x = 0, y = 0, s = 1, dim }: { key?: React.Key; type: HoldType; x?: number; y?: number; s?: number; dim?: boolean }) {
  const op = dim ? 0.55 : 1
  const ink = '#1c1915'
  return (
    <g transform={`translate(${x} ${y}) scale(${s})`} opacity={op}>
      {type === 'jug' && (
        <>
          <path d="M-13 -2 Q-13 -10 0 -10 Q13 -10 13 -2 Q13 7 0 8 Q-13 7 -13 -2 Z" fill="#e6dcc8" stroke={ink} strokeWidth="1.6" />
          <path d="M-8 -3 Q0 3 8 -3" fill="none" stroke={ink} strokeWidth="2" strokeLinecap="round" />
        </>
      )}
      {type === 'crimp' && (
        <>
          <path d="M-11 0 L11 0 L9 -4.5 L-9 -4.5 Z" fill="#f2c14e" stroke={ink} strokeWidth="1.5" strokeLinejoin="round" />
          <line x1="-10" y1="1.6" x2="10" y2="1.6" stroke={ink} strokeOpacity="0.35" strokeWidth="1.4" />
        </>
      )}
      {type === 'sloper' && (
        <path d="M-12 4 Q-12 -9 0 -9 Q12 -9 12 4 Z" fill="#9fc4e0" stroke={ink} strokeWidth="1.5" />
      )}
      {type === 'pocket' && (
        <>
          <ellipse cx="0" cy="0" rx="10" ry="7" fill="#c9a77e" stroke={ink} strokeWidth="1.5" />
          <ellipse cx="0" cy="1" rx="6" ry="4" fill="#3a2a22" />
        </>
      )}
      {type === 'rock' && <path d="M-7 2 L-4 -4 L5 -5 L8 1 L2 4 Z" fill="#b98a62" stroke={ink} strokeOpacity="0.7" strokeWidth="1.2" />}
    </g>
  )
}

export function HoldIcon({ type, size = 22 }: { type: HoldType; size?: number }) {
  return (
    <svg width={size} height={size} viewBox="-15 -12 30 24" aria-hidden><HoldShape type={type} /></svg>
  )
}

/** Bolt hanger with a quickdraw; `clipped` hangs the rope through it. */
export function Bolt({ x, y, clipped, rope = "#d9572b", next }: { key?: React.Key; x: number; y: number; clipped?: boolean; rope?: string; next?: boolean }) {
  return (
    <g transform={`translate(${x} ${y})`}>
      {next && <circle r="16" fill="none" stroke="#f7f4ee" strokeWidth="2" strokeDasharray="4 4" opacity="0.9" />}
      <circle r="4.5" fill="#cfd5da" stroke="#1c1915" strokeWidth="1.4" />
      <circle r="1.6" fill="#1c1915" />
      <rect x="-2" y="4" width="4" height="10" rx="2" fill="#2d5a4b" stroke="#1c1915" strokeWidth="1" />
      <path d="M-4 14 Q-4 20 0 20 Q4 20 4 14" fill="none" stroke={clipped ? rope : '#cfd5da'} strokeWidth="2.4" />
    </g>
  )
}

export function QuickdrawIcon({ size = 22, className = '' }: { size?: number; className?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" className={className} aria-hidden>
      <path d="M9 3 Q5 3 5 7 Q5 10 9 10" /><path d="M9 3 L11 3" /><rect x="10" y="9" width="4" height="7" rx="2" /><path d="M15 21 Q19 21 19 17 Q19 14 15 14" /><path d="M15 21 L13 21" />
    </svg>
  )
}

export function ShoeIcon({ aggressive, size = 26 }: { aggressive?: boolean; size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 32 20" aria-hidden>
      <path d={aggressive ? 'M2 14 Q4 5 11 4 L16 6 Q22 10 29 12 Q31 15 28 17 L5 17 Q2 17 2 14 Z' : 'M2 13 Q3 6 10 6 L16 7 Q22 9 29 11 Q31 14 28 16 L5 16 Q2 16 2 13 Z'} fill="#5a3d2e" stroke="#1c1915" strokeWidth="1.4" />
      <path d={aggressive ? 'M4 17 L28 17' : 'M4 16 L28 16'} stroke="#1c1915" strokeWidth="2.4" />
      <path d="M9 7 L13 11 M12 6 L16 10" stroke="#e9c46a" strokeWidth="1.4" />
    </svg>
  )
}

export function RopeCoil({ color, size = 40 }: { color: string; size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 40 40" aria-hidden>
      {[14, 11, 8].map((r, i) => <ellipse key={r} cx="20" cy={21 - i} rx={r + 3} ry={r} fill="none" stroke="#1c1915" strokeWidth="5" />)}
      {[14, 11, 8].map((r, i) => <ellipse key={`c${r}`} cx="20" cy={21 - i} rx={r + 3} ry={r} fill="none" stroke={color} strokeWidth="3" />)}
      <path d="M33 26 Q38 34 30 37" fill="none" stroke={color} strokeWidth="3" strokeLinecap="round" />
    </svg>
  )
}

/** Passport-stamp style badge used for achievements. */
export function BadgeGlyph({ icon, size = 26, color = 'currentColor' }: { icon: string; size?: number; color?: string }) {
  const p: Record<string, React.ReactNode> = {
    flag: <><path d="M7 21V4" /><path d="M7 4h10l-2 4 2 4H7" /></>,
    eye: <><path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12Z" /><circle cx="12" cy="12" r="3" /></>,
    repeat: <><path d="M17 2l3 3-3 3" /><path d="M4 11V9a4 4 0 0 1 4-4h12" /><path d="M7 22l-3-3 3-3" /><path d="M20 13v2a4 4 0 0 1-4 4H4" /></>,
    target: <><circle cx="12" cy="12" r="9" /><circle cx="12" cy="12" r="5" /><circle cx="12" cy="12" r="1.5" /></>,
    feather: <><path d="M20 4C12 4 6 10 6 18" /><path d="M20 4c0 8-6 12-14 14" /><path d="M4 20l4-4" /></>,
    droplet: <path d="M12 3s6 7 6 11a6 6 0 0 1-12 0c0-4 6-11 6-11Z" />,
    arm: <><path d="M5 19c2-6 4-8 8-8l3-5 3 2-2 5c2 2 1 6-3 6H5Z" /></>,
    bolt: <path d="M13 2 4 14h7l-1 8 9-12h-7l1-8Z" />,
    broom: <><path d="M14 3l7 7" /><path d="M12 9l3 3-6 9-6-6 9-6Z" /></>,
    crown: <path d="M3 18h18l-2-10-4 4-3-6-3 6-4-4-2 10Z" />,
    sun: <><circle cx="12" cy="12" r="4" /><path d="M12 2v2M12 20v2M2 12h2M20 12h2M5 5l1.5 1.5M17.5 17.5 19 19M5 19l1.5-1.5M17.5 6.5 19 5" /></>,
    star: <path d="M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1L3.2 9.5l6.1-.9L12 3Z" />,
    users: <><circle cx="8" cy="8" r="3" /><circle cx="16" cy="8" r="3" /><path d="M2 20c0-3 3-5 6-5s6 2 6 5" /><path d="M14 15c3 0 8 1 8 5" /></>,
    gem: <><path d="M6 3h12l3 6-9 12L3 9l3-6Z" /><path d="M3 9h18M9 3l3 18 3-18" /></>,
    mountain: <><path d="M2 20 9 7l4 6 2-3 7 10H2Z" /></>,
    turn: <><path d="M9 14 4 9l5-5" /><path d="M4 9h11a5 5 0 0 1 0 10h-3" /></>,
  }
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
      {p[icon] ?? p.star}
    </svg>
  )
}
