import React, { useLayoutEffect, useRef, useState } from 'react'

export const DEVICE_W = 915
export const DEVICE_H = 412

/** A 20:9 Android phone held landscape (915 × 412 dp), scaled to fit. */
export function DeviceFrame({ children }: { children: React.ReactNode }) {
  const host = useRef<HTMLDivElement>(null)
  const [scale, setScale] = useState(1)

  useLayoutEffect(() => {
    const el = host.current
    if (!el) return
    const fit = () => {
      const r = el.getBoundingClientRect()
      const s = Math.min((r.width - 28) / DEVICE_W, (r.height - 28) / DEVICE_H)
      setScale(Math.max(0.3, s))
    }
    fit()
    const ro = new ResizeObserver(fit)
    ro.observe(el)
    return () => ro.disconnect()
  }, [])

  return (
    <div ref={host} className="w-full h-full flex items-center justify-center">
      <div
        style={{ width: (DEVICE_W + 28) * scale, height: (DEVICE_H + 28) * scale }}
        className="relative shrink-0"
      >
        <div
          style={{ width: DEVICE_W + 28, height: DEVICE_H + 28, transform: `scale(${scale})`, transformOrigin: '0 0' }}
          className="absolute left-0 top-0 rounded-[44px] bg-[#0c0b0a] p-[14px] shadow-[0_30px_80px_rgb(0_0_0/0.55)] ring-1 ring-white/10"
        >
          <div className="relative w-[915px] h-[412px] rounded-[32px] overflow-hidden bg-night select-none">
            {children}
            {/* punch-hole camera: keep 24 dp clear on this edge */}
            <div className="pointer-events-none absolute left-[11px] top-1/2 -translate-y-1/2 w-[10px] h-[10px] rounded-full bg-black ring-2 ring-white/5 z-[100]" />
          </div>
        </div>
      </div>
    </div>
  )
}
