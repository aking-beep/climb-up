import React, { useState } from 'react'
import { WifiOff } from 'lucide-react'
import { useGame } from '../state/GameState'
import { Modal } from './Modal'
import { ROUTES, STYLE_LABEL, fmtTime } from '../data/routes'
import { SimTag } from '../components/ui'

type Board = 'crag' | 'expedition' | 'passport'
type Scope = 'personal' | 'friends' | 'global'

/** Records with in-place tabs (fixes B4: no scene reload per tap). */
export function RecordsSheet() {
  const g = useGame()
  const [board, setBoard] = useState<Board>('crag')
  const [scope, setScope] = useState<Scope>('personal')

  return (
    <Modal kicker="Records" title="Your climbing record" onClose={() => g.setOverlay(null)} width={600}>
      <div className="flex items-center justify-between">
        <Segmented value={board} set={v => setBoard(v as Board)} items={[['crag', 'Crag'], ['expedition', 'Expedition'], ['passport', 'Passport']]} />
        <Segmented value={scope} set={v => setScope(v as Scope)} items={[['personal', 'Personal'], ['friends', 'Friends'], ['global', 'Global']]} small />
      </div>

      {scope !== 'personal' ? (
        <div className="mt-4 flex items-start gap-3 rounded-[8px] bg-paper-sunk p-4">
          <WifiOff size={22} className="mt-0.5 shrink-0 text-ink-muted" />
          <div>
            <div className="font-display text-[17px] text-ink">Not connected</div>
            <p className="mt-0.5 text-[13px] leading-snug text-ink-soft">Friends and global boards open when the records service is switched on. Your goes are saved on this phone and will be sent then.</p>
          </div>
        </div>
      ) : board === 'crag' ? (
        <table className="mt-3 w-full text-left text-[13px]">
          <thead className="text-[11px] text-ink-muted">
            <tr className="border-b border-paper-edge"><th className="py-1.5 font-medium">Route</th><th className="font-medium">Best ascent</th><th className="font-medium">Best time</th><th className="text-right font-medium">Goes</th></tr>
          </thead>
          <tbody>
            {ROUTES.map(r => {
              const p = g.progress[r.id]
              return (
                <tr key={r.id} className="border-b border-paper-edge/60">
                  <td className="py-1.5"><span className="mr-2 inline-block w-9 font-display text-ink">{r.grade === 'Lesson' ? 'L' : r.grade}</span>{r.name}</td>
                  <td className={p?.sends ? 'text-ink' : 'text-ink-muted'}>{p?.sends ? STYLE_LABEL[p.best] : p?.attempts ? `High point bolt ${p.highBolt}` : '—'}</td>
                  <td className="tabular">{p?.sends ? fmtTime(p.bestSeconds) : '—'}</td>
                  <td className="tabular text-right">{p?.attempts ?? 0}</td>
                </tr>
              )
            })}
          </tbody>
        </table>
      ) : board === 'expedition' ? (
        <table className="mt-3 w-full text-left text-[13px]">
          <thead className="text-[11px] text-ink-muted"><tr className="border-b border-paper-edge"><th className="py-1.5 font-medium">Expedition</th><th className="font-medium">Ending</th><th className="font-medium">Leader points</th><th className="text-right font-medium">Days</th></tr></thead>
          <tbody>
            <tr className="border-b border-paper-edge/60"><td className="py-1.5">Kilimanjaro · Machame</td><td>Summit, all four home</td><td className="tabular">412</td><td className="tabular text-right">9</td></tr>
            <tr className="border-b border-paper-edge/60"><td className="py-1.5">Kilimanjaro · Lemosho</td><td className="text-ink-muted">In progress · Day 6</td><td className="tabular text-ink-muted">—</td><td className="tabular text-right text-ink-muted">6</td></tr>
          </tbody>
        </table>
      ) : (
        <div className="mt-3 text-[13px] text-ink-soft">2 places stamped: Lion Rock (Crag) and Kilimanjaro (Expedition), both in Africa. The global passport board needs places on two continents.</div>
      )}
      <div className="mt-3"><SimTag>Sample records</SimTag></div>
    </Modal>
  )
}

function Segmented({ value, set, items, small }: { value: string; set: (v: string) => void; items: [string, string][]; small?: boolean }) {
  return (
    <div className="flex rounded-full bg-paper-sunk p-1">
      {items.map(([k, l]) => (
        <button key={k} onClick={() => set(k)} aria-pressed={value === k}
          className={`rounded-full px-3 ${small ? 'h-9 text-[13px]' : 'h-10 text-[14px]'} font-medium transition-colors duration-150 ${value === k ? 'bg-spruce text-spruce-ink' : 'text-ink-soft hover:text-ink'}`}>
          {l}
        </button>
      ))}
    </div>
  )
}
