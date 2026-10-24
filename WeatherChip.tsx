import React from 'react'
import { Wind, Sun, CloudFog, Snowflake } from 'lucide-react'
import { Weather } from './MapLayer'

const OPTS: { id: Weather; Icon: React.ComponentType<{ size?: number }>; label: string; built: boolean }[] = [
  { id: 'clear', Icon: Sun, label: 'Clear', built: true },
  { id: 'wind', Icon: Wind, label: 'Wind', built: true },
  { id: 'fog', Icon: CloudFog, label: 'Fog', built: false },
  { id: 'snow', Icon: Snowflake, label: 'Snow', built: false },
]

/** Current weather + temperature. Fog and snow are designed, not built: marked as such. */
export function WeatherChip({ weather, set }: { weather: Weather; set: (w: Weather) => void }) {
  const cur = OPTS.find(o => o.id === weather)!
  return (
    <div className="relative flex items-center gap-2 rounded-full bg-scrim py-1 pl-3 pr-1 text-[13px] text-paper ring-1 ring-white/10">
      <span className="tabular whitespace-nowrap">{weather === 'wind' ? '28 km/h' : weather === 'snow' ? '−9 °C' : '−4 °C'}</span>
      <div className="flex">
        {OPTS.map(o => (
          <button key={o.id} onClick={() => set(o.id)} aria-pressed={weather === o.id} aria-label={`${o.label}${o.built ? '' : ' (designed, not built)'}`} title={`${o.label}${o.built ? '' : ' · designed, not built'}`}
            className={`relative grid h-10 w-10 place-items-center rounded-full transition-colors duration-150 ${weather === o.id ? 'bg-paper text-ink' : 'text-paper/80 hover:text-paper'}`}>
            <o.Icon size={17} />
            {!o.built && <span className="absolute right-1 top-1 h-1.5 w-1.5 rounded-full bg-[#7fb3d9]" />}
          </button>
        ))}
      </div>
      {!cur.built && <span className="world-text absolute left-3 top-[52px] whitespace-nowrap text-[12px] text-[#bfe0f5]">{cur.label}: designed state, new in 2.0 · visual only</span>}
    </div>
  )
}
