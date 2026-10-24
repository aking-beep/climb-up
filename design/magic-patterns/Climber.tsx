import React from 'react'
import { Look } from '../data/cosmetics'
import { Hero, HeroPose } from './Hero'

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

const MAP: Record<Pose, HeroPose> = {
  idle: 'idle', climbA: 'climbA', climbB: 'climbB', reach: 'reach', clip: 'clip',
  rest: 'shake', fall: 'fall', celebrate: 'celebrate', hang: 'hang', wave: 'wave',
}

/**
 * Phase 1 API, Phase 2 body. Every existing screen (hub, crag, profile,
 * customize) now draws the new articulated climber through this adapter.
 * The Phase 1 figure is kept as ClimberV1 for side-by-side reference only.
 */
export function Climber({ look, pose = 'idle', view = 'front', size = 120, reducedMotion, className, style }: Props) {
  return (
    <Hero
      look={look}
      pose={MAP[pose]}
      view={view}
      size={size}
      reducedMotion={reducedMotion}
      className={className?.replace('anim-breathe', '')}
      style={style}
    />
  )
}
