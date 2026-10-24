import React, { useEffect, useState } from 'react'
import { motion, MotionValue } from 'framer-motion'
import { useGame } from '../state/GameState'
import { Climber, Pose } from '../components/Climber'

/**
 * The player's own climber, warming up on a boulder in the foreground.
 * Loop: climb (8 beats × 400 ms) → top out and celebrate → chalk up and wave → reset.
 * Tapping the climber opens the Profile.
 */
export function BoulderClimber({ x, rm, onTap }: { x: MotionValue<number>; rm: boolean; onTap: () => void }) {
  const { look } = useGame()
  const [step, setStep] = useState(rm ? 12 : 0)

  useEffect(() => {
    if (rm) { setStep(12); return }
    const id = window.setInterval(() => setStep(s => (s + 1) % 18), 400)
    return () => window.clearInterval(id)
  }, [rm])

  const climbing = step < 8
  const onTop = step >= 8 && step < 17
  const pose: Pose = climbing ? (step % 2 ? 'climbB' : 'climbA') : step < 11 ? 'celebrate' : step === 13 || step === 14 ? 'wave' : 'idle'
  const y = climbing ? -step * 11 : onTop ? -112 : 0

  return (
    <motion.div style={{ x }} className="absolute bottom-0 left-[400px] h-[170px] w-[190px]">
      <svg viewBox="0 0 190 170" className="absolute bottom-0 left-0 h-full w-full" aria-hidden>
        <path d="M18 170 Q12 110 40 76 Q62 52 104 50 Q150 50 168 86 Q186 124 178 170 Z" fill="#9c6a45" stroke="#2a1c12" strokeWidth="2" />
        <path d="M104 50 Q150 50 168 86 Q186 124 178 170 L132 170 Q146 120 128 84 Q118 62 104 50 Z" fill="#6f4a31" opacity="0.7" />
        <path d="M44 80 Q70 58 104 56" fill="none" stroke="#e9c49a" strokeWidth="3" strokeLinecap="round" opacity="0.7" />
        {/* chalked holds on the boulder face */}
        {[[78, 140], [96, 118], [74, 100], [100, 82], [86, 66]].map(([cx, cy]) => (
          <ellipse key={`${cx}-${cy}`} cx={cx} cy={cy} rx="7" ry="3.5" fill="#efe6d4" stroke="#2a1c12" strokeWidth="1.2" />
        ))}
        <ellipse cx="96" cy="168" rx="80" ry="6" fill="#000" opacity="0.25" />
      </svg>
      <motion.button
        onClick={onTap}
        aria-label="Your climber — open profile"
        className="absolute bottom-[14px] left-[56px] cursor-pointer"
        animate={{ y, opacity: step === 17 ? 0 : 1 }}
        transition={{ y: { duration: step === 0 ? 0 : climbing ? 0.4 : 0.2, ease: climbing ? 'linear' : [0.23, 1, 0.32, 1] }, opacity: { duration: 0.2 } }}
      >
        <Climber look={look} pose={pose} view={climbing ? 'back' : 'front'} size={64} reducedMotion={rm} className={onTop && !rm ? 'anim-breathe' : ''} />
      </motion.button>
    </motion.div>
  )
}
