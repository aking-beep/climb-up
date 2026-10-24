import React from 'react'
import { motion } from 'framer-motion'
import { useGame } from '../state/GameState'
import { useExpedition } from '../state/Expedition'
import { Hero } from '../components/Hero'
import { PaperButton, PrimaryButton, SimTag, Stars } from '../components/ui'
import { CAMPS } from '../data/kili'
import { KILI_PLATE } from '../expedition/MapLayer'

/**
 * Summit → Descent → Scorecard. The descent is the existing Godot level
 * (not redesigned in Phase 2). The scorecard shows the engine's own buckets
 * (ExpeditionEngine.score: judgment, risk management, teamwork, preparation,
 * overall); numbers here are placeholders, never computed by the UI.
 */
export function Scorecard() {
  const g = useGame()
  const x = useExpedition()
  const rm = g.settings.reducedMotion
  const descending = x.ended === 'descent'
  const turned = x.ended === 'turned'
  const high = CAMPS[x.at].meters

  if (descending) {
    return (
      <div className="absolute inset-0 overflow-hidden bg-night">
        <img src={KILI_PLATE} alt="" className="absolute inset-0 h-full w-full object-cover opacity-50" />
        <div className="paper-grain absolute left-1/2 top-1/2 flex w-[520px] -translate-x-1/2 -translate-y-1/2 flex-col rounded-[12px] border border-paper-edge p-5 shadow-[0_16px_40px_rgb(0_0_0/0.45)]">
          <div className="text-[12px] font-medium text-ink-muted">Uhuru → Mweka · existing descent level</div>
          <div className="font-display text-[26px] leading-tight text-ink">The walk down</div>
          <p className="mt-1 text-[14px] leading-snug text-ink-soft">The descent (descent.gd, short-rope Jun) plays here, unchanged. Its outcome lands through finish_descent() and can still end the expedition badly. The summit did not complete anything.</p>
          <div className="mt-4 flex gap-2">
            <SimTag className="self-center">Descent not simulated in this prototype</SimTag>
            <PrimaryButton className="ml-auto" onClick={() => x.finishDescent()}>Skip to the scorecard</PrimaryButton>
          </div>
        </div>
      </div>
    )
  }

  const rows: [string, number][] = [['Judgment', turned ? 78 : 71], ['Risk management', turned ? 72 : 64], ['Teamwork', 68], ['Preparation', 60]]
  return (
    <div className="absolute inset-0 overflow-hidden bg-night">
      <img src={KILI_PLATE} alt="" className="absolute inset-0 h-full w-full object-cover opacity-50" />
      <motion.div initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: rm ? 0 : 0.24, ease: [0.23, 1, 0.32, 1] }}
        className="paper-grain absolute bottom-4 left-7 right-6 top-4 grid grid-cols-[230px_1fr] gap-6 rounded-[12px] border border-paper-edge p-5 shadow-[0_16px_40px_rgb(0_0_0/0.45)]">
        <div className="flex flex-col items-center justify-end rounded-[10px] bg-paper-sunk pb-3">
          <Hero look={g.look} pose={turned ? 'idle' : 'celebrate'} view="front" size={130} kit="trek" reducedMotion={rm} />
          <div className="mt-1 font-display text-[18px] text-ink">{turned ? 'Home, by choice' : 'Home safely'}</div>
          <div className="text-[12px] text-ink-muted">{x.summit ? 'Summit reached · returned safely' : `Highest point ${high.toLocaleString()} m`}</div>
        </div>
        <div className="flex min-h-0 flex-col">
          <div className="flex items-center justify-between">
            <div>
              <div className="text-[12px] font-medium text-ink-muted">Expedition scorecard · {x.routeName} · {x.day} days</div>
              <div className="font-display text-[30px] leading-tight text-ink">{turned ? 'You turned around in time.' : 'Up, and back down.'}</div>
            </div>
            <SimTag>Engine values in Godot</SimTag>
          </div>
          <p className="mt-1 text-[14px] text-ink-soft">How high you climb isn't how you win. The engine scores the decisions, not the photograph.</p>
          <div className="mt-4 grid grid-cols-[1fr_auto] items-center gap-x-6 gap-y-3">
            {rows.map(([k, v], i) => (
              <React.Fragment key={k}>
                <div>
                  <div className="flex justify-between text-[13px]"><span className="font-medium text-ink">{k}</span><span className="tabular font-semibold">{v}</span></div>
                  <div className="mt-1 h-[6px] overflow-hidden rounded-full bg-ink/10"><motion.div className="h-full rounded-full bg-spruce" initial={{ width: 0 }} animate={{ width: `${v}%` }} transition={{ delay: rm ? 0 : 0.1 + i * 0.05, duration: rm ? 0 : 0.24, ease: [0.23, 1, 0.32, 1] }} /></div>
                </div>
                <span />
              </React.Fragment>
            ))}
          </div>
          <div className="mt-4 grid grid-cols-3 gap-3 border-t border-paper-edge pt-3 text-[13px]">
            {(['barranco-wall', 'karanga-ridge', 'summit-approach'] as const).map(id => (
              <div key={id}>
                <div className="text-ink-muted">{id === 'barranco-wall' ? 'Barranco Wall' : id === 'karanga-ridge' ? 'Karanga Ridge*' : 'Summit approach'}</div>
                <Stars n={x.climbs[id].stars} />
              </div>
            ))}
          </div>
          <div className="mt-auto flex gap-2">
            <PaperButton onClick={() => g.go('hub')}>Adventure Hub</PaperButton>
            <PrimaryButton className="flex-1" onClick={() => { x.jump('karanga'); g.go('expedition') }}>Replay from Karanga (prototype)</PrimaryButton>
          </div>
        </div>
      </motion.div>
    </div>
  )
}
