import React, { useState } from 'react'
import { motion } from 'framer-motion'
import { X, Check } from 'lucide-react'
import { Hero } from '../components/Hero'
import { Look } from '../data/cosmetics'
import { CAMPS, PACK, PARTY, STATS, ENCOUNTERS } from '../data/kili'
import { Meter, PaperButton, PrimaryButton, SimTag, Chip } from '../components/ui'
import { MechanicTag } from '../encounter/Panels'
import { Npc, VIEWPOINT_IMG } from './campData'
import type { CampPhase } from '../state/Expedition'
import { useExpedition } from '../state/Expedition'

const EASE = [0.23, 1, 0.32, 1] as [number, number, number, number]

/** Bottom dialogue sheet: NPC bust left, player bust right, one line at a time, topics as choices. */
export function DialoguePanel({ npc, phase, you, onClose, onEngine, onDecision, rm }: { key?: React.Key; 
  npc: Npc; phase: CampPhase; you: Look; onClose: () => void; onEngine: (text: string) => void; onDecision: () => void; rm: boolean
}) {
  const [topic, setTopic] = useState<number | null>(null)
  const [line, setLine] = useState(0)
  const t = topic === null ? null : npc.topics[topic]
  const text = t ? t.a[line] : npc.greet[phase]
  const asking = t !== null && line === 0
  return (
    <motion.div initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: 12 }} transition={{ duration: rm ? 0 : 0.22, ease: EASE }}
      className="absolute inset-x-6 bottom-4 z-40 flex h-[176px] gap-3">
      <div className="paper-grain relative w-[128px] shrink-0 overflow-hidden rounded-[12px] border border-paper-edge">
        <div className="absolute inset-x-0 bottom-0 h-[54px] bg-paper-sunk" />
        <Hero look={npc.look} pose="talk" view="front" crop="bust" size={128} kit="camp" expression="talk" reducedMotion={rm} className="absolute bottom-0" />
      </div>
      <div className="paper-grain flex min-w-0 flex-1 flex-col rounded-[12px] border border-paper-edge px-4 py-3 shadow-[0_16px_40px_rgb(0_0_0/0.45)]">
        <div className="flex items-center gap-2">
          <span className="font-display text-[19px] leading-none text-ink">{npc.name}</span>
          <span className="text-[12px] text-ink-muted">{npc.role}</span>
          {npc.support && <Chip className="!h-5">Camp crew</Chip>}
          <button onClick={onClose} aria-label="Close" className="ml-auto -mr-2 -mt-1 grid h-10 w-10 place-items-center rounded-full text-ink-muted hover:bg-paper-sunk"><X size={18} /></button>
        </div>
        {t && <div className="mt-1 text-[12px] font-medium text-ember">You: {t.q}</div>}
        <p className="mt-1 line-clamp-3 text-[14px] leading-snug text-ink">{text}</p>
        {t?.engine && line === t.a.length - 1 && <div className="mt-1"><MechanicTag>Engine action · {t.engine}</MechanicTag></div>}
        <div className="mt-auto flex flex-wrap gap-1.5 pt-2">
          {t && line < t.a.length - 1 ? (
            <PrimaryButton className="!h-10 !text-[14px]" onClick={() => setLine(l => l + 1)}>Continue</PrimaryButton>
          ) : (
            <>
              {npc.topics.map((tp, i) => (
                <button key={tp.q} onClick={() => {
                  if (tp.engine && npc.id === 'lena' && i === 3) { onDecision(); return }
                  if (tp.engine) onEngine(tp.engine)
                  setTopic(i); setLine(0)
                }}
                  className={`h-10 whitespace-nowrap rounded-[6px] border px-3 text-[13px] transition-colors duration-150 ${topic === i ? 'border-spruce bg-spruce/10 text-ink' : 'border-paper-edge bg-paper-raised text-ink-soft hover:border-ink-muted'}`}>
                  {tp.q}
                </button>
              ))}
            </>
          )}
          {asking && null}
        </div>
      </div>
      <div className="paper-grain relative w-[110px] shrink-0 overflow-hidden rounded-[12px] border border-paper-edge">
        <div className="absolute inset-x-0 bottom-0 h-[48px] bg-paper-sunk" />
        <Hero look={you} pose="idle" view="front" crop="bust" size={110} kit="camp" expression={t ? 'neutral' : 'happy'} reducedMotion={rm} className="absolute bottom-0" />
      </div>
    </motion.div>
  )
}

function Sheet({ title, kicker, onClose, children, width = 560, rm }: { title: string; kicker: string; onClose: () => void; children: React.ReactNode; width?: number; rm: boolean }) {
  return (
    <div className="absolute inset-0 z-40 bg-scrim-soft" onClick={onClose}>
      <motion.div initial={{ opacity: 0, y: 8, scale: 0.98 }} animate={{ opacity: 1, y: 0, scale: 1 }} transition={{ duration: rm ? 0 : 0.22, ease: EASE }}
        onClick={e => e.stopPropagation()}
        className="paper-grain absolute bottom-4 left-1/2 top-4 flex -translate-x-1/2 flex-col rounded-[12px] border border-paper-edge shadow-[0_16px_40px_rgb(0_0_0/0.45)]" style={{ width }}>
        <div className="flex items-start justify-between px-5 pt-3">
          <div>
            <div className="text-[12px] font-medium text-ink-muted">{kicker}</div>
            <div className="font-display text-[22px] leading-tight text-ink">{title}</div>
          </div>
          <button onClick={onClose} aria-label="Close" className="-mr-2 grid h-12 w-12 place-items-center rounded-full text-ink-muted hover:bg-paper-sunk"><X size={20} /></button>
        </div>
        <div className="flex min-h-0 flex-1 flex-col px-5 pb-4">{children}</div>
      </motion.div>
    </div>
  )
}

function Tabs({ tabs, at, set }: { tabs: string[]; at: number; set: (i: number) => void }) {
  return (
    <div className="mt-1 flex gap-4 border-b border-paper-edge">
      {tabs.map((t, i) => (
        <button key={t} onClick={() => set(i)} className={`-mb-px h-10 border-b-2 text-[14px] font-medium transition-colors duration-150 ${at === i ? 'border-spruce text-ink' : 'border-transparent text-ink-muted hover:text-ink'}`}>{t}</button>
      ))}
    </div>
  )
}

/** Personal tent: rest, equipment, journal, progress. */
export function TentPanel({ you, onClose, rm }: { key?: React.Key;  you: Look; onClose: () => void; rm: boolean }) {
  const x = useExpedition()
  const [tab, setTab] = useState(0)
  const [resting, setResting] = useState(false)
  return (
    <Sheet kicker={`${CAMPS[x.at].name} · your tent`} title="Your tent" onClose={onClose} width={600} rm={rm}>
      <Tabs tabs={['Rest', 'Equipment', 'Journal', 'Progress']} at={tab} set={setTab} />
      <div className="no-scrollbar mt-3 min-h-0 flex-1 overflow-y-auto">
        {tab === 0 && (
          <div className="grid grid-cols-[150px_1fr] gap-4">
            <div className="relative h-[170px] overflow-hidden rounded-[8px] bg-[#2a2f40]">
              <div className="absolute inset-x-0 bottom-0 h-8 bg-[#5a4e42]" />
              <div className="absolute bottom-2 left-1/2 -translate-x-1/2"><Hero look={you} pose={resting ? 'sit' : 'idle'} view={resting ? 'side' : 'front'} size={110} kit="camp" seat={resting} expression={resting ? 'calm' : undefined} reducedMotion={rm} /></div>
            </div>
            <div>
              <p className="text-[14px] leading-snug text-ink-soft">Lie down and let the body work. Resting here is presentation only: it does not pass engine time or change a stat. Real rest is a decision ("Take the extra day") and stays in the decision card.</p>
              <div className="mt-3 space-y-2">
                {STATS.slice(0, 4).map(s => <Meter key={s.key} label={s.label} value={x.stats[s.key]} />)}
              </div>
              <PaperButton className="mt-3" onClick={() => setResting(r => !r)}>{resting ? 'Get up' : 'Lie down'}</PaperButton>
            </div>
          </div>
        )}
        {tab === 1 && (
          <div className="grid grid-cols-2 gap-x-6 gap-y-2">
            <div className="col-span-2 text-[13px] text-ink-muted">Your kit is cosmetic and persistent; climb pickups are found per attempt (existing rule).</div>
            {[['Jacket', you.jacket], ['Harness', you.harness], ['Chalk bag', you.chalkBag], ['Pack', you.packColor]].map(([k, c]) => (
              <div key={k} className="flex items-center gap-3 border-b border-paper-edge py-2"><span className="h-6 w-6 rounded-full ring-1 ring-ink/30" style={{ background: c }} /><span className="text-[14px] text-ink">{k}</span></div>
            ))}
            <div className="col-span-2 mt-2 text-[13px] font-semibold text-ink">Found on this expedition</div>
            {PACK.gear.map(gr => (
              <div key={gr.id} className="flex items-center justify-between border-b border-paper-edge py-1.5 text-[14px]"><span>{gr.label}</span><span className={gr.found ? 'text-good' : 'text-ink-muted'}>{gr.found ? 'In pack' : 'Not found'}</span></div>
            ))}
          </div>
        )}
        {tab === 2 && (
          <ol className="space-y-2">
            {x.log.map(l => <li key={l} className="border-b border-paper-edge pb-2 text-[14px] leading-snug text-ink-soft">{l}</li>)}
            <li className="text-[12px] text-ink-muted">Entries come from the engine's lastNote history (existing Log tab).</li>
          </ol>
        )}
        {tab === 3 && (
          <div>
            <div className="flex items-center gap-1">
              {CAMPS.map((c, i) => (
                <div key={c.id} className="flex flex-1 flex-col items-center">
                  <span className={`h-3 w-3 rounded-full border-2 ${i < x.at ? 'border-route bg-route' : i === x.at ? 'border-ember bg-ember' : 'border-ink-muted/50 bg-transparent'}`} />
                  <span className="mt-1 whitespace-nowrap text-[10px] text-ink-muted">{c.name.replace(' Camp', '')}</span>
                </div>
              ))}
            </div>
            <dl className="mt-4 grid grid-cols-3 divide-x divide-paper-edge border-y border-paper-edge py-2 text-center">
              <div><dt className="text-[11px] text-ink-muted">Day</dt><dd className="tabular text-[16px] font-semibold">{x.day} of {x.days}</dd></div>
              <div><dt className="text-[11px] text-ink-muted">Height</dt><dd className="tabular text-[16px] font-semibold">{CAMPS[x.at].meters.toLocaleString()} m</dd></div>
              <div><dt className="text-[11px] text-ink-muted">Climbs played</dt><dd className="tabular text-[16px] font-semibold">{(Object.values(x.climbs) as { done: boolean }[]).filter(c => c.done).length} of 3</dd></div>
            </dl>
          </div>
        )}
      </div>
    </Sheet>
  )
}

/** Guide's table: route conditions, upcoming challenge, and the existing decision. */
export function GuidePanel({ onClose, onDecision, rm }: { key?: React.Key;  onClose: () => void; onDecision: () => void; rm: boolean }) {
  const x = useExpedition()
  const next = CAMPS[Math.min(CAMPS.length - 1, x.at + 1)]
  const enc = Object.values(ENCOUNTERS).find(e => e.from === x.at)
  return (
    <Sheet kicker="Guide's table · with Lena" title={`Toward ${next.name}`} onClose={onClose} width={560} rm={rm}>
      <div className="grid grid-cols-2 gap-4">
        <div>
          <div className="text-[13px] font-semibold text-ink">Route conditions</div>
          <dl className="mt-1 divide-y divide-paper-edge border-y border-paper-edge text-[13px]">
            <div className="flex justify-between py-1.5"><dt className="text-ink-muted">Height gain</dt><dd className="font-semibold">+{(next.meters - CAMPS[x.at].meters).toLocaleString()} m</dd></div>
            <div className="flex justify-between py-1.5"><dt className="text-ink-muted">Map weather</dt><dd className="font-semibold capitalize">{x.weather}</dd></div>
            <div className="flex justify-between py-1.5"><dt className="text-ink-muted">Bad weather</dt><dd className="font-semibold">{x.stats.weatherRisk}</dd></div>
            <div className="flex justify-between py-1.5"><dt className="text-ink-muted">Falling rocks</dt><dd className="font-semibold">{x.stats.objectiveRisk}</dd></div>
          </dl>
          <p className="mt-2 text-[12px] text-ink-muted">Values read from the engine state; the camp never computes its own.</p>
        </div>
        <div>
          <div className="text-[13px] font-semibold text-ink">Upcoming challenge</div>
          {enc ? (
            <div className="mt-1 rounded-[8px] border border-paper-edge bg-paper-raised p-3">
              <div className="font-display text-[17px] text-ink">{enc.name}</div>
              <div className="text-[12px] text-ink-muted">{enc.axis}</div>
              <p className="mt-1 text-[13px] leading-snug text-ink-soft">{enc.godot}</p>
            </div>
          ) : <p className="mt-1 text-[13px] text-ink-soft">No played climb on the next leg.</p>}
          <p className="mt-2 text-[13px] leading-snug text-ink-soft">Lena: "{PARTY[1].name} is {PARTY[1].note.toLowerCase()} Jun is watching his head. Choose the day with that in it."</p>
        </div>
      </div>
      <div className="mt-auto flex gap-2 pt-3">
        <PaperButton onClick={onClose}>Not yet</PaperButton>
        <PrimaryButton className="flex-1" disabled={!x.event} onClick={onDecision}>{x.event ? `Open today's decision: ${x.event.title}` : 'Decision made'}</PrimaryButton>
      </div>
    </Sheet>
  )
}

/** Gear and supplies: inspect, review stores, and a prep checklist (visual only). */
export function GearPanel({ onClose, rm }: { key?: React.Key;  onClose: () => void; rm: boolean }) {
  const x = useExpedition()
  const [checked, setChecked] = useState<string[]>([])
  const items = ['Bottles filled', 'Headlamp batteries', 'Gloves in the lid', 'Snacks in a pocket']
  return (
    <Sheet kicker="Gear and supplies · Joseph checks the ropes here" title="Prepare for the next climb" onClose={onClose} width={600} rm={rm}>
      <div className="grid grid-cols-[1fr_1fr] gap-5">
        <div>
          <div className="text-[13px] font-semibold text-ink">Stores (engine values)</div>
          <div className="mt-2 space-y-2">
            <Meter label="Food & supplies" value={x.stats.supplies} />
            <div className="flex justify-between border-b border-paper-edge py-1.5 text-[14px]"><span>Medicine</span><span className="tabular font-semibold">{PACK.medicine} of {PACK.medicineMax} doses</span></div>
            <div className="flex justify-between border-b border-paper-edge py-1.5 text-[14px]"><span>Snacks</span><span className="tabular font-semibold">{PACK.snacks}</span></div>
          </div>
          <div className="mt-3 text-[13px] font-semibold text-ink">Gear found</div>
          <div className="mt-1 flex flex-wrap gap-1.5">{PACK.gear.map(gr => <Chip key={gr.id} tone={gr.found ? 'good' : 'neutral'}>{gr.label}</Chip>)}</div>
        </div>
        <div>
          <div className="flex items-center gap-2 text-[13px] font-semibold text-ink">Checklist <SimTag>Visual only</SimTag></div>
          <ul className="mt-2 space-y-1.5">
            {items.map(it => {
              const on = checked.includes(it)
              return (
                <li key={it}>
                  <button onClick={() => setChecked(c => on ? c.filter(v => v !== it) : [...c, it])} className={`flex h-11 w-full items-center gap-3 rounded-[6px] border px-3 text-left text-[14px] transition-colors duration-150 ${on ? 'border-spruce bg-spruce/10' : 'border-paper-edge bg-paper-raised'}`}>
                    <span className={`grid h-5 w-5 place-items-center rounded-[4px] border ${on ? 'border-spruce bg-spruce text-spruce-ink' : 'border-ink-muted'}`}>{on && <Check size={14} />}</span>{it}
                  </button>
                </li>
              )
            })}
          </ul>
          <p className="mt-2 text-[12px] leading-snug text-ink-muted">The checklist changes no gameplay value. It exists so the player looks at what the climb will cost before choosing it.</p>
        </div>
      </div>
    </Sheet>
  )
}

/** Viewpoint: the mountain, the next objective, conditions. */
export function ViewpointPanel({ phase, onClose, rm }: { key?: React.Key;  phase: CampPhase; onClose: () => void; rm: boolean }) {
  const x = useExpedition()
  const next = CAMPS[Math.min(CAMPS.length - 1, x.at + 1)]
  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={{ duration: rm ? 0 : 0.24, ease: EASE }} className="absolute inset-0 z-40 bg-night">
      <img src={VIEWPOINT_IMG} alt="Kibo from Karanga" className="absolute inset-0 h-full w-full object-cover" />
      <div className="absolute inset-0 bg-[#0a1430]" style={{ opacity: phase === 'night' ? 0.62 : phase === 'evening' ? 0.18 : 0 }} />
      <div className="absolute left-[47%] top-[38%]">
        <div className="h-3 w-3 rounded-full border-2 border-paper bg-ember" />
        <div className="world-text mt-1 whitespace-nowrap text-paper"><div className="font-display text-[16px]">{next.name}</div><div className="tabular text-[12px]">{next.meters.toLocaleString()} m · next objective</div></div>
      </div>
      <div className="absolute left-[37%] top-[11%] world-text text-paper"><div className="font-display text-[15px]">Uhuru Peak</div><div className="tabular text-[12px]">5,895 m</div></div>
      <div className="absolute left-7 top-4 rounded-[10px] bg-scrim px-4 py-3 text-paper ring-1 ring-white/15">
        <div className="font-display text-[18px]">From the viewpoint</div>
        <div className="mt-1 text-[13px] text-paper/85">Wind: {x.weather} · Visibility: {phase === 'night' ? 'stars, no cloud' : phase === 'evening' ? 'clear to the summit' : 'cloud building from the south'}</div>
      </div>
      <button onClick={onClose} className="absolute bottom-4 right-6 h-12 rounded-full bg-paper-raised px-5 font-display text-[16px] text-ink ring-1 ring-paper-edge transition-transform duration-[120ms] ease-out active:scale-[0.97]">Back to camp</button>
    </motion.div>
  )
}

/** Trail exit: back to the map, or continue when the engine allows it. */
export function ExitPanel({ onClose, onMap, onDecision, rm }: { key?: React.Key;  onClose: () => void; onMap: () => void; onDecision: () => void; rm: boolean }) {
  const x = useExpedition()
  return (
    <Sheet kicker="Trail exit" title="Leave camp?" onClose={onClose} width={440} rm={rm}>
      <p className="text-[14px] leading-snug text-ink-soft">{x.event ? `Today's decision is still open: "${x.event.title}". The team moves on only through that decision.` : 'The decision is made. The team is ready to walk.'}</p>
      <div className="mt-auto flex flex-col gap-2 pt-4">
        {x.event && <PrimaryButton onClick={onDecision}>Review today's decision</PrimaryButton>}
        <PaperButton onClick={onMap}>Back to the expedition map</PaperButton>
      </div>
    </Sheet>
  )
}
