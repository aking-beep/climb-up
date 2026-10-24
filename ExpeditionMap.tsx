import React, { useEffect, useState } from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import { Tent } from 'lucide-react'
import { useGame } from '../state/GameState'
import { useExpedition } from '../state/Expedition'
import { BackButton, PrimaryButton, SimTag, PaperButton } from '../components/ui'
import { CAMPS, Choice } from '../data/kili'
import { MapLayer } from '../expedition/MapLayer'
import { PartyPanel } from '../expedition/PartyPanel'
import { DecisionCard } from '../expedition/DecisionCard'
import { PackStrip } from '../expedition/PackStrip'
import { SummitCard } from '../expedition/SummitCard'
import { WeatherChip } from '../expedition/WeatherChip'
import { ExpeditionPicker } from '../expedition/ExpeditionPicker'
import { Modal } from '../overlays/Modal'
import { SpecNote } from '../components/SpecNote'

/**
 * Screen 6 — the trek map is the hub of a run. Phase 2 adds two doors off it:
 * "Enter camp" (optional exploration) and the played climbs (diamonds, or a
 * card choice that launches one). The engine's card flow is unchanged.
 */
export function ExpeditionMap() {
  const g = useGame()
  const x = useExpedition()
  const [cardOpen, setCardOpen] = useState(g.intent === 'open-decision')
  const [preview, setPreview] = useState<Choice | null>(null)
  const [picker, setPicker] = useState(g.intent === 'pick-expedition')
  const [retreat, setRetreat] = useState<Choice | null>(null)

  useEffect(() => {
    if (g.intent === 'pick-expedition') setPicker(true)
    if (g.intent === 'open-decision') setCardOpen(true)
  }, [g.intent, x.at])

  const confirm = (c: Choice) => {
    if (c.move === 'retreat') { setRetreat(c); return }
    setPreview(null); setCardOpen(false)
    x.apply(c)
  }

  const camp = CAMPS[x.at]
  const canCamp = x.at > 0 && x.at < CAMPS.length - 1

  return (
    <div className="absolute inset-0 overflow-hidden bg-[#3b4a3a]">
      <MapLayer at={x.at} weather={x.weather} rm={g.settings.reducedMotion} onCamp={i => { if (i === x.at && x.event) setCardOpen(true) }} onPlay={id => (x.climbs[id].done ? x.launch(id, null) : x.play(id))} />

      <div className="absolute left-7 top-4 flex items-center gap-3">
        <BackButton dark label="Hub" onClick={() => g.go('hub')} />
        <div className="world-text text-paper">
          <div className="font-display text-[22px] leading-none">Kilimanjaro · {x.routeName}</div>
          <div className="tabular mt-1 text-[13px] text-paper/85">Day {x.day} of {x.days} · {camp.name} · {camp.meters.toLocaleString()} m</div>
        </div>
      </div>

      <div className="absolute left-[400px] top-5"><WeatherChip weather={x.weather} set={x.setWeather} /></div>
      <div className="absolute right-6 top-4"><SummitCard at={x.at} /></div>

      <div className="absolute bottom-4 left-7 top-[76px] w-[212px]"><PartyPanel stats={x.stats} preview={preview} /></div>

      <div className="absolute bottom-4 left-[256px]"><PackStrip /></div>

      <AnimatePresence>
        {cardOpen && x.event ? (
          <DecisionCard key={x.event.id} camp={camp} event={x.event} preview={preview} setPreview={setPreview} onConfirm={confirm} onClose={() => { setCardOpen(false); setPreview(null) }} rm={g.settings.reducedMotion} />
        ) : (
          <motion.div key="cta" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="absolute bottom-4 right-6 flex items-center gap-2">
            {canCamp && (
              <PaperButton size="lg" onClick={() => g.go('camp')}><Tent size={18} /> Enter camp</PaperButton>
            )}
            {x.event ? (
              <PrimaryButton size="lg" onClick={() => setCardOpen(true)}>Today at {camp.name.replace(' Camp', '')}</PrimaryButton>
            ) : (
              <PrimaryButton size="lg" onClick={() => x.jump('karanga')}>Make camp</PrimaryButton>
            )}
          </motion.div>
        )}
      </AnimatePresence>

      <AnimatePresence>
        {x.toast && (
          <motion.div initial={{ opacity: 0, y: -4 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} transition={{ duration: 0.18 }}
            className="absolute left-1/2 top-[76px] max-w-[440px] -translate-x-1/2 rounded-[8px] bg-scrim px-4 py-2 text-center text-[13px] text-paper ring-1 ring-white/15">
            {x.toast}
          </motion.div>
        )}
      </AnimatePresence>

      <AnimatePresence>
        {picker && <ExpeditionPicker onContinue={() => setPicker(false)} onNew={(n, d) => { x.startNew(n, d); setPicker(false); g.go('prep') }} onClose={() => setPicker(false)} />}
        {retreat && (
          <Modal kicker="Turn around" title="Walk out from here?" onClose={() => setRetreat(null)} width={440}
            footer={<><PaperButton onClick={() => setRetreat(null)}>Not yet</PaperButton><PrimaryButton className="flex-1" onClick={() => { const c = retreat; setRetreat(null); setCardOpen(false); x.apply(c) }}>Turn around</PrimaryButton></>}>
            <p className="text-[14px] leading-snug text-ink-soft">{retreat.detail} Turning around while the way down still exists is scored as judgment, not failure.</p>
          </Modal>
        )}
      </AnimatePresence>

      <div className="pointer-events-none absolute bottom-[70px] left-[256px]"><SimTag className="!bg-paper/90">Simulated run · engine untouched</SimTag></div>

      {g.settings.showSpecs && (
        <>
          <SpecNote x={250} y={130} w={200}>Map pans by drag; camera recentres on the party after a move (280 ms)</SpecNote>
          <SpecNote x={560} y={300} w={190}>Enter camp is optional; the decision stays one tap away on the map and in camp</SpecNote>
        </>
      )}
    </div>
  )
}
