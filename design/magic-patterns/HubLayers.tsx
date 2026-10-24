import React from 'react'
import { motion, MotionValue } from 'framer-motion'

/** Slow cloud band over the far plate (weather layer; static under reduced motion). */
export function CloudBand({ rm }: { rm: boolean }) {
  return (
    <div className={`pointer-events-none absolute left-0 top-[30%] h-[22%] w-full ${rm ? '' : 'anim-drift-slow'}`}>
      <svg viewBox="0 0 971 90" className="h-full w-full" preserveAspectRatio="none" aria-hidden>
        <g fill="#fbf3e6" opacity="0.55">
          <path d="M60 60 Q90 30 130 44 Q160 20 200 40 Q240 34 250 58 Z" />
          <path d="M420 70 Q450 44 490 54 Q520 34 560 50 Q600 46 610 72 Z" />
          <path d="M780 52 Q805 30 840 40 Q870 22 905 40 Q935 40 940 60 Z" />
        </g>
      </svg>
    </div>
  )
}

/** Mid ridge in haze: separates the far plate from the playable foreground. */
export function HubMidground({ x }: { x: MotionValue<number> }) {
  return (
    <motion.div style={{ x }} className="pointer-events-none absolute bottom-0 left-[-40px] h-[180px] w-[1000px]">
      <svg viewBox="0 0 1000 180" className="h-full w-full" preserveAspectRatio="none" aria-hidden>
        <path d="M0 120 Q120 92 240 108 T470 100 Q560 84 650 104 T860 96 Q930 90 1000 104 V180 H0 Z" fill="#7d8a5e" opacity="0.55" />
        <path d="M0 150 Q160 124 300 138 T560 132 Q700 118 820 136 T1000 128 V180 H0 Z" fill="#5f6b44" opacity="0.8" />
      </svg>
    </motion.div>
  )
}

/** Foreground grass and rock, darker and softened: the tilt-shift edge of the diorama. */
export function HubForeground({ x }: { x: MotionValue<number> }) {
  return (
    <motion.div style={{ x }} className="pointer-events-none absolute bottom-[-6px] left-[-50px] h-[90px] w-[1020px]">
      <svg viewBox="0 0 1020 90" className="h-full w-full blur-[1.2px]" preserveAspectRatio="none" aria-hidden>
        <path d="M0 90 V50 Q30 30 60 46 Q80 20 110 40 Q130 26 150 48 Q170 60 190 90 Z" fill="#2f3320" />
        <path d="M860 90 Q880 50 910 48 Q930 24 960 40 Q990 30 1020 44 V90 Z" fill="#2f3320" />
        <g stroke="#3e4428" strokeWidth="3" strokeLinecap="round">
          {Array.from({ length: 18 }).map((_, i) => (
            <line key={i} x1={20 + i * 9} y1="90" x2={14 + i * 9 + (i % 3) * 4} y2={44 + (i % 4) * 8} />
          ))}
          {Array.from({ length: 16 }).map((_, i) => (
            <line key={`r${i}`} x1={870 + i * 9} y1="90" x2={876 + i * 9 - (i % 3) * 4} y2={42 + (i % 4) * 8} />
          ))}
        </g>
      </svg>
    </motion.div>
  )
}
