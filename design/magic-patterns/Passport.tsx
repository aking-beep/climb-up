import React from 'react'
import { NewDataTag } from '../components/ui'

/** World Passport: places stamped across both modes (exists today with 2 places). */
export function Passport() {
  return (
    <div>
      <p className="text-[13px] text-ink-soft">Every place you climb gets a stamp. The global passport board needs places on two continents; both of yours are in Africa.</p>
      <div className="mt-3 grid grid-cols-4 gap-3">
        <Stamp shape="round" color="#a8432a" place="Lion Rock" line="Crag · first send" date="12 MAR" />
        <Stamp shape="rect" color="#1f3d34" place="Kilimanjaro" line="Uhuru Peak · 5,895 m" date="03 APR" />
        <Empty place="A second crag" note="Proposed · crack or slab" />
        <Empty place="Everest" note="Content exists in the Expo build; not in Godot" />
      </div>
      <div className="mt-4 flex items-center justify-between border-t border-paper-edge pt-3 text-[13px]">
        <span className="text-ink-muted">Continents</span>
        <span className="font-medium text-ink">Africa · 1 of 2 needed</span>
      </div>
      <div className="mt-1 flex items-center justify-between text-[13px]">
        <span className="text-ink-muted">Stamp dates</span>
        <NewDataTag />
      </div>
    </div>
  )
}

function Stamp({ shape, color, place, line, date }: { shape: 'round' | 'rect'; color: string; place: string; line: string; date: string }) {
  return (
    <div className="flex flex-col items-center text-center">
      <div
        className={`grid h-[112px] w-[112px] place-items-center border-[3px] ${shape === 'round' ? 'rounded-full' : 'rounded-[10px] rotate-[-4deg]'}`}
        style={{ borderColor: color, color }}
      >
        <div className={`grid h-[94px] w-[94px] place-items-center border border-dashed ${shape === 'round' ? 'rounded-full' : 'rounded-[6px]'}`} style={{ borderColor: color }}>
          <div>
            <div className="text-[11px] font-semibold">{date}</div>
            <div className="font-display text-[16px] leading-tight">{place}</div>
          </div>
        </div>
      </div>
      <div className="mt-1.5 text-[12px] text-ink-muted">{line}</div>
    </div>
  )
}

function Empty({ place, note }: { place: string; note: string }) {
  return (
    <div className="flex flex-col items-center text-center">
      <div className="grid h-[112px] w-[112px] place-items-center rounded-full border-2 border-dashed border-paper-edge text-ink-muted">
        <div className="font-display text-[15px] leading-tight">{place}</div>
      </div>
      <div className="mt-1.5 text-[12px] leading-snug text-ink-muted">{note}</div>
    </div>
  )
}
