import React from 'react'
import { Route } from '../data/routes'
import { Modal } from '../overlays/Modal'
import { PaperButton, PrimaryButton } from '../components/ui'

/** Same choices as crag_level.gd pause_menu(); Settings is now the shared sheet. */
export function PauseMenu({ route, onResume, onSettings, onLower }: { route: Route; onResume: () => void; onSettings: () => void; onLower: () => void }) {
  return (
    <Modal
      kicker="Paused"
      title={route.name}
      onClose={onResume}
      width={440}
      footer={
        <>
          <PaperButton onClick={onLower}>Lower off</PaperButton>
          <PrimaryButton className="flex-1" onClick={onResume}>Resume</PrimaryButton>
        </>
      }
    >
      <p className="text-[14px] leading-snug text-ink-soft">Lowering off ends this go. Your high point is kept, and the route will still be here.</p>
      <div className="mt-3 grid grid-cols-2 gap-2">
        <PaperButton onClick={onResume}>Look at the route</PaperButton>
        <PaperButton onClick={onSettings}>Settings</PaperButton>
      </div>
    </Modal>
  )
}
