// Math and pose library for the Phase 2 climber rig. Pure functions only:
// the renderer (Hero.tsx) and the Godot handoff both read these numbers.
//
// Angle convention: degrees, 0 = pointing straight down the screen,
// +90 = screen right, 180 = straight up. dir(a) = (sin a, cos a).

export type Build = 'A' | 'B' | 'C'
export type Body = 'm' | 'f'
export type HeroView = 'side' | 'front' | 'back'
export type Expression = 'neutral' | 'happy' | 'effort' | 'worried' | 'talk' | 'calm' | 'tired' | 'determined'
export type HeroPose =
  | 'idle' | 'walk' | 'run' | 'climb' | 'climbA' | 'climbB' | 'reach' | 'mantle' | 'rest'
  | 'fall' | 'celebrate' | 'talk' | 'sit' | 'clip' | 'hang' | 'shake' | 'wave' | 'brace' | 'work' | 'crouch'

export type V = [number, number]
export interface Targets { hL?: V; hR?: V; fL?: V; fR?: V }

export interface BuildDef {
  id: Build
  name: string
  heads: string
  headR: number; neck: number; torso: number; chestR: number; waistR: number
  shoulderW: number; hipW: number
  ua: number; fa: number; th: number; sh: number
  armW: [number, number, number]; legW: [number, number, number]
  handR: number; foot: number; ankle: number
  headRx: number; headRy: number
  eye: { x: number; y: number; rx: number; ry: number; hl: number }
  brow: number
  nose: boolean
  cheek: boolean
}

export const BUILDS: Record<Build, BuildDef> = {
  A: {
    id: 'A', name: 'Trail Storybook', heads: '3.4 heads',
    headR: 15, neck: 3, torso: 27, chestR: 10.5, waistR: 8.5, shoulderW: 9.5, hipW: 5.2,
    ua: 16, fa: 14, th: 19, sh: 18, armW: [4.6, 3.7, 3.1], legW: [6.2, 4.7, 3.7],
    handR: 4.3, foot: 10.5, ankle: 3, headRx: 1, headRy: 0.96,
    eye: { x: 6.2, y: 2.6, rx: 2.15, ry: 2.95, hl: 0.85 }, brow: 1.25, nose: false, cheek: true,
  },
  B: {
    id: 'B', name: 'Bounce & Grin', heads: '2.5 heads',
    headR: 18, neck: 2, torso: 21, chestR: 11.5, waistR: 11, shoulderW: 9, hipW: 6,
    ua: 11.5, fa: 10.5, th: 13, sh: 12, armW: [4.7, 4.2, 3.9], legW: [6.6, 5.7, 5.1],
    handR: 5.7, foot: 13.5, ankle: 4, headRx: 1.04, headRy: 0.94,
    eye: { x: 6.4, y: 2.2, rx: 2.9, ry: 3.9, hl: 1.15 }, brow: 1.9, nose: false, cheek: true,
  },
  C: {
    id: 'C', name: 'Painted Alpinist', heads: '5.6 heads',
    headR: 10.5, neck: 4, torso: 34, chestR: 10, waistR: 7.2, shoulderW: 11, hipW: 6,
    ua: 21, fa: 19, th: 27, sh: 26, armW: [4.1, 3.1, 2.5], legW: [5.8, 4.1, 3.2],
    handR: 3.3, foot: 10.5, ankle: 3, headRx: 0.86, headRy: 1.04,
    eye: { x: 5.1, y: 2.2, rx: 1.95, ry: 1.25, hl: 0.55 }, brow: 1.1, nose: true, cheek: false,
  },
}

/**
 * The female body mirrors the male one on the same rig, clips and kit:
 * narrower shoulders and chest, a defined waist, wider hips, finer hands
 * and feet, slightly larger eyes, softer brows. Same height, same poses.
 */
export function withBody(b: BuildDef, body: Body): BuildDef {
  if (body === 'm') return b
  return {
    ...b,
    shoulderW: b.shoulderW * 0.86, chestR: b.chestR * 0.9, waistR: b.waistR * 0.84, hipW: b.hipW * 1.16,
    armW: [b.armW[0] * 0.86, b.armW[1] * 0.86, b.armW[2] * 0.86],
    legW: [b.legW[0] * 1.04, b.legW[1] * 0.92, b.legW[2] * 0.88],
    handR: b.handR * 0.88, foot: b.foot * 0.92,
    eye: { ...b.eye, ry: b.eye.ry * 1.06, rx: b.eye.rx * 1.04 },
    brow: b.brow * 0.78,
  }
}

/** Every build is drawn at the same standing height, so scale is compared fairly. */
export const STAND_VB = 124
export const GROUND_VB = 146

export function groundY(b: BuildDef) { return b.th + b.sh + b.ankle }
export function standHeight(b: BuildDef) { return groundY(b) + b.torso + b.neck + b.headR * 2 * b.headRy + 2 }
export function buildScale(b: BuildDef) { return STAND_VB / standHeight(b) }
/** Where the hip sits in the 120 × 150 view box when standing. */
export function hipVB(b: BuildDef): V { return [60, GROUND_VB - buildScale(b) * groundY(b)] }

export interface PoseOut {
  lean: number; tilt: number
  uaL: number; faL: number; uaR: number; faR: number
  thL: number; shL: number; thR: number; shR: number
  dx: number; lift: number
  grounded: boolean
  expr: Expression
}

const rad = (d: number) => (d * Math.PI) / 180
const deg = (r: number) => (r * 180) / Math.PI
export const dir = (a: number): V => [Math.sin(rad(a)), Math.cos(rad(a))]
export const add = (p: V, q: V): V => [p[0] + q[0], p[1] + q[1]]
export const mul = (p: V, k: number): V => [p[0] * k, p[1] * k]
const ang = (v: V) => deg(Math.atan2(v[0], v[1]))
const clamp = (v: number, a: number, b: number) => Math.max(a, Math.min(b, v))

/** Fixed joint positions relative to the hip, before limbs. */
export function frame(b: BuildDef, lean: number, view: HeroView) {
  const up: V = [Math.sin(rad(lean)), -Math.cos(rad(lean))]
  const right: V = [Math.cos(rad(lean)), Math.sin(rad(lean))]
  const side = view === 'side'
  const waist = mul(up, b.waistR * 0.35)
  const chest = mul(up, b.torso - b.chestR * 0.9)
  const neckBase = mul(up, b.torso)
  const shoulderMid = add(chest, mul(up, b.chestR * 0.35))
  const sw = side ? 1.2 : b.shoulderW
  const hw = side ? 1 : b.hipW
  return {
    up, right, waist, chest, neckBase,
    sL: add(shoulderMid, mul(right, -sw)), sR: add(shoulderMid, mul(right, sw)),
    hL: mul(right, -hw), hR: mul(right, hw),
  }
}

/** Two-bone IK. Returns absolute [upper, lower] angles; `out` picks the elbow/knee side (-1 left, 1 right). */
export function ik2(S: V, T: V, a: number, b: number, out: number): [number, number] {
  let dx = T[0] - S[0], dy = T[1] - S[1]
  let d = Math.hypot(dx, dy) || 0.001
  const max = a + b - 0.01
  if (d > max) { dx *= max / d; dy *= max / d; d = max }
  const min = Math.abs(a - b) + 0.01
  if (d < min) { dx *= min / d; dy *= min / d; d = min }
  const base = Math.atan2(dx, dy)
  const alpha = Math.acos(clamp((a * a + d * d - b * b) / (2 * a * d), -1, 1))
  const pick = (u: number) => {
    const E: V = [S[0] + a * Math.sin(u), S[1] + a * Math.cos(u)]
    return { u, E }
  }
  const c1 = pick(base + alpha), c2 = pick(base - alpha)
  const c = (c1.E[0] - c2.E[0]) * out >= 0 ? c1 : c2
  const Tc: V = [S[0] + dx, S[1] + dy]
  return [deg(c.u), ang([Tc[0] - c.E[0], Tc[1] - c.E[1]])]
}

const BASE_SIDE: PoseOut = { lean: 3, tilt: 0, uaL: 2, faL: 10, uaR: 6, faR: 16, thL: -2, shL: -3, thR: 2, shR: 0, dx: 0, lift: 0, grounded: true, expr: 'neutral' }
const BASE_FRONT: PoseOut = { lean: 0, tilt: 0, uaL: -9, faL: -4, uaR: 9, faR: 4, thL: -4, shL: -2, thR: 4, shR: 2, dx: 0, lift: 0, grounded: true, expr: 'neutral' }

/** Natural view for each clip when the caller does not choose. */
export const POSE_VIEW: Record<HeroPose, HeroView> = {
  idle: 'front', walk: 'side', run: 'side', climb: 'back', climbA: 'back', climbB: 'back', reach: 'back',
  mantle: 'back', rest: 'side', fall: 'front', celebrate: 'front', talk: 'front', sit: 'side', clip: 'back',
  hang: 'back', shake: 'back', wave: 'front', brace: 'side', work: 'side', crouch: 'side',
}

/** Climbing holds as fractions of reach, used when no live targets are given. */
function wallTargets(b: BuildDef, pose: HeroPose, t: number): Targets {
  const f = frame(b, 0, 'back')
  const a = b.ua + b.fa, l = b.th + b.sh
  const H = (p: V, v: V): V => add(p, mul(v, a))
  const F = (p: V, v: V): V => add(p, mul(v, l))
  const A: Targets = { hL: H(f.sL, [-0.22, -0.93]), hR: H(f.sR, [0.36, -0.55]), fL: F(f.hL, [-0.26, 0.9]), fR: F(f.hR, [0.42, 0.52]) }
  const Bt: Targets = { hL: H(f.sL, [-0.36, -0.55]), hR: H(f.sR, [0.22, -0.93]), fL: F(f.hL, [-0.42, 0.52]), fR: F(f.hR, [0.26, 0.9]) }
  switch (pose) {
    case 'climbA': return A
    case 'climbB': return Bt
    case 'climb': {
      const p = (Math.sin((t / 1.3) * Math.PI * 2) + 1) / 2
      const s = p * p * (3 - 2 * p)
      const mix = (x?: V, y?: V): V => [x![0] + (y![0] - x![0]) * s, x![1] + (y![1] - x![1]) * s]
      return { hL: mix(A.hL, Bt.hL), hR: mix(A.hR, Bt.hR), fL: mix(A.fL, Bt.fL), fR: mix(A.fR, Bt.fR) }
    }
    case 'reach': return { hL: H(f.sL, [-0.12, -0.62]), hR: H(f.sR, [0.3, -0.99]), fL: F(f.hL, [-0.2, 0.96]), fR: F(f.hR, [0.36, 0.74]) }
    case 'clip': return { hL: H(f.sL, [-0.08, -0.97]), hR: [b.waistR * 0.2, -b.torso * 0.32], fL: F(f.hL, [-0.3, 0.86]), fR: F(f.hR, [0.3, 0.86]) }
    case 'hang': return { hL: H(f.sL, [0.26, -0.96]), hR: H(f.sR, [-0.26, -0.96]), fL: F(f.hL, [-0.04, 1]), fR: F(f.hR, [0.08, 0.99]) }
    case 'shake': return { hL: H(f.sL, [0.1, -0.98]), hR: H(f.sR, [0.12 + 0.06 * Math.sin(t * 14), 0.97]), fL: F(f.hL, [-0.3, 0.86]), fR: F(f.hR, [0.32, 0.82]) }
    case 'mantle': {
      const k = (Math.sin(t * 2.2) + 1) / 2
      return { hL: H(f.sL, [-0.1, 0.18]), hR: H(f.sR, [0.1, 0.18]), fL: F(f.hL, [-0.36, 0.22 + 0.08 * k]), fR: F(f.hR, [0.06, 0.98]) }
    }
    default: return A
  }
}

export function isWallPose(p: HeroPose) {
  return p === 'climb' || p === 'climbA' || p === 'climbB' || p === 'reach' || p === 'clip' || p === 'hang' || p === 'shake' || p === 'mantle'
}

/** Pose at time t (seconds). Live targets override the wall library. */
export function computePose(b: BuildDef, pose: HeroPose, view: HeroView, t: number, targets?: Targets, lean?: number): PoseOut {
  const side = view === 'side'
  const base = side ? BASE_SIDE : BASE_FRONT
  const br = Math.sin((t / 2.4) * Math.PI * 2)

  if (isWallPose(pose) || targets) {
    const lib = isWallPose(pose) ? wallTargets(b, pose, t) : {}
    const T = { ...lib, ...targets }
    const L = lean ?? (pose === 'reach' ? 5 : pose === 'mantle' ? -3 : 0)
    const f = frame(b, L, 'back')
    const def = { ...base, lean: L, grounded: false, expr: (pose === 'reach' || pose === 'mantle' ? 'effort' : pose === 'hang' ? 'tired' : 'determined') as Expression }
    if (T.hL) { const [u, v] = ik2(f.sL, T.hL, b.ua, b.fa, -1); def.uaL = u; def.faL = v }
    if (T.hR) { const [u, v] = ik2(f.sR, T.hR, b.ua, b.fa, 1); def.uaR = u; def.faR = v }
    if (T.fL) { const [u, v] = ik2(f.hL, T.fL, b.th, b.sh, -1); def.thL = u; def.shL = v }
    if (T.fR) { const [u, v] = ik2(f.hR, T.fR, b.th, b.sh, 1); def.thR = u; def.shR = v }
    return def
  }

  switch (pose) {
    case 'idle':
      return side
        ? { ...base, uaR: 6 + br * 1.5, faR: 16 + br * 2, uaL: 2 - br, faL: 10 - br, lift: br * 0.4 }
        : { ...base, uaL: -9 - br * 1.2, faL: -4 - br * 1.5, uaR: 9 + br * 1.2, faR: 4 + br * 1.5, lift: br * 0.4, tilt: br * 0.8 }
    case 'walk': {
      const ph = (t / 0.8) * Math.PI * 2
      const leg = (p: number) => { const th = 3 + 24 * Math.sin(p); return [th, th - (6 + 40 * Math.pow(Math.max(0, Math.cos(p)), 1.3))] }
      const [thR, shR] = leg(ph), [thL, shL] = leg(ph + Math.PI)
      const arm = (p: number) => { const u = -20 * Math.sin(p); return [u, u + 14 + 8 * Math.max(0, -Math.sin(p))] }
      const [uaR, faR] = arm(ph), [uaL, faL] = arm(ph + Math.PI)
      return { ...BASE_SIDE, lean: 5, thR, shR, thL, shL, uaR, faR, uaL, faL, tilt: Math.sin(ph * 2) * 1.2 }
    }
    case 'run': {
      const ph = (t / 0.5) * Math.PI * 2
      const leg = (p: number) => { const th = 10 + 42 * Math.sin(p); return [th, th - (18 + 78 * Math.max(0, Math.cos(p)))] }
      const [thR, shR] = leg(ph), [thL, shL] = leg(ph + Math.PI)
      const arm = (p: number) => { const u = -46 * Math.sin(p); return [u, u + 85] }
      const [uaR, faR] = arm(ph), [uaL, faL] = arm(ph + Math.PI)
      return { ...BASE_SIDE, lean: 15, thR, shR, thL, shL, uaR, faR, uaL, faL, lift: 2.5 * Math.max(0, Math.sin(ph * 2)), expr: 'determined' }
    }
    case 'talk': {
      const g = Math.sin(t * 2.1)
      return side
        ? { ...base, uaR: 30 + 12 * g, faR: 100 + 16 * Math.sin(t * 3.1), tilt: 3 * Math.sin(t * 1.3), expr: 'talk' }
        : { ...base, uaR: 24 + 10 * g, faR: 95 + 18 * Math.sin(t * 3.1), uaL: -9 - br, faL: -4, tilt: 3 * Math.sin(t * 1.3), expr: 'talk' }
    }
    case 'sit': {
      const s = side ? 1 : 0
      return side
        ? { ...BASE_SIDE, lean: 8 + br * 1.2, thR: 86, shR: 8, thL: 80, shL: 2, uaR: 34, faR: 80, uaL: 28, faL: 74, expr: 'calm' }
        : { ...BASE_FRONT, thL: -150 * s - 20, shL: -6, thR: 20, shR: 6, expr: 'calm' }
    }
    case 'rest': {
      const hb = Math.sin((t / 1.5) * Math.PI * 2)
      return { ...BASE_SIDE, lean: 38 + hb * 2, thR: 26, shR: -8, thL: 14, shL: -14, uaR: 30, faR: 6, uaL: 24, faL: 2, tilt: -18, expr: 'tired', lift: hb * 0.5 }
    }
    case 'brace':
      return { ...BASE_SIDE, lean: 26, thR: 52, shR: -20, thL: -10, shL: -34, uaR: 60, faR: 20, uaL: 30, faL: 8, tilt: -6, expr: 'determined' }
    case 'work': {
      const w = Math.sin(t * 3.4)
      return { ...BASE_SIDE, lean: 18, thR: 10, shR: -4, thL: -4, shL: -8, uaR: 46 + 10 * w, faR: 92 + 8 * w, uaL: 36 - 6 * w, faL: 86, tilt: 10 }
    }
    case 'crouch': {
      const w = Math.sin(t * 2.6)
      return { ...BASE_SIDE, lean: 30, thR: 100, shR: -20, thL: 60, shL: -60, uaR: 60 + 8 * w, faR: 40 + 10 * w, uaL: 50, faL: 30, tilt: 14 }
    }
    case 'fall': {
      const w = Math.sin(t * 9)
      return { ...BASE_FRONT, lean: -8, uaL: -140 + w * 14, faL: -170 + w * 18, uaR: 145 - w * 14, faR: 175 - w * 16, thL: -22, shL: 6, thR: 30, shR: 60, grounded: false, expr: 'worried' }
    }
    case 'celebrate': {
      const hop = Math.abs(Math.sin((t / 0.7) * Math.PI))
      return side
        ? { ...BASE_SIDE, uaR: 160, faR: 168, uaL: 150, faL: 160, lift: hop * 3, expr: 'happy' }
        : { ...BASE_FRONT, uaL: -148, faL: -166, uaR: 148, faR: 166, thL: -6, thR: 6, lift: hop * 3, expr: 'happy' }
    }
    case 'wave': {
      const w = Math.sin(t * 7)
      return { ...BASE_FRONT, uaR: 140, faR: 170 + w * 18, uaL: -9 - br, lift: br * 0.4, expr: 'happy' }
    }
    default:
      return base
  }
}

const KEYS: (keyof PoseOut)[] = ['lean', 'tilt', 'uaL', 'faL', 'uaR', 'faR', 'thL', 'shL', 'thR', 'shR', 'dx', 'lift']

/** Ease the displayed pose toward the target; k in 0..1. */
export function lerpPose(a: PoseOut, b: PoseOut, k: number): PoseOut {
  const o = { ...b }
  for (const key of KEYS) {
    const av = a[key] as number, bv = b[key] as number
    let d = bv - av
    if (key !== 'dx' && key !== 'lift') { while (d > 180) d -= 360; while (d < -180) d += 360 }
    ;(o[key] as number) = av + d * k
  }
  return o
}
