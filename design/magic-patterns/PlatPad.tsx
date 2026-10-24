import React, { useEffect, useRef } from 'react'
import { Stick, StickV } from '../Stick'
import { ActionButton } from '../Panels'

export interface PadRefs { stick: React.MutableRefObject<StickV>; hop: React.MutableRefObject<boolean> }

/**
 * The APK's touch layout for a played climb (core/input/touch_controls.gd):
 * a floating stick on the left (push UP on rock to climb), HOP as the big
 * button, ACT for the thing in front of you, REST. `extra` is the stage's
 * own fourth button. Keys: arrows/WASD, Space hop, E act, R rest.
 */
export function PlatPad({ refs, act, onAct, resting, restSub, restDisabled, onRest, extra, onKey, hopSub }: {
  refs: PadRefs
  act: { label: string; sub?: string } | null
  onAct: () => void
  resting: boolean
  restSub: string
  restDisabled: boolean
  onRest: () => void
  extra?: React.ReactNode
  onKey?: (k: string) => void
  hopSub?: string
}) {
  const cb = useRef({ onAct, onRest, onKey })
  cb.current = { onAct, onRest, onKey }
  useEffect(() => {
    const kd = (e: KeyboardEvent) => {
      if (e.repeat) return
      if (e.key === ' ') { e.preventDefault(); refs.hop.current = true }
      else if (e.key === 'e' || e.key === 'Enter') cb.current.onAct()
      else if (e.key === 'r') cb.current.onRest()
      else cb.current.onKey?.(e.key)
    }
    window.addEventListener('keydown', kd)
    return () => window.removeEventListener('keydown', kd)
  }, [refs])
  return (
    <>
      <Stick axis="xy" zoneW={320} zoneH={240} label="Up on rock = climb" onChange={v => { refs.stick.current = v }} />
      <ActionButton x={826} y={338} label="HOP" sub={hopSub} onDown={() => { refs.hop.current = true }} />
      {act && <ActionButton x={728} y={296} size={64} tone="route" label={act.label} sub={act.sub} onClick={onAct} />}
      <ActionButton x={744} y={374} size={56} tone="scrim" label={resting ? 'UP' : 'REST'} sub={restSub} disabled={restDisabled && !resting} onClick={onRest} />
      {extra}
    </>
  )
}
