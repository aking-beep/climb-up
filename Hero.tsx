import React, { useContext, useEffect, useId, useRef, useState } from 'react'
import { Look } from '../data/cosmetics'
import {
  BUILDS, Build, BuildDef, Body, Expression, HeroPose, HeroView, PoseOut, Targets, V, withBody,
  add, buildScale, computePose, dir, frame, groundY, hipVB, lerpPose, mul, POSE_VIEW,
} from './heroRig'

export type { Build, Body, HeroPose, HeroView, Expression, Targets } from './heroRig'
export { BUILDS } from './heroRig'

/** The build the whole prototype draws with (A is the recommended direction). */
export const HeroBuildContext = React.createContext<Build>('A')

const INK = '#1c1915'
const PANTS = '#3a342c'
const MOUTH = '#5a2a22'

export type Kit = 'climb' | 'trek' | 'camp'

export interface HeroProps {
  look: Look
  pose?: HeroPose
  view?: HeroView
  build?: Build
  /** Body type; falls back to look.body, then 'm'. Same rig, clips and kit. */
  body?: Body
  /** Rendered width in px; height is width × 1.25 (or × 0.9 for a bust). */
  size?: number
  facing?: 1 | -1
  /** Live IK targets: offsets from the hip, in view-box units (see heroHipPx). */
  targets?: Targets
  lean?: number
  expression?: Expression
  kit?: Kit
  crop?: 'full' | 'bust'
  seat?: boolean
  /** Desync NPC loops. */
  phase?: number
  /** Freeze at a time (for frame strips). */
  time?: number
  reducedMotion?: boolean
  className?: string
  style?: React.CSSProperties
}

/**
 * The Phase 2 climber. One rig, three proportion sets (builds A/B/C), every
 * cosmetic slot from Look as its own layer. Joints are solved from the pose
 * library (heroRig.ts) or from live hold targets, so hands and feet land on
 * the holds. Reference for tools/art/characters_hd.py, not final art.
 */
export function Hero(props: HeroProps) {
  const ctxBuild = useContext(HeroBuildContext)
  const {
    look, pose = 'idle', size = 120, facing = 1, targets, lean, kit = 'climb', crop = 'full',
    seat, phase = 0, reducedMotion: rm, className, style,
  } = props
  const body: Body = props.body ?? look.body ?? 'm'
  const fem = body === 'f'
  const b = withBody(BUILDS[props.build ?? ctxBuild], body)
  const view = props.view ?? POSE_VIEW[pose]
  const clock = useHeroTime(!rm && props.time === undefined)
  const t = (props.time ?? clock) + phase
  const uid = useId().replace(/:/g, '')
  const s = buildScale(b)
  const G = groundY(b)

  const local = targets ? scaleTargets(targets, 1 / s) : undefined
  const target = computePose(b, pose, view, t, local, lean)
  const cur = useRef<PoseOut | null>(null)
  const last = useRef(t)
  const key = useRef(`${b.id}-${view}-${body}`)
  if (!cur.current || rm || props.time !== undefined || key.current !== `${b.id}-${view}-${body}`) {
    cur.current = target
  } else {
    const dt = Math.min(0.1, Math.max(0, t - last.current))
    cur.current = lerpPose(cur.current, target, 1 - Math.exp(-dt / 0.055))
  }
  last.current = t
  key.current = `${b.id}-${view}-${body}`
  const p = cur.current
  const expr = props.expression ?? p.expr

  const f = frame(b, p.lean, view)
  const chain = (S: V, u: number, l: number, l1: number, l2: number): [V, V, V] => {
    const E = add(S, mul(dir(u), l1))
    return [S, E, add(E, mul(dir(l), l2))]
  }
  const armL = chain(f.sL, p.uaL, p.faL, b.ua, b.fa)
  const armR = chain(f.sR, p.uaR, p.faR, b.ua, b.fa)
  const legL = chain(f.hL, p.thL, p.shL, b.th, b.sh)
  const legR = chain(f.hR, p.thR, p.shR, b.th, b.sh)
  const oy = p.grounded ? G - (Math.max(legL[2][1], legR[2][1]) + b.ankle) : 0
  const hipX = p.dx
  const hipY = oy - p.lift

  const ow = 1.35 / s
  const side = view === 'side'
  const back = view === 'back'
  const front = view === 'front'
  const climbKit = kit === 'climb'
  const showPack = look.pack !== 'none' && kit !== 'camp'

  const up2: V = [Math.sin(((p.lean + p.tilt) * Math.PI) / 180), -Math.cos(((p.lean + p.tilt) * Math.PI) / 180)]
  const hc = add(f.neckBase, mul(up2, b.neck + b.headR * b.headRy * 0.9))

  const armEl = (pts: [V, V, V], ang: number, far: boolean, thumb: number, k: string) => (
    <g key={k}>
      <Limb pts={pts} ws={b.armW} fill={look.jacket} ow={ow} far={far} />
      <circle cx={lerp(pts[1], pts[2], 0.86)[0]} cy={lerp(pts[1], pts[2], 0.86)[1]} r={b.armW[2] * 1.08} fill={look.jacketTrim} />
      <Hand at={add(pts[2], mul(dir(ang), b.handR * 0.62))} ang={ang} r={b.handR} skin={look.skin} ow={ow} thumb={thumb} far={far} />
    </g>
  )
  const legEl = (pts: [V, V, V], thA: number, shA: number, far: boolean, toe: number, k: string) => (
    <g key={k}>
      <Limb pts={pts} ws={b.legW} fill={PANTS} ow={ow} far={far} />
      {climbKit && <Band at={lerp(pts[0], pts[1], 0.24)} ang={thA} half={b.legW[0] + 0.5} th={1.35} fill={look.harness} ow={ow * 0.8} />}
      <Shoe at={pts[2]} ang={shA} b={b} toe={side ? 1 : toe} frontal={!side} boot={!climbKit} accent={look.rope} ow={ow} far={far} />
    </g>
  )

  const torsoR = side ? 0.82 : 1
  const torso = (
    <g key="torso">
      <defs>
        <clipPath id={`${uid}t`}>
          <Capsule a={f.waist} b={f.chest} r1={b.waistR * torsoR} r2={b.chestR * torsoR} />
        </clipPath>
      </defs>
      <g fill={INK}><Capsule a={f.waist} b={f.chest} r1={b.waistR * torsoR + ow} r2={b.chestR * torsoR + ow} /></g>
      <g fill={look.jacket}><Capsule a={f.waist} b={f.chest} r1={b.waistR * torsoR} r2={b.chestR * torsoR} /></g>
      {/* key light upper-left: cool shade on the far side */}
      <rect clipPath={`url(#${uid}t)`} x={f.chest[0] + b.chestR * (side ? -0.1 : 0.32)} y={-200} width={200} height={400} fill="#0b1a2a" opacity={0.16} />
      {front && <line x1={f.chest[0] * 0.9} y1={f.chest[1] - b.chestR * 0.7} x2={f.waist[0]} y2={f.waist[1] + b.waistR * 0.2} stroke={look.jacketTrim} strokeWidth={ow * 1.1} />}
      {front && <path d={`M${f.neckBase[0] - b.chestR * 0.45} ${f.neckBase[1] + 1} L${f.neckBase[0]} ${f.neckBase[1] + b.chestR * 0.55} L${f.neckBase[0] + b.chestR * 0.45} ${f.neckBase[1] + 1}`} fill="none" stroke={look.jacketTrim} strokeWidth={ow * 1.4} strokeLinejoin="round" />}
      {side && <path d={`M${f.chest[0] + b.chestR * 0.35} ${f.chest[1] - b.chestR * 0.5} Q${f.chest[0] + b.chestR * 0.6} ${f.chest[1] + 3} ${f.waist[0] + b.waistR * 0.45} ${f.waist[1]}`} fill="none" stroke={look.jacketTrim} strokeWidth={ow} />}
    </g>
  )

  const pelvis = side
    ? <g key="pelvis"><circle cx={0} cy={0} r={b.legW[0] + 0.8 + ow} fill={INK} /><circle cx={0} cy={0} r={b.legW[0] + 0.8} fill={PANTS} /></g>
    : <g key="pelvis"><g fill={INK}><Capsule a={f.hL} b={f.hR} r1={b.legW[0] + 0.6 + ow} r2={b.legW[0] + 0.6 + ow} /></g><g fill={PANTS}><Capsule a={f.hL} b={f.hR} r1={b.legW[0] + 0.6} r2={b.legW[0] + 0.6} /></g></g>

  const beltAt = mul(f.up, b.waistR * 0.12)
  const harness = climbKit ? (
    <g key="harness">
      <Band at={beltAt} ang={180 - p.lean} half={b.waistR * (side ? 0.84 : 1.04)} th={1.8} fill={look.harness} ow={ow} />
      {front && <ellipse cx={beltAt[0]} cy={beltAt[1] + 3} rx={1.6} ry={2.2} fill="none" stroke={look.harness} strokeWidth={1.3} />}
      <Quickdraw at={add(beltAt, mul(f.right, (side ? -0.7 : 0.82) * b.waistR))} ow={ow} />
      {!side && <Quickdraw at={add(beltAt, mul(f.right, -0.82 * b.waistR))} ow={ow} />}
    </g>
  ) : null
  const chalk = climbKit ? (
    <ChalkBag key="chalk" look={look} at={add(beltAt, back ? [0, 1.2] : side ? mul(f.right, -b.waistR * 0.95) : mul(f.right, b.waistR * 1.05))} k={b.waistR / 8.5} ow={ow} />
  ) : null

  const pk = packSize(look, b)
  const packBack = showPack && back ? (
    <g key="pack" transform={`translate(${f.chest[0]} ${f.chest[1]}) rotate(${p.lean})`}>
      <rect x={-pk.w / 2 - ow} y={-pk.h * 0.6 - ow} width={pk.w + ow * 2} height={pk.h + ow * 2} rx={pk.w * 0.3} fill={INK} />
      <rect x={-pk.w / 2} y={-pk.h * 0.6} width={pk.w} height={pk.h} rx={pk.w * 0.3} fill={look.packColor} />
      <rect x={pk.w * 0.08} y={-pk.h * 0.6} width={pk.w * 0.42} height={pk.h} rx={pk.w * 0.2} fill="#0b1a2a" opacity={0.16} />
      <path d={`M${-pk.w / 2 + 1} ${-pk.h * 0.32} Q0 ${-pk.h * 0.18} ${pk.w / 2 - 1} ${-pk.h * 0.32}`} fill="none" stroke={INK} strokeOpacity={0.5} strokeWidth={ow} />
      <rect x={-pk.w * 0.26} y={pk.h * 0.02} width={pk.w * 0.52} height={pk.h * 0.24} rx={2} fill="#000" opacity={0.14} />
      {look.pack === 'expedition' && <rect x={-pk.w / 2 - 1.5} y={-pk.h * 0.6 - 5} width={pk.w + 3} height={6} rx={3} fill="#cdbf9f" stroke={INK} strokeWidth={ow} />}
    </g>
  ) : null
  const packBehind = showPack && !back ? (
    side ? (
      <g key="packb" transform={`translate(${f.chest[0] - f.right[0] * (b.chestR * 0.8 + pk.w * 0.26)} ${f.chest[1] - f.right[1] * (b.chestR * 0.8 + pk.w * 0.26)}) rotate(${p.lean})`}>
        <rect x={-pk.w * 0.3 - ow} y={-pk.h * 0.6 - ow} width={pk.w * 0.6 + ow * 2} height={pk.h + ow * 2} rx={pk.w * 0.22} fill={INK} />
        <rect x={-pk.w * 0.3} y={-pk.h * 0.6} width={pk.w * 0.6} height={pk.h} rx={pk.w * 0.22} fill={look.packColor} />
        {look.pack === 'expedition' && <rect x={-pk.w * 0.34} y={-pk.h * 0.6 - 5} width={pk.w * 0.68} height={6} rx={3} fill="#cdbf9f" stroke={INK} strokeWidth={ow} />}
      </g>
    ) : (
      <g key="packb" transform={`translate(${f.chest[0]} ${f.chest[1]}) rotate(${p.lean})`}>
        <rect x={-pk.w / 2 - 1.5 - ow} y={-pk.h * 0.62 - ow} width={pk.w + 3 + ow * 2} height={pk.h * 0.9} rx={pk.w * 0.3} fill={INK} />
        <rect x={-pk.w / 2 - 1.5} y={-pk.h * 0.62} width={pk.w + 3} height={pk.h * 0.9} rx={pk.w * 0.3} fill={look.packColor} />
      </g>
    )
  ) : null
  const straps = showPack && !back ? (
    <g key="straps" stroke={look.packColor} strokeWidth={2.4} strokeLinecap="round" fill="none">
      {side ? (
        <path d={`M${f.sR[0] - 1} ${f.sR[1]} Q${f.chest[0] + b.chestR * 0.9} ${f.chest[1] + 2} ${f.waist[0] + b.waistR * 0.5} ${f.waist[1] - 1}`} />
      ) : (
        <>
          <path d={`M${f.sL[0] + 2.5} ${f.sL[1] - 1} L${f.waist[0] - b.waistR * 0.55} ${f.waist[1]}`} />
          <path d={`M${f.sR[0] - 2.5} ${f.sR[1] - 1} L${f.waist[0] + b.waistR * 0.55} ${f.waist[1]}`} />
          <path d={`M${f.chest[0] - b.chestR * 0.55} ${f.chest[1]} L${f.chest[0] + b.chestR * 0.55} ${f.chest[1]}`} strokeWidth={1.4} />
        </>
      )}
    </g>
  ) : null

  const neckA = add(f.neckBase, mul(f.up, -1.5))
  const neckB = add(f.neckBase, mul(up2, b.neck + 2.5))
  const neck = (
    <g key="neck">
      <g fill={INK}><Capsule a={neckA} b={neckB} r1={b.headR * 0.24 + ow} r2={b.headR * 0.24 + ow} /></g>
      <g fill={look.skin}><Capsule a={neckA} b={neckB} r1={b.headR * 0.24} r2={b.headR * 0.24} /></g>
      {look.headwear === 'headlamp' && <g fill={look.headwearColor}><Capsule a={add(neckA, mul(f.up, 1))} b={add(neckA, mul(f.up, 3.2))} r1={b.headR * 0.32} r2={b.headR * 0.3} /></g>}
    </g>
  )

  const head = (
    <g key="head" transform={`translate(${hc[0]} ${hc[1]}) rotate(${p.lean + p.tilt}) scale(${b.headR / 15})`}>
      <Head b={b} view={view} look={look} expr={expr} t={t} fem={fem} ow={(ow * 15) / b.headR} />
    </g>
  )

  const seatEl = seat ? (
    <path key="seat" d={`M${-b.th * 0.9} ${G} Q${-b.th * 1.0} ${hipY + b.legW[0] * 0.8} ${-b.th * 0.2} ${hipY + b.legW[0] * 0.7} Q${b.th * 0.5} ${hipY + b.legW[0] * 0.6} ${b.th * 0.62} ${G} Z`}
      transform={`translate(${-hipX} ${-hipY})`} fill="#7b6a58" stroke={INK} strokeWidth={ow} />
  ) : null

  const thumbL = front ? 1 : back ? -1 : 1
  const parts: React.ReactNode[] = []
  if (side) {
    parts.push(seatEl, armEl(armL, p.faL, true, 1, 'aF'), legEl(legL, p.thL, p.shL, true, 1, 'lF'), packBehind, legEl(legR, p.thR, p.shR, false, 1, 'lN'), pelvis, torso, harness, chalk, straps, neck, head, armEl(armR, p.faR, false, 1, 'aN'))
  } else if (back) {
    parts.push(legEl(legL, p.thL, p.shL, false, -1, 'lL'), legEl(legR, p.thR, p.shR, false, 1, 'lR'), pelvis, torso, harness, neck, packBack, chalk, head, armEl(armL, p.faL, false, thumbL, 'aL'), armEl(armR, p.faR, false, -thumbL, 'aR'))
  } else {
    parts.push(seatEl, packBehind, legEl(legL, p.thL, p.shL, false, -1, 'lL'), legEl(legR, p.thR, p.shR, false, 1, 'lR'), pelvis, torso, harness, chalk, straps, neck, head, armEl(armL, p.faL, false, thumbL, 'aL'), armEl(armR, p.faR, false, -thumbL, 'aR'))
  }

  const tf = `translate(60 ${146}) scale(${s * facing} ${s}) translate(0 ${-G}) translate(${hipX} ${hipY})`
  let vb = '0 0 120 150'
  let h = size * 1.25
  if (crop === 'bust') {
    const hx = 60 + s * facing * (hc[0] + hipX)
    const hy = 146 + s * (hc[1] + hipY - G)
    const w = s * b.headR * 5.2
    vb = `${hx - w / 2} ${hy - s * b.headR * 1.9} ${w} ${w * 0.9}`
    h = size * 0.9
  }

  return (
    <svg viewBox={vb} width={size} height={h} className={className} style={{ overflow: crop === 'bust' ? 'hidden' : 'visible', ...style }} aria-hidden>
      <g transform={tf} strokeLinejoin="round">{parts}</g>
    </svg>
  )
}

/** Where the hip lands in px inside a Hero of this size (for placing it on holds). */
export function heroHipPx(build: Build, size: number): V {
  const h = hipVB(BUILDS[build])
  return [h[0] * (size / 120), h[1] * (size / 120)]
}

/* ---------------------------------------------------------------- parts */

function Capsule({ a, b, r1, r2 }: { a: V; b: V; r1: number; r2: number }) {
  return (
    <>
      <polygon points={seg(a, b, r1, r2)} />
      <circle cx={a[0]} cy={a[1]} r={r1} />
      <circle cx={b[0]} cy={b[1]} r={r2} />
    </>
  )
}

function Limb({ pts, ws, fill, ow, far }: { pts: [V, V, V]; ws: [number, number, number]; fill: string; ow: number; far: boolean }) {
  const shapes = (g: number) => (
    <>
      <polygon points={seg(pts[0], pts[1], ws[0] + g, ws[1] + g)} />
      <polygon points={seg(pts[1], pts[2], ws[1] + g, ws[2] + g)} />
      {pts.map((q, i) => <circle key={i} cx={q[0]} cy={q[1]} r={ws[i] + g} />)}
    </>
  )
  return (
    <g>
      <g fill={INK}>{shapes(ow)}</g>
      <g fill={fill}>{shapes(0)}</g>
      {far && <g fill="#0b1a2a" opacity={0.24}>{shapes(0)}</g>}
    </g>
  )
}

function Hand({ at, ang, r, skin, ow, thumb, far }: { at: V; ang: number; r: number; skin: string; ow: number; thumb: number; far: boolean }) {
  return (
    <g transform={`translate(${at[0]} ${at[1]}) rotate(${-ang})`}>
      <ellipse cx={thumb * r * 0.62} cy={-r * 0.2} rx={r * 0.36} ry={r * 0.5} fill={skin} stroke={INK} strokeWidth={ow} />
      <ellipse cx={0} cy={0} rx={r * 0.8} ry={r} fill={skin} stroke={INK} strokeWidth={ow} />
      <path d={`M${-r * 0.5} ${r * 0.35} Q0 ${r * 0.62} ${r * 0.5} ${r * 0.35}`} fill="none" stroke={INK} strokeOpacity={0.35} strokeWidth={ow * 0.7} />
      {far && <ellipse cx={0} cy={0} rx={r * 0.8} ry={r} fill="#0b1a2a" opacity={0.22} />}
    </g>
  )
}

function Shoe({ at, ang, b, toe, frontal, boot, accent, ow, far }: { at: V; ang: number; b: BuildDef; toe: number; frontal: boolean; boot: boolean; accent: string; ow: number; far: boolean }) {
  const k = b.foot / 10.5
  const sx = (frontal ? 0.62 : 1) * toe * k
  const body = boot ? '#5a3d2e' : '#4a5a66'
  return (
    <g transform={`translate(${at[0]} ${at[1]}) rotate(${-ang}) scale(${sx} ${k})`}>
      <path d={boot ? 'M-4 -4 Q-5 3.5 -3 4.6 L8 4.6 Q11 4.4 11 2 Q10 -1 5 -2.2 L3.5 -4.5 Z' : 'M-3.6 -3 Q-4.6 3 -2.6 4.2 L7.4 4.2 Q11 4 11.4 2 Q9.4 -1 4.2 -2.6 L2.6 -4 Z'}
        fill={body} stroke={INK} strokeWidth={ow / k} />
      <path d={boot ? 'M-3.4 3.4 L10.6 3.4' : 'M-2.8 3.1 L10.8 2.6'} stroke="#2a2420" strokeWidth={1.8} strokeLinecap="round" />
      {!boot && <path d="M0.6 -2.6 L3.4 -1.4" stroke={accent} strokeWidth={1.7} strokeLinecap="round" />}
      {boot && <path d="M0 -3 L2.6 -1.6 M-0.6 -1 L2 0.2" stroke="#d8c7a4" strokeWidth={0.7} />}
      {far && <path d="M-3.6 -3 Q-4.6 3 -2.6 4.2 L7.4 4.2 Q11 4 11.4 2 Q9.4 -1 4.2 -2.6 L2.6 -4 Z" fill="#0b1a2a" opacity={0.24} />}
    </g>
  )
}

function Band({ at, ang, half, th, fill, ow }: { at: V; ang: number; half: number; th: number; fill: string; ow: number }) {
  return (
    <g transform={`translate(${at[0]} ${at[1]}) rotate(${-ang + 90})`}>
      <rect x={-th} y={-half} width={th * 2} height={half * 2} rx={th} fill={fill} stroke={INK} strokeWidth={ow} />
    </g>
  )
}

function Quickdraw({ at, ow }: { at: V; ow: number }) {
  return (
    <g transform={`translate(${at[0]} ${at[1] + 1.4})`}>
      <path d="M-0.9 0 L-0.9 3.4 M0.9 0 L0.9 3.4" stroke="#b9c2c8" strokeWidth={0.9} />
      <rect x={-1.1} y={3} width={2.2} height={3.2} rx={0.6} fill="#e9c46a" stroke={INK} strokeWidth={ow * 0.6} />
    </g>
  )
}

function ChalkBag({ look, at, k, ow }: { key?: React.Key; look: Look; at: V; k: number; ow: number }) {
  const w = 5.4 * k, h = 6.2 * k
  return (
    <g transform={`translate(${at[0]} ${at[1]})`}>
      <rect x={-w / 2} y={0} width={w} height={h} rx={w * 0.32} fill={look.chalkBag} stroke={INK} strokeWidth={ow} />
      {look.bagPattern === 'stripe' && <line x1={-w / 2} y1={h * 0.5} x2={w / 2} y2={h * 0.4} stroke="#a8432a" strokeWidth={1.2} />}
      {look.bagPattern === 'topo' && <path d={`M${-w / 2} ${h * 0.45} q${w / 4} -1.2 ${w / 2} 0 t${w / 2} 0`} fill="none" stroke={INK} strokeOpacity={0.5} strokeWidth={0.6} />}
      {look.bagPattern === 'dots' && <g fill="#f7f4ee"><circle cx={-w * 0.18} cy={h * 0.45} r={0.6} /><circle cx={w * 0.2} cy={h * 0.65} r={0.6} /></g>}
      <rect x={-w / 2 - 0.4} y={-0.9} width={w + 0.8} height={1.8} rx={0.9} fill="#f7f4ee" stroke={INK} strokeWidth={ow * 0.8} />
    </g>
  )
}

/* ---------------------------------------------------------------- head (authored at R = 15) */

function Head({ b, view, look, expr, t, ow, fem }: { b: BuildDef; view: HeroView; look: Look; expr: Expression; t: number; ow: number; fem: boolean }) {
  const rx = 15 * b.headRx, ry = 15 * b.headRy
  const back = view === 'back', side = view === 'side'
  const hw = look.headwear
  const sway = Math.sin(t * 2.6) * 1.6
  return (
    <g>
      {/* female: ponytail behind the head (side), longer frame (front) */}
      {fem && side && <path d={`M-11 -7 Q-25 ${0 + sway} ${-21 + sway} 17 Q-19 21 -16 17 Q-17 5 -7 -1 Z`} fill={look.hair} stroke={INK} strokeWidth={ow} />}
      {fem && !side && !back && <path d={`M${-rx - 2} -2 Q${-rx - 3} 14 ${-rx + 3} 18 L${rx - 3} 18 Q${rx + 3} 14 ${rx + 2} -2 Z`} fill={look.hair} stroke={INK} strokeWidth={ow} />}
      {!back && <ellipse cx={side ? -0.8 : 0} cy={-1.5} rx={rx + 0.8} ry={ry + 0.4} fill={look.hair} stroke={INK} strokeWidth={ow} />}
      {!side && !back && <g fill={look.skin} stroke={INK} strokeWidth={ow}><ellipse cx={-rx} cy={3} rx={2.6} ry={3.4} /><ellipse cx={rx} cy={3} rx={2.6} ry={3.4} /></g>}
      {back && <g fill={look.skin} stroke={INK} strokeWidth={ow}><ellipse cx={-rx + 0.4} cy={3} rx={2.4} ry={3.2} /><ellipse cx={rx - 0.4} cy={3} rx={2.4} ry={3.2} /></g>}
      <ellipse cx={0} cy={0} rx={rx} ry={ry} fill={back ? look.hair : look.skin} stroke={INK} strokeWidth={ow} />
      {back && <path d={`M${-rx * 0.8} ${ry * 0.55} Q0 ${ry * 0.95} ${rx * 0.8} ${ry * 0.55}`} fill="none" stroke="#000" strokeOpacity={0.2} strokeWidth={2} />}
      {side && <ellipse cx={-3.6} cy={3} rx={2.4} ry={3.3} fill={look.skin} stroke={INK} strokeWidth={ow} />}
      {fem && back && <path d={`M-4.5 -4 Q${-6 + sway} 14 ${-2 + sway} 25 Q${1 + sway} 28 ${3.5 + sway} 24 Q5.5 12 4.5 -4 Z`} fill={look.hair} stroke={INK} strokeWidth={ow} />}
      {fem && back && <rect x={-3.6} y={-5} width={7.2} height={3} rx={1.5} fill={look.headwearColor} stroke={INK} strokeWidth={ow * 0.7} />}
      {!back && <Face b={b} side={side} expr={expr} t={t} ow={ow} skin={look.skin} fem={fem} />}
      {!back && (
        <g transform={`scale(${b.headRx} ${b.headRy})`}>
          <path d={side
            ? 'M-15.2 4 Q-16 -15.5 0 -16 Q14 -15.8 15.3 -3 Q11 -8.5 5 -9 Q1 -6 -4 -8 Q-6 -1 -8.6 1.5 Q-11.5 6 -15.2 4 Z'
            : 'M-15.2 1 Q-16 -15.5 0 -16 Q16 -15.5 15.2 1 Q14 -6 9 -8.5 Q4 -5.5 -1 -8.8 Q-6 -6 -10 -8 Q-13.5 -4 -15.2 1 Z'}
            fill={look.hair} stroke={INK} strokeWidth={ow} />
        </g>
      )}
      <g transform={`scale(${b.headRx} ${b.headRy})`}>
        <Headwear hw={hw} c={look.headwearColor} view={view} ow={ow} strap={look.harness} />
      </g>
    </g>
  )
}

function Face({ b, side, expr, t, ow, skin, fem }: { b: BuildDef; side: boolean; expr: Expression; t: number; ow: number; skin: string; fem: boolean }) {
  const e = b.eye
  const blink = (t % 3.7) < 0.12 && expr !== 'happy'
  const closed = blink || expr === 'calm'
  const xs = side ? [7.4, 0.6] : [-e.x, e.x]
  const sc = side ? [1, 0.72] : [1, 1]
  const mx = side ? 6.6 : 0
  const my = e.y + (b.id === 'B' ? 8 : 8.6)
  const w = b.id === 'B' ? 4 : 3.3
  const innerDir = (x: number) => (side ? -1 : x < 0 ? 1 : -1)
  const browLift = expr === 'worried' ? -1.6 : expr === 'effort' || expr === 'determined' ? 1.3 : expr === 'happy' ? -0.6 : 0

  return (
    <g>
      {b.cheek && xs.map((x, i) => <circle key={`c${i}`} cx={x + (side ? 1 : x < 0 ? -2.2 : 2.2)} cy={e.y + 5.4} r={2.6 * sc[i]} fill="#e07a5f" opacity={0.3} />)}
      {xs.map((x, i) => {
        const rx = e.rx * sc[i], ry = e.ry
        if (closed) return <path key={i} d={`M${x - rx} ${e.y} Q${x} ${e.y + ry * 0.75} ${x + rx} ${e.y}`} fill="none" stroke={INK} strokeWidth={ow * 1.2} strokeLinecap="round" />
        if (expr === 'happy') return <path key={i} d={`M${x - rx} ${e.y + ry * 0.35} Q${x} ${e.y - ry * 1.05} ${x + rx} ${e.y + ry * 0.35}`} fill="none" stroke={INK} strokeWidth={ow * 1.4} strokeLinecap="round" />
        const tired = expr === 'tired'
        return (
          <g key={i}>
            {b.id === 'C' && <ellipse cx={x} cy={e.y} rx={rx * 1.25} ry={ry * 1.05} fill="#f7f4ee" stroke={INK} strokeWidth={ow * 0.8} />}
            <ellipse cx={x + (side ? 0.4 : 0)} cy={e.y + (tired ? ry * 0.25 : 0)} rx={b.id === 'C' ? ry * 0.95 : rx} ry={tired ? ry * 0.6 : ry} fill={b.id === 'C' ? '#3a2a20' : INK} />
            <circle cx={x - rx * 0.28} cy={e.y - ry * 0.32} r={e.hl * sc[i]} fill="#fff" />
            {tired && <path d={`M${x - rx * 1.1} ${e.y - ry * 0.25} L${x + rx * 1.1} ${e.y - ry * 0.25}`} stroke={INK} strokeWidth={ow} />}
          </g>
        )
      })}
      {fem && !closed && expr !== 'happy' && xs.map((x, i) => {
        const out = side ? 1 : x < 0 ? -1 : 1
        const ex = x + out * e.rx * sc[i] * 0.85
        return <path key={`l${i}`} d={`M${ex} ${e.y - e.ry * 0.55} l${out * 1.6} -1.4 M${ex - out * 0.6} ${e.y - e.ry * 0.85} l${out * 1.2} -1.6`} stroke={INK} strokeWidth={ow * 0.9} strokeLinecap="round" />
      })}
      {xs.map((x, i) => {
        const by = e.y - e.ry - (b.id === 'C' ? 2.4 : 2.1)
        const d = innerDir(x)
        const hw = 2.4 * sc[i]
        return <path key={`b${i}`} d={`M${x - d * hw} ${by} L${x + d * hw} ${by + browLift}`} stroke={INK} strokeWidth={b.brow} strokeLinecap="round" />
      })}
      {b.nose
        ? side
          ? <path d={`M${15 * b.headRx - 0.6} ${e.y + 1} q2.8 2.8 -0.4 4.8`} fill={skin} stroke={INK} strokeWidth={ow} />
          : <path d={`M0.2 ${e.y + 1.6} L-1.2 ${e.y + 5.2} L0.9 ${e.y + 5.6}`} fill="none" stroke={INK} strokeOpacity={0.7} strokeWidth={ow * 0.8} strokeLinecap="round" />
        : <ellipse cx={side ? 12.5 : 0} cy={e.y + 4.2} rx={1.1} ry={0.8} fill="#000" opacity={0.14} />}
      <Mouth expr={expr} x={mx} y={my} w={side ? w * 0.75 : w} t={t} ow={ow} />
    </g>
  )
}

function Mouth({ expr, x, y, w, t, ow }: { expr: Expression; x: number; y: number; w: number; t: number; ow: number }) {
  const st = { fill: 'none', stroke: INK, strokeWidth: ow * 1.1, strokeLinecap: 'round' as const }
  switch (expr) {
    case 'happy':
      return <path d={`M${x - w} ${y - 0.6} Q${x} ${y + 5.4} ${x + w} ${y - 0.6} Z`} fill={MOUTH} stroke={INK} strokeWidth={ow} strokeLinejoin="round" />
    case 'effort':
      return <g><rect x={x - w * 0.85} y={y - 0.6} width={w * 1.7} height={2.4} rx={1} fill="#f7f4ee" stroke={INK} strokeWidth={ow} /><line x1={x - w * 0.85} y1={y + 0.6} x2={x + w * 0.85} y2={y + 0.6} stroke={INK} strokeWidth={ow * 0.6} /></g>
    case 'determined':
      return <path d={`M${x - w * 0.7} ${y + 0.6} L${x + w * 0.7} ${y}`} {...st} />
    case 'worried':
      return <ellipse cx={x} cy={y + 0.8} rx={w * 0.4} ry={1.5} fill={MOUTH} stroke={INK} strokeWidth={ow} />
    case 'talk': {
      const open = Math.sin(t * 11) > 0
      return <ellipse cx={x} cy={y + 0.6} rx={w * 0.55} ry={open ? 1.9 : 0.6} fill={MOUTH} stroke={INK} strokeWidth={ow} />
    }
    case 'tired':
      return <ellipse cx={x} cy={y + 0.8} rx={w * 0.38} ry={1.1 + 0.4 * Math.sin(t * 4)} fill={MOUTH} stroke={INK} strokeWidth={ow} />
    case 'calm':
      return <path d={`M${x - w * 0.7} ${y} Q${x} ${y + 2} ${x + w * 0.7} ${y}`} {...st} />
    default:
      return <path d={`M${x - w * 0.8} ${y} Q${x} ${y + 1.8} ${x + w * 0.8} ${y}`} {...st} />
  }
}

function Headwear({ hw, c, view, ow, strap }: { hw: Look['headwear']; c: string; view: HeroView; ow: number; strap: string }) {
  const side = view === 'side', front = view === 'front'
  switch (hw) {
    case 'helmet':
      return (
        <g>
          {front && <path d="M-14 -1 Q-13 9 -4 13.5 M14 -1 Q13 9 4 13.5" fill="none" stroke={strap} strokeWidth={1} />}
          {side && <path d="M-6 -2 Q-4 8 4 13" fill="none" stroke={strap} strokeWidth={1} />}
          <path d={side ? 'M-16 -2.5 Q-16 -19.5 1 -19.8 Q17 -19.5 16.6 -3.5 Z' : 'M-16.2 -2.5 Q-16.5 -19.5 0 -19.8 Q16.5 -19.5 16.2 -2.5 Z'} fill={c} stroke={INK} strokeWidth={ow} />
          <path d="M-16.8 -2.5 L16.8 -2.5" stroke={INK} strokeWidth={3.2} strokeLinecap="round" />
          <path d="M-16.8 -2.5 L16.8 -2.5" stroke={c} strokeWidth={1.6} strokeLinecap="round" />
          <g fill="#000" opacity={0.22}><rect x={-6} y={-16} width={2.4} height={4.4} rx={1.2} /><rect x={-1.2} y={-17} width={2.4} height={4.4} rx={1.2} /><rect x={3.6} y={-16} width={2.4} height={4.4} rx={1.2} /></g>
          <path d="M-9 -15.5 Q-4 -18.6 2 -18.4" fill="none" stroke="#fff" strokeOpacity={0.55} strokeWidth={1.8} strokeLinecap="round" />
          <path d="M3 -18 Q12 -16 15.5 -6" fill="none" stroke="#0b1a2a" strokeOpacity={0.18} strokeWidth={3} />
        </g>
      )
    case 'beanie':
      return (
        <g>
          <path d="M-15.8 -3 Q-16 -18.5 0 -18.8 Q16 -18.5 15.8 -3 Z" fill={c} stroke={INK} strokeWidth={ow} />
          <rect x={-16.6} y={-7} width={33.2} height={6.4} rx={3} fill={c} stroke={INK} strokeWidth={ow} />
          <g stroke={INK} strokeOpacity={0.25} strokeWidth={0.7}>{[-11, -5.5, 0, 5.5, 11].map(x => <line key={x} x1={x} y1={-6} x2={x} y2={-1.6} />)}</g>
          <circle cx={side ? -2 : 0} cy={-20.6} r={3.6} fill="#f7f4ee" stroke={INK} strokeWidth={ow} />
        </g>
      )
    case 'sunhat':
      return (
        <g>
          <ellipse cx={0} cy={-4} rx={side ? 22 : 24} ry={side ? 3.6 : 5.2} fill={c} stroke={INK} strokeWidth={ow} />
          <path d="M-11.5 -4 Q-11.5 -18 0 -18 Q11.5 -18 11.5 -4 Z" fill={c} stroke={INK} strokeWidth={ow} />
          <rect x={-11.4} y={-8.4} width={22.8} height={3.2} fill="#a8432a" opacity={0.85} />
        </g>
      )
    case 'headlamp':
      return (
        <g>
          <path d="M-15.6 -7.5 Q0 -12 15.6 -7.5 L15.6 -3.4 Q0 -8 -15.6 -3.4 Z" fill={c} stroke={INK} strokeWidth={ow} />
          {front && <><rect x={-4.6} y={-12} width={9.2} height={7} rx={2} fill="#2a2a2a" stroke={INK} strokeWidth={ow} /><circle cx={0} cy={-8.5} r={2.4} fill="#ffd37a" /></>}
          {side && <><rect x={11} y={-11.5} width={6} height={6.4} rx={1.6} fill="#2a2a2a" stroke={INK} strokeWidth={ow} /><circle cx={16.4} cy={-8.3} r={1.8} fill="#ffd37a" /></>}
        </g>
      )
    case 'cap':
      return (
        <g>
          {side && <path d="M9 -4.6 Q21 -5 23 -1.6 L11 -1.6 Z" fill={c} stroke={INK} strokeWidth={ow} />}
          <path d="M-15.6 -3 Q-16 -18.5 0 -18.8 Q16 -18.5 15.6 -3 Z" fill={c} stroke={INK} strokeWidth={ow} />
          {front && <ellipse cx={0} cy={-2.6} rx={13} ry={3.2} fill={c} stroke={INK} strokeWidth={ow} />}
          <circle cx={0} cy={-18.6} r={1.3} fill={INK} opacity={0.5} />
        </g>
      )
    default:
      return null
  }
}

/* ---------------------------------------------------------------- helpers */

function seg(a: V, b: V, r1: number, r2: number) {
  const dx = b[0] - a[0], dy = b[1] - a[1]
  const L = Math.hypot(dx, dy) || 0.001
  const nx = -dy / L, ny = dx / L
  return `${a[0] + nx * r1},${a[1] + ny * r1} ${b[0] + nx * r2},${b[1] + ny * r2} ${b[0] - nx * r2},${b[1] - ny * r2} ${a[0] - nx * r1},${a[1] - ny * r1}`
}

function lerp(a: V, b: V, k: number): V { return [a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k] }

function scaleTargets(t: Targets, k: number): Targets {
  const o: Targets = {}
  ;(Object.keys(t) as (keyof Targets)[]).forEach(key => { const v = t[key]; if (v) o[key] = [v[0] * k, v[1] * k] })
  return o
}

function packSize(look: Look, b: BuildDef) {
  if (look.pack === 'daypack') return { w: b.chestR * 1.5, h: b.torso * 0.6 }
  if (look.pack === 'expedition') return { w: b.chestR * 1.95, h: b.torso * 0.95 }
  return { w: b.chestR * 1.7, h: b.torso * 0.74 }
}

/* ---------------------------------------------------------------- shared clock (30 fps, one rAF) */

const subs = new Set<(t: number) => void>()
let raf = 0
let lastEmit = 0
function loop(now: number) {
  if (now - lastEmit > 32) {
    lastEmit = now
    const t = now / 1000
    subs.forEach(f => f(t))
  }
  raf = requestAnimationFrame(loop)
}

export function useHeroTime(active: boolean) {
  const [t, setT] = useState(() => (typeof performance !== 'undefined' ? performance.now() / 1000 : 0))
  useEffect(() => {
    if (!active) return
    subs.add(setT)
    if (subs.size === 1) raf = requestAnimationFrame(loop)
    return () => {
      subs.delete(setT)
      if (subs.size === 0) cancelAnimationFrame(raf)
    }
  }, [active])
  return active ? t : 0
}
