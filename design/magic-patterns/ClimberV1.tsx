import React from 'react'
import { Look } from '../data/cosmetics'

export type Pose = 'idle' | 'climbA' | 'climbB' | 'reach' | 'clip' | 'rest' | 'fall' | 'celebrate' | 'hang' | 'wave'

interface Props {
  look: Look
  pose?: Pose
  view?: 'front' | 'back'
  size?: number
  reducedMotion?: boolean
  className?: string
  style?: React.CSSProperties
}

/**
 * The player climber, drawn as layered vector parts so every cosmetic slot
 * (jacket, headwear, pack, harness, chalk bag) is its own swappable layer —
 * the same split the Godot sprite generator needs to output.
 */
export function ClimberV1({ look, pose = 'idle', view = 'front', size = 120, reducedMotion, className, style }: Props) {
  const p = POSES[pose]
  const t: React.CSSProperties = {
    transition: reducedMotion ? 'none' : 'transform 180ms cubic-bezier(0.23, 1, 0.32, 1)',
    transformBox: 'view-box',
    transformOrigin: '0 0',
  }
  const back = view === 'back'
  const ink = '#1c1915'
  const pants = '#3a342c'

  const arm = (side: 'L' | 'R') => {
    const a = side === 'L' ? p.aL : -p.aR
    const f = side === 'L' ? p.fL : -p.fR
    const x = side === 'L' ? 45 : 75
    return (
      <g transform={`translate(${x} 58)`}>
        <g style={{ ...t, transform: `rotate(${a}deg)` }}>
          <line x1="0" y1="0" x2="0" y2="18" stroke={ink} strokeWidth="12" strokeLinecap="round" />
          <line x1="0" y1="0" x2="0" y2="18" stroke={look.jacket} strokeWidth="9" strokeLinecap="round" />
          <g transform="translate(0 18)">
            <g style={{ ...t, transform: `rotate(${f}deg)` }}>
              <line x1="0" y1="0" x2="0" y2="14" stroke={ink} strokeWidth="11" strokeLinecap="round" />
              <line x1="0" y1="0" x2="0" y2="14" stroke={look.jacket} strokeWidth="8" strokeLinecap="round" />
              <line x1="0" y1="10" x2="0" y2="13" stroke={look.jacketTrim} strokeWidth="8" strokeLinecap="butt" />
              <circle cx="0" cy="18" r="5.2" fill={ink} />
              <circle cx="0" cy="18" r="4" fill={look.skin} />
            </g>
          </g>
        </g>
      </g>
    )
  }

  const leg = (side: 'L' | 'R') => {
    const a = side === 'L' ? p.lL : -p.lR
    const k = side === 'L' ? p.kL : -p.kR
    const x = side === 'L' ? 53 : 67
    return (
      <g transform={`translate(${x} 92)`}>
        <g style={{ ...t, transform: `rotate(${a}deg)` }}>
          <line x1="0" y1="0" x2="0" y2="20" stroke={ink} strokeWidth="14" strokeLinecap="round" />
          <line x1="0" y1="0" x2="0" y2="20" stroke={pants} strokeWidth="11" strokeLinecap="round" />
          {/* harness leg loop */}
          <rect x="-6.5" y="3" width="13" height="4" rx="2" fill={look.harness} stroke={ink} strokeWidth="1" />
          <g transform="translate(0 20)">
            <g style={{ ...t, transform: `rotate(${k}deg)` }}>
              <line x1="0" y1="0" x2="0" y2="17" stroke={ink} strokeWidth="13" strokeLinecap="round" />
              <line x1="0" y1="0" x2="0" y2="17" stroke={pants} strokeWidth="10" strokeLinecap="round" />
              <path d={side === 'L' ? 'M-6 18 Q-7 25 1 25 L6 25 Q8 21 5 17 Z' : 'M6 18 Q7 25 -1 25 L-6 25 Q-8 21 -5 17 Z'} fill="#5a3d2e" stroke={ink} strokeWidth="1.4" />
            </g>
          </g>
        </g>
      </g>
    )
  }

  return (
    <svg viewBox="0 0 120 150" width={size} height={size * 1.25} className={className} style={{ overflow: 'visible', ...style }} aria-hidden>
      <g style={{ ...t, transform: `translate(60px, 92px) rotate(${p.body}deg) translate(-60px, ${-92 + p.dy}px)` }}>
        {/* pack behind the body (front view) */}
        {!back && look.pack !== 'none' && (
          <rect x={look.pack === 'expedition' ? 37 : 40} y={look.pack === 'expedition' ? 46 : 52} width={look.pack === 'expedition' ? 46 : 40} height={look.pack === 'expedition' ? 44 : 34} rx="8" fill={look.packColor} stroke={ink} strokeWidth="1.5" />
        )}
        {leg('L')}
        {leg('R')}
        {/* far arm first when facing the wall */}
        {back && arm('L')}
        {back && arm('R')}
        {/* torso */}
        <path d="M44 56 Q44 50 52 50 L68 50 Q76 50 76 56 L77 90 Q77 95 72 95 L48 95 Q43 95 43 90 Z" fill={look.jacket} stroke={ink} strokeWidth="1.6" />
        <path d="M62 51 L68 50 Q76 50 76 56 L77 90 Q77 95 72 95 L64 95 Z" fill={look.jacketTrim} opacity="0.55" />
        {!back && <line x1="60" y1="53" x2="60" y2="84" stroke={look.jacketTrim} strokeWidth="1.6" />}
        {!back && <path d="M53 50 L60 57 L67 50" fill="none" stroke={look.jacketTrim} strokeWidth="2" strokeLinejoin="round" />}
        {/* pack straps (front) or pack body (back) */}
        {!back && look.pack !== 'none' && (
          <g stroke={look.packColor} strokeWidth="3.4" strokeLinecap="round">
            <line x1="50" y1="52" x2="49" y2="80" />
            <line x1="70" y1="52" x2="71" y2="80" />
            <line x1="49" y1="68" x2="71" y2="68" strokeWidth="2" />
          </g>
        )}
        {back && look.pack !== 'none' && <PackBack look={look} ink={ink} />}
        {/* harness waist belt + belay loop */}
        <rect x="42.5" y="85" width="35" height="6.5" rx="3" fill={look.harness} stroke={ink} strokeWidth="1.3" />
        {!back && <rect x="57" y="89" width="6" height="7" rx="2.5" fill="none" stroke={look.harness} strokeWidth="2.4" />}
        {/* chalk bag */}
        <ChalkBag look={look} x={back ? 54 : 73} y={back ? 88 : 84} ink={ink} />
        {/* arms in front when facing camera */}
        {!back && arm('L')}
        {!back && arm('R')}
        {/* head */}
        <g>
          <rect x="56" y="44" width="8" height="8" rx="3" fill={look.skin} stroke={ink} strokeWidth="1.2" />
          <circle cx="60" cy="33" r="15" fill={back ? look.hair : look.skin} stroke={ink} strokeWidth="1.6" />
          {!back && (
            <>
              <path d="M45.5 31 Q47 18 60 18 Q73 18 74.5 31 Q68 25 60 26 Q52 25 45.5 31 Z" fill={look.hair} />
              <ellipse cx="54.5" cy="35" rx="1.9" ry="2.4" fill={ink} />
              <ellipse cx="65.5" cy="35" rx="1.9" ry="2.4" fill={ink} />
              <circle cx="51" cy="40" r="2.4" fill="#e07a5f" opacity="0.35" />
              <circle cx="69" cy="40" r="2.4" fill="#e07a5f" opacity="0.35" />
              <path d={pose === 'fall' ? 'M57 42 Q60 39.5 63 42' : 'M57 41 Q60 43.5 63 41'} fill="none" stroke={ink} strokeWidth="1.4" strokeLinecap="round" />
            </>
          )}
          {back && <path d="M46 36 Q60 44 74 36" fill="none" stroke="#000" strokeOpacity="0.18" strokeWidth="3" />}
          <Headwear look={look} back={back} ink={ink} />
        </g>
      </g>
    </svg>
  )
}

function PackBack({ look, ink }: { look: Look; ink: string }) {
  const big = look.pack === 'expedition'
  const small = look.pack === 'daypack'
  const w = big ? 34 : small ? 24 : 28
  const h = big ? 44 : small ? 26 : 32
  const x = 60 - w / 2
  const y = big ? 48 : 54
  return (
    <g>
      <rect x={x} y={y} width={w} height={h} rx="7" fill={look.packColor} stroke={ink} strokeWidth="1.5" />
      <path d={`M${x + 2} ${y + 9} Q60 ${y + 14} ${x + w - 2} ${y + 9}`} fill="none" stroke={ink} strokeOpacity="0.5" strokeWidth="1.3" />
      <rect x={60 - w / 4} y={y + h * 0.5} width={w / 2} height={h * 0.3} rx="3" fill="#000" fillOpacity="0.15" />
      {big && <rect x={x - 2} y={y - 6} width={w + 4} height="8" rx="4" fill="#cdbf9f" stroke={ink} strokeWidth="1.2" />}
    </g>
  )
}

function ChalkBag({ look, x, y, ink }: { look: Look; x: number; y: number; ink: string }) {
  const id = `bag-${look.bagPattern}-${x}`
  return (
    <g>
      <defs>
        <clipPath id={id}><rect x={x - 5.5} y={y} width="11" height="13" rx="3.5" /></clipPath>
      </defs>
      <rect x={x - 5.5} y={y} width="11" height="13" rx="3.5" fill={look.chalkBag} stroke={ink} strokeWidth="1.3" />
      <g clipPath={`url(#${id})`} stroke={ink} strokeOpacity="0.45" fill="none" strokeWidth="1.2">
        {look.bagPattern === 'stripe' && <><line x1={x - 6} y1={y + 6} x2={x + 6} y2={y + 4} strokeWidth="2.2" stroke="#a8432a" strokeOpacity="0.9" /><line x1={x - 6} y1={y + 9} x2={x + 6} y2={y + 7} strokeWidth="1.4" stroke="#1f3d34" strokeOpacity="0.9" /></>}
        {look.bagPattern === 'topo' && <><path d={`M${x - 6} ${y + 5} q4 -3 6 0 t6 0`} /><path d={`M${x - 6} ${y + 8.5} q4 -3 6 0 t6 0`} /><path d={`M${x - 6} ${y + 12} q4 -3 6 0 t6 0`} /></>}
        {look.bagPattern === 'dots' && <g fill="#f7f4ee" stroke="none" fillOpacity="0.95"><circle cx={x - 2.5} cy={y + 5} r="1.2" /><circle cx={x + 2} cy={y + 7} r="1.2" /><circle cx={x - 1.5} cy={y + 10} r="1.2" /><circle cx={x + 3} cy={y + 11} r="1" /></g>}
      </g>
      <rect x={x - 6.5} y={y - 1.5} width="13" height="3.2" rx="1.6" fill="#f7f4ee" stroke={ink} strokeWidth="1" />
    </g>
  )
}

function Headwear({ look, back, ink }: { look: Look; back: boolean; ink: string }) {
  const c = look.headwearColor
  switch (look.headwear) {
    case 'helmet':
      return (
        <g>
          <path d="M43.5 30 Q44 14 60 14 Q76 14 76.5 30 Z" fill={c} stroke={ink} strokeWidth="1.6" />
          <path d="M42 30 L78 30" stroke={ink} strokeWidth="3.2" strokeLinecap="round" />
          <path d="M42 30 L78 30" stroke={c} strokeWidth="1.6" strokeLinecap="round" />
          <path d="M52 16.5 Q60 13.5 68 16.5" fill="none" stroke="#fff" strokeOpacity="0.5" strokeWidth="2" strokeLinecap="round" />
          {!back && <path d="M46 31 Q47 40 50 44" fill="none" stroke={ink} strokeWidth="1.2" />}
        </g>
      )
    case 'beanie':
      return (
        <g>
          <path d="M45 28 Q45 13 60 13 Q75 13 75 28 Z" fill={c} stroke={ink} strokeWidth="1.6" />
          <rect x="43.5" y="25" width="33" height="7" rx="3" fill={c} stroke={ink} strokeWidth="1.4" />
          <line x1="50" y1="26" x2="50" y2="31" stroke={ink} strokeOpacity="0.25" /><line x1="56" y1="26" x2="56" y2="31" stroke={ink} strokeOpacity="0.25" /><line x1="64" y1="26" x2="64" y2="31" stroke={ink} strokeOpacity="0.25" /><line x1="70" y1="26" x2="70" y2="31" stroke={ink} strokeOpacity="0.25" />
          <circle cx="60" cy="11" r="4.2" fill="#f7f4ee" stroke={ink} strokeWidth="1.2" />
        </g>
      )
    case 'sunhat':
      return (
        <g>
          <ellipse cx="60" cy="27" rx="25" ry="5.2" fill={c} stroke={ink} strokeWidth="1.5" />
          <path d="M47 27 Q47 13 60 13 Q73 13 73 27 Z" fill={c} stroke={ink} strokeWidth="1.5" />
          <rect x="47" y="22" width="26" height="3.5" fill="#a8432a" opacity="0.85" />
        </g>
      )
    case 'headlamp':
      return (
        <g>
          <path d="M45 26 Q60 20 75 26 L75 31 Q60 25 45 31 Z" fill={c} stroke={ink} strokeWidth="1.3" />
          {!back && <><rect x="55.5" y="22" width="9" height="7" rx="2" fill="#2a2a2a" stroke={ink} strokeWidth="1" /><circle cx="60" cy="25.5" r="2.4" fill="#ffd37a" /></>}
          <path d="M46 38 Q60 46 74 38 L74 46 Q60 52 46 46 Z" fill={c} stroke={ink} strokeWidth="1.3" opacity={back ? 1 : 0.95} />
        </g>
      )
    default:
      return back ? null : <path d="M52 19 Q57 13 63 17 Q66 14 69 19" fill="none" stroke={look.hair} strokeWidth="3" strokeLinecap="round" />
  }
}

interface PoseDef { aL: number; fL: number; aR: number; fR: number; lL: number; kL: number; lR: number; kR: number; body: number; dy: number }

const POSES: Record<Pose, PoseDef> = {
  idle: { aL: 12, fL: -8, aR: 12, fR: -8, lL: 4, kL: 0, lR: 4, kR: 0, body: 0, dy: 0 },
  wave: { aL: 12, fL: -8, aR: 150, fR: 30, lL: 4, kL: 0, lR: 4, kR: 0, body: 0, dy: 0 },
  climbA: { aL: 168, fL: 12, aR: 122, fR: 42, lL: 52, kL: -84, lR: 18, kR: -26, body: 0, dy: 0 },
  climbB: { aL: 122, fL: 42, aR: 168, fR: 12, lL: 18, kL: -26, lR: 52, kR: -84, body: 0, dy: -2 },
  reach: { aL: 126, fL: 38, aR: 178, fR: 0, lL: 14, kL: -18, lR: 38, kR: -58, body: 3, dy: -4 },
  clip: { aL: 168, fL: 8, aR: 138, fR: 78, lL: 34, kL: -52, lR: 34, kR: -52, body: -2, dy: 0 },
  rest: { aL: 172, fL: 4, aR: 16, fR: -12, lL: 20, kL: -30, lR: 26, kR: -38, body: 4, dy: 2 },
  hang: { aL: 172, fL: 4, aR: 172, fR: 4, lL: 6, kL: -6, lR: 6, kR: -6, body: 0, dy: 0 },
  fall: { aL: 138, fL: -42, aR: 152, fR: -30, lL: 30, kL: 22, lR: 46, kR: 32, body: -14, dy: 0 },
  celebrate: { aL: 158, fL: -12, aR: 158, fR: -12, lL: 8, kL: 0, lR: 8, kR: 0, body: 0, dy: -3 },
}
