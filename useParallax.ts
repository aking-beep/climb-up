import React, { useRef } from 'react'
import { MotionValue, useAnimationFrame, useMotionValue, useSpring, useTransform } from 'framer-motion'

/**
 * Layered parallax. On device this is driven by the gyroscope (Input.get_gyroscope)
 * with a slow idle sway; the prototype uses the pointer as a stand-in for tilt.
 * Each layer multiplies the same normalised offset by its depth factor.
 */
export function useParallax(reducedMotion: boolean) {
  const ref = useRef<HTMLDivElement>(null)
  const targetX = useMotionValue(0)
  const targetY = useMotionValue(0)
  const sway = useMotionValue(0)
  const sx = useSpring(targetX, { stiffness: 60, damping: 18 })
  const sy = useSpring(targetY, { stiffness: 60, damping: 18 })
  const combined = useTransform([sx, sway], ([a, b]) => (a as number) + (b as number))

  useAnimationFrame(t => {
    if (reducedMotion) { sway.set(0); return }
    sway.set(Math.sin(t / 5200) * 0.35)
  })

  const onMove = (e: React.PointerEvent) => {
    if (reducedMotion || !ref.current) return
    const r = ref.current.getBoundingClientRect()
    targetX.set(((e.clientX - r.left) / r.width - 0.5) * 2)
    targetY.set(((e.clientY - r.top) / r.height - 0.5) * 2)
  }
  const onLeave = () => { targetX.set(0); targetY.set(0) }

  // eslint-disable-next-line react-hooks/rules-of-hooks
  const x = (k: number): MotionValue<number> => useTransform(combined, v => v * k)
  // eslint-disable-next-line react-hooks/rules-of-hooks
  const y = (k: number): MotionValue<number> => useTransform(sy, v => v * k)

  return { ref, x, y, onMove, onLeave }
}
