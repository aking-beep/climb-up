import React from 'react'
import { motion } from 'framer-motion'
import { useGame } from '../state/GameState'
import { Climber, Pose } from '../components/Climber'
import { Bolt, HoldShape } from '../components/Icons'
import { ClimbSim, PX } from './useClimbSim'
import { CRAG_PLATE } from '../screens/CragSelect'

export const WALL_TEXTURE = 'https://cdn.magicpatterns.com/patterns/generated-images/cc7e2eef-eacd-4451-85f8-0d4bc5bbae6b.jpg'
const CX = 400
const CAMERA_Y = 228

/** The playfield: far valley (blurred, slow), the wall, holds, bolts, rope, climber. */
export function ClimbWorld({ s, highBolt }: { s: ClimbSim; highBolt: number }) {
  const { look, settings } = useGame()
  const rm = settings.reducedMotion
  const H = (s.top + 7) * PX
  const wy = (m: number) => H - 30 - m * PX
  const { sim } = s
  const bodyM = s.handY - sim.bodyOffset
  const camY = CAMERA_Y - wy(bodyM - 0.6)
  const climberX = CX + s.hold.x * 0.55 - 35
  const climberTop = wy(bodyM) - 13
  const harness = { x: climberX + 35, y: climberTop + 52 }

  const pose: Pose =
    sim.mode === 'complete' ? 'celebrate'
      : sim.mode === 'fall' || sim.mode === 'lesson' ? 'fall'
        : sim.mode === 'reach' ? 'reach'
          : sim.mode === 'clip' ? 'clip'
            : sim.mode === 'rest' ? 'hang'
              : s.onGood && sim.stamina < 95 ? 'rest'
                : sim.flip ? 'climbB' : 'climbA'

  // rope: harness → last clipped bolt → down through the clipped draws → belayer
  const clipped = s.bolts.filter(b => s.isClipped(b.i))
  const anchorPt = { x: CX, y: wy(s.top + 1.3) + 22 }
  const ropePts = [harness, ...(sim.anchored ? [anchorPt] : []), ...[...clipped].reverse().map(b => ({ x: CX + b.x, y: wy(b.y) + 18 })), { x: CX + 20, y: H }]
  const ropeD = ropePts.map((p, i) => `${i ? 'L' : 'M'}${p.x} ${p.y}`).join(' ')
  const slack = sim.mode === 'fall' || sim.mode === 'lesson' || sim.mode === 'rest' ? 0 : 6
  const ropeCurve = ropePts.length > 1
    ? `M${harness.x} ${harness.y} Q${(harness.x + ropePts[1].x) / 2 + slack * 3} ${(harness.y + ropePts[1].y) / 2 + slack} ${ropePts[1].x} ${ropePts[1].y} ` + ropeD.split(' L').slice(2).map(p => `L${p}`).join(' ')
    : ropeD
  const reachTarget = sim.mode === 'reach' || sim.mode === 'climb' ? s.holds[Math.min(sim.idx + 1, s.holds.length - 1)] : null
  const hpBolt = highBolt > 0 ? s.bolts[highBolt - 1] : null

  return (
    <div className="absolute inset-0 overflow-hidden bg-[#2b2219]">
      {/* far layer: the valley plate, defocused, moving at 15% of the camera */}
      <motion.img
        src={CRAG_PLATE}
        alt=""
        draggable={false}
        className="absolute left-0 top-[-60px] h-[560px] w-[1000px] max-w-none object-cover blur-[3px] brightness-[0.82]"
        animate={{ y: Math.min(0, camY * 0.15 + 40) }}
        transition={{ duration: rm ? 0 : 0.3, ease: [0.23, 1, 0.32, 1] }}
      />
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(55%_80%_at_12%_0%,rgb(255_214_160/0.25),transparent_70%)]" />

      <motion.div
        className="absolute left-0 top-0 w-[915px]"
        style={{ height: H }}
        animate={{ y: camY }}
        transition={{ duration: rm ? 0 : sim.mode === 'fall' ? 0.55 : 0.28, ease: sim.mode === 'fall' ? [0.65, 0, 0.35, 1] : [0.23, 1, 0.32, 1] }}
      >
        <svg width="915" height={H} className="absolute left-0 top-0" aria-hidden>
          <defs>
            <pattern id="wall-tex" patternUnits="userSpaceOnUse" width="460" height="818">
              <image href={WALL_TEXTURE} width="460" height="818" preserveAspectRatio="xMidYMid slice" />
            </pattern>
          </defs>
          {/* wall column with a natural edge; the cool shadow side reads as depth */}
          <path d={`M210 0 L612 0 Q640 ${H * 0.2} 618 ${H * 0.4} Q600 ${H * 0.6} 632 ${H * 0.8} L624 ${H} L196 ${H} Q176 ${H * 0.7} 200 ${H * 0.5} Q220 ${H * 0.3} 210 0 Z`} fill="url(#wall-tex)" />
          <path d={`M560 0 L612 0 Q640 ${H * 0.2} 618 ${H * 0.4} Q600 ${H * 0.6} 632 ${H * 0.8} L624 ${H} L590 ${H} Z`} fill="#20304a" opacity="0.28" />
          <path d={`M210 0 L612 0 Q640 ${H * 0.2} 618 ${H * 0.4} Q600 ${H * 0.6} 632 ${H * 0.8} L624 ${H} L196 ${H} Q176 ${H * 0.7} 200 ${H * 0.5} Q220 ${H * 0.3} 210 0 Z`} fill="none" stroke="#1c1915" strokeOpacity="0.5" strokeWidth="3" />
          {/* ground */}
          <rect x="0" y={H - 30} width="915" height="30" fill="#4a3a26" />
          <path d={`M0 ${H - 30} Q200 ${H - 42} 420 ${H - 30} T915 ${H - 34} V${H} H0 Z`} fill="#5f6b44" />

          {/* previous high point, chalked on the rock */}
          {hpBolt && sim.clips < highBolt && (
            <g transform={`translate(${CX + 60} ${wy(hpBolt.y)})`}>
              <line x1="-26" y1="0" x2="26" y2="0" stroke="#f7f4ee" strokeWidth="3" strokeLinecap="round" opacity="0.85" />
              <text x="32" y="4" fill="#f7f4ee" fontSize="12" fontFamily="Outfit" fontWeight="600" className="world-text">Your high point</text>
            </g>
          )}

          {/* holds */}
          {s.holds.map(h => (
            <HoldShape key={h.i} type={h.type} x={CX + h.x} y={wy(h.y)} s={1.15} />
          ))}
          {reachTarget && sim.mode === 'reach' && (
            <circle cx={CX + reachTarget.x} cy={wy(reachTarget.y)} r="20" fill="none" stroke="#f7f4ee" strokeWidth="2.5" strokeDasharray="5 4" />
          )}

          {/* anchor */}
          <g transform={`translate(${CX} ${wy(s.top + 1.3)})`}>
            <circle cx="-10" cy="0" r="5" fill="#cfd5da" stroke="#1c1915" strokeWidth="1.4" />
            <circle cx="10" cy="0" r="5" fill="#cfd5da" stroke="#1c1915" strokeWidth="1.4" />
            <path d="M-10 4 L0 18 L10 4" fill="none" stroke="#cfd5da" strokeWidth="2.5" />
            <circle cx="0" cy="22" r="5" fill="none" stroke={sim.anchored ? look.rope : '#cfd5da'} strokeWidth="2.5" />
            {s.atChains && sim.mode === 'climb' && (
              <circle cx="0" cy="12" r="24" fill="none" stroke="#f7f4ee" strokeWidth="2.5" strokeDasharray="5 4" />
            )}
          </g>

          {/* bolts */}
          {s.bolts.map(b => (
            <Bolt key={b.i} x={CX + b.x} y={wy(b.y)} clipped={s.isClipped(b.i)} rope={look.rope} next={s.canClip && b.i === sim.clips && sim.mode === 'climb'} />
          ))}

          {/* rope */}
          <path d={ropeCurve} fill="none" stroke="#1c1915" strokeWidth="5" strokeLinecap="round" strokeLinejoin="round" opacity="0.6" />
          <path d={ropeCurve} fill="none" stroke={look.rope} strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" />
        </svg>

        <motion.div
          className="absolute"
          animate={{ left: climberX, top: climberTop, rotate: sim.mode === 'fall' ? -8 : 0 }}
          transition={{ duration: rm ? 0 : sim.mode === 'fall' ? 0.55 : 0.22, ease: sim.mode === 'fall' ? [0.55, 0, 0.75, 0.3] : [0.23, 1, 0.32, 1] }}
        >
          <Climber look={look} pose={pose} view={sim.mode === 'complete' ? 'front' : 'back'} size={70} reducedMotion={rm} />
        </motion.div>
      </motion.div>
    </div>
  )
}
