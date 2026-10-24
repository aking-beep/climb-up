import React from 'react'

const INK = '#1c1915'

/** Dome tent, three-quarter view. `lit` glows from inside at night. */
export function Tent({ x, y, w = 96, color, lit, door = 1 }: { x: number; y: number; w?: number; color: string; lit?: boolean; door?: 1 | -1 }) {
  const h = w * 0.62
  return (
    <svg className="pointer-events-none absolute" style={{ left: x - w / 2 - 6, top: y - h - 4 }} width={w + 12} height={h + 14} aria-hidden>
      <ellipse cx={w / 2 + 6} cy={h + 6} rx={w / 2 + 4} ry={7} fill="#000" opacity={0.18} />
      <path d={`M6 ${h + 4} Q${w / 2 + 6} ${-h * 0.15} ${w + 6} ${h + 4} Z`} fill={color} stroke={INK} strokeWidth={1.4} />
      <path d={`M${w / 2 + 6} 3 Q${w * 0.78 + 6} ${h * 0.3} ${w + 6} ${h + 4} L${w / 2 + 6} ${h + 4} Z`} fill="#0b1a2a" opacity={0.18} />
      <path d={`M${w * 0.22 + 6} ${h * 0.55} Q${w / 2 + 6} ${h * 0.02} ${w * 0.78 + 6} ${h * 0.55}`} fill="none" stroke={INK} strokeOpacity={0.45} strokeWidth={1.2} />
      <path d={`M${w / 2 + 6 + door * w * 0.02} ${h + 4} Q${w / 2 + 6 + door * w * 0.1} ${h * 0.42} ${w / 2 + 6 + door * w * 0.24} ${h + 4} Z`} fill={lit ? '#ffd37a' : '#2a2420'} stroke={INK} strokeWidth={1} />
    </svg>
  )
}

export function MessTent({ x, y, lit }: { x: number; y: number; lit?: boolean }) {
  return (
    <svg className="pointer-events-none absolute" style={{ left: x - 92, top: y - 96 }} width={184} height={110} aria-hidden>
      <ellipse cx={92} cy={100} rx={88} ry={9} fill="#000" opacity={0.18} />
      <path d="M8 96 L20 30 L164 30 L176 96 Z" fill="#d8c7a4" stroke={INK} strokeWidth={1.4} />
      <path d="M20 30 L92 6 L164 30 Z" fill="#c9b48e" stroke={INK} strokeWidth={1.4} />
      <path d="M92 30 L164 30 L176 96 L92 96 Z" fill="#0b1a2a" opacity={0.12} />
      <rect x={70} y={52} width={44} height={44} fill={lit ? '#ffd37a' : '#3a2f26'} stroke={INK} strokeWidth={1.2} />
      <path d="M8 96 L176 96" stroke={INK} strokeWidth={1.4} />
    </svg>
  )
}

export function Fire({ x, y, lit, rm }: { x: number; y: number; lit: boolean; rm: boolean }) {
  return (
    <svg className="pointer-events-none absolute" style={{ left: x - 30, top: y - 40 }} width={60} height={56} aria-hidden>
      {[0, 1, 2, 3, 4, 5, 6].map(i => <ellipse key={i} cx={30 + Math.cos(i * 0.9) * 22} cy={44 + Math.sin(i * 0.9) * 8} rx={6} ry={4} fill="#8f8577" stroke={INK} strokeWidth={0.8} />)}
      <path d="M18 44 L42 40 M20 40 L40 46" stroke="#5a3d2e" strokeWidth={4} strokeLinecap="round" />
      {lit && (
        <g style={{ animation: rm ? 'none' : 'flicker 0.5s ease-in-out infinite', transformOrigin: '30px 44px' }}>
          <path d="M22 42 Q20 28 30 14 Q34 26 40 30 Q42 38 38 42 Z" fill="#d9572b" />
          <path d="M26 42 Q26 32 31 24 Q34 32 36 42 Z" fill="#ffd37a" />
        </g>
      )}
    </svg>
  )
}

export function Stove({ x, y, steam, rm }: { x: number; y: number; steam: boolean; rm: boolean }) {
  return (
    <svg className="pointer-events-none absolute" style={{ left: x - 26, top: y - 50 }} width={52} height={56} aria-hidden>
      <rect x={10} y={36} width={32} height={14} rx={3} fill="#4c5866" stroke={INK} strokeWidth={1.2} />
      <path d="M12 36 L12 22 Q26 18 40 22 L40 36 Z" fill="#9aa4ae" stroke={INK} strokeWidth={1.2} />
      <rect x={10} y={20} width={32} height={4} rx={2} fill="#6b7480" stroke={INK} strokeWidth={1} />
      {steam && [0, 1, 2].map(i => <circle key={i} cx={20 + i * 6} cy={12 - i * 3} r={3 + i} fill="#f7f4ee" opacity={0.5} style={{ animation: rm ? 'none' : `grit ${1.6 + i * 0.3}s linear ${i * 0.4}s infinite reverse` }} />)}
    </svg>
  )
}

export function Supplies({ x, y }: { x: number; y: number }) {
  return (
    <svg className="pointer-events-none absolute" style={{ left: x - 50, top: y - 46 }} width={100} height={56} aria-hidden>
      <ellipse cx={50} cy={50} rx={48} ry={6} fill="#000" opacity={0.18} />
      <rect x={6} y={22} width={30} height={26} rx={2} fill="#8a6a46" stroke={INK} strokeWidth={1.2} />
      <rect x={10} y={4} width={26} height={20} rx={2} fill="#9c7a52" stroke={INK} strokeWidth={1.2} />
      {[0, 1, 2].map(i => <g key={i}><rect x={44 + i * 17} y={24} width={14} height={24} rx={3} fill="#e9c46a" stroke={INK} strokeWidth={1.2} /><rect x={48 + i * 17} y={20} width={6} height={5} fill="#3a342c" /></g>)}
    </svg>
  )
}

export function GearPile({ x, y, rope }: { x: number; y: number; rope: string }) {
  return (
    <svg className="pointer-events-none absolute" style={{ left: x - 46, top: y - 40 }} width={92} height={50} aria-hidden>
      <ellipse cx={46} cy={44} rx={44} ry={6} fill="#000" opacity={0.18} />
      <rect x={4} y={18} width={42} height={24} rx={11} fill="#a8432a" stroke={INK} strokeWidth={1.2} />
      <rect x={30} y={10} width={36} height={22} rx={10} fill="#1f3d34" stroke={INK} strokeWidth={1.2} />
      {[0, 1, 2].map(i => <ellipse key={i} cx={74} cy={34 - i * 2} rx={13 - i} ry={6 - i * 0.5} fill="none" stroke={rope} strokeWidth={2.4} />)}
      <path d="M50 40 Q56 30 62 40 Z" fill="#e9c46a" stroke={INK} strokeWidth={1} />
    </svg>
  )
}

export function MapTable({ x, y }: { x: number; y: number }) {
  return (
    <svg className="pointer-events-none absolute" style={{ left: x - 34, top: y - 30 }} width={68} height={40} aria-hidden>
      <path d="M4 30 Q4 10 34 8 Q64 10 64 30 Q34 38 4 30 Z" fill="#7b6a58" stroke={INK} strokeWidth={1.2} />
      <rect x={18} y={10} width={32} height={14} rx={1} fill="#f3efe6" stroke={INK} strokeWidth={0.8} transform="rotate(-6 34 17)" />
      <path d="M22 18 Q30 12 36 17 T46 14" fill="none" stroke="#a8432a" strokeWidth={1.2} transform="rotate(-6 34 17)" />
    </svg>
  )
}

export function Lantern({ x, y, lit }: { x: number; y: number; lit: boolean }) {
  return (
    <svg className="pointer-events-none absolute" style={{ left: x - 6, top: y - 46 }} width={12} height={48} aria-hidden>
      <rect x={5} y={10} width={2} height={38} fill="#5a3d2e" />
      <rect x={1} y={2} width={10} height={11} rx={2} fill={lit ? '#ffd37a' : '#6b6257'} stroke={INK} strokeWidth={1} />
    </svg>
  )
}

export function Signpost({ x, y }: { x: number; y: number }) {
  return (
    <div className="pointer-events-none absolute" style={{ left: x - 4, top: y - 58 }}>
      <div className="absolute left-[3px] top-[16px] h-[42px] w-[3px] bg-[#5a3d2e]" />
      <div className="paper-grain whitespace-nowrap rounded-[3px] border border-paper-edge px-1.5 py-0.5 font-display text-[11px] text-ink">Barafu →</div>
    </div>
  )
}
