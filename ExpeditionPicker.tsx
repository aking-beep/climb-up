import React, { useState } from 'react'
import { Modal } from '../overlays/Modal'
import { EXP_ROUTES } from '../data/kili'
import { PaperButton, PrimaryButton } from '../components/ui'

/** Choose an expedition. Starting a new one over a run in progress asks first (fixes B1). */
export function ExpeditionPicker({ onContinue, onNew, onClose }: { onContinue: () => void; onNew: (name: string, days: number) => void; onClose: () => void }) {
  const [route, setRoute] = useState('machame')
  const [confirm, setConfirm] = useState(false)
  const r = EXP_ROUTES.find(x => x.id === route)!

  if (confirm) {
    return (
      <Modal kicker="New expedition" title="Leave the Lemosho run?" onClose={() => setConfirm(false)} width={460}
        footer={<><PaperButton onClick={() => setConfirm(false)}>Keep my run</PaperButton><PrimaryButton className="flex-1" onClick={() => onNew(r.name, r.days)}>Start {r.name}</PrimaryButton></>}>
        <p className="text-[14px] leading-snug text-ink-soft">Your expedition at <span className="font-semibold text-ink">Day 6, Karanga Camp</span> will end and cannot be continued. Artifacts already brought home stay in your collection.</p>
      </Modal>
    )
  }

  return (
    <Modal kicker="Expedition" title="Kilimanjaro" onClose={onClose} width={600}>
      <button onClick={onContinue} className="flex w-full items-center justify-between rounded-[10px] bg-spruce px-4 py-3 text-left text-spruce-ink transition-[transform] duration-[120ms] ease-out active:scale-[0.98]">
        <span>
          <span className="block text-[12px] text-spruce-ink/75">Continue</span>
          <span className="block font-display text-[19px]">Lemosho · Day 6 · Karanga Camp</span>
        </span>
        <span className="font-display text-[16px]">Resume →</span>
      </button>
      <div className="mt-3 text-[12px] font-semibold text-ember">Or start a new expedition · the route is the difficulty</div>
      <div className="mt-1.5 grid grid-cols-3 gap-2">
        {EXP_ROUTES.map(x => (
          <button key={x.id} onClick={() => setRoute(x.id)} aria-pressed={route === x.id}
            className={`flex flex-col rounded-[8px] border p-2.5 text-left transition-colors duration-150 ${route === x.id ? 'border-spruce bg-spruce/10' : 'border-paper-edge bg-paper-raised hover:border-ink-muted'}`}>
            <span className="flex items-baseline justify-between"><span className="font-display text-[17px] text-ink">{x.name}</span><span className="tabular text-[12px] text-ink-muted">{x.days} days</span></span>
            <span className="text-[12px] font-semibold text-ink-soft">{x.label}</span>
            <span className="mt-1 text-[12px] leading-snug text-ink-muted">{x.text}</span>
          </button>
        ))}
      </div>
      <div className="mt-3 flex justify-end">
        <PaperButton onClick={() => setConfirm(true)}>New {r.name} expedition</PaperButton>
      </div>
    </Modal>
  )
}
