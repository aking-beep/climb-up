import React, { useEffect, useState } from 'react'
import { Lock, Check } from 'lucide-react'
import { useGame } from '../state/GameState'
import { Slot } from './SlotTabs'
import { Climber } from '../components/Climber'
import { RopeCoil } from '../components/Icons'
import {
  BAG_COLORS, CHALK_BAGS, HARNESSES, HEADWEAR, HEADWEAR_COLORS, JACKETS, Look, Option, PACKS, PACK_COLORS, ROPES,
  DEFAULT_LOOK, DEFAULT_LOOK_F, PRESET_LOOKS_F, PRESET_LOOKS_M, SKIN_TONES, HAIR_COLORS,
} from '../data/cosmetics'
import { Hero } from '../components/Hero'

const TITLE: Record<Slot, string> = { body: 'Your climber', jacket: 'Jacket colour', headwear: 'Helmet or hat', pack: 'Backpack', harness: 'Harness colour', chalk: 'Chalk bag', rope: 'Rope colour' }

/** Conditions the sample save already meets (2★ Warm-up, an expedition ending, a summit). */
const MET = new Set(['2 stars on Warm-up Wall', 'Finish any expedition ending', 'Reach Uhuru Peak'])

export function OptionGrid({ slot }: { slot: Slot }) {
  const g = useGame()
  const [note, setNote] = useState<string | null>(null)
  useEffect(() => setNote(null), [slot])
  const set = (patch: Partial<Look>) => g.setLook({ ...g.look, ...patch })
  const locked = (o: Option<unknown>) => !!o.lock && !MET.has(o.lock)
  const tryPick = (o: Option<unknown>, apply: () => void) => {
    if (locked(o)) { setNote(`Locked · ${o.lock}`); return }
    setNote(o.lock ? `Unlocked by: ${o.lock}` : null)
    apply()
  }

  return (
    <div className="min-h-0">
      <div className="font-display text-[19px] text-ink">{TITLE[slot]}</div>
      <div className="mt-2">
        {slot === 'body' && <BodyPicker look={g.look} set={set} replace={g.setLook} />}
        {slot === 'jacket' && (
          <div className="grid grid-cols-4 gap-2">
            {JACKETS.map(o => (
              <Swatch key={o.id} color={o.value} label={o.label} selected={g.look.jacket === o.value} locked={locked(o)} onClick={() => tryPick(o, () => set({ jacket: o.value, jacketTrim: o.trim ?? o.value }))} />
            ))}
          </div>
        )}
        {slot === 'headwear' && (
          <>
            <div className="grid grid-cols-3 gap-1.5">
              {HEADWEAR.map(o => (
                <Tile key={o.id} label={o.label} selected={g.look.headwear === o.value} locked={locked(o)} onClick={() => tryPick(o, () => set({ headwear: o.value }))}>
                  <HeadPreview look={{ ...g.look, headwear: o.value }} />
                </Tile>
              ))}
            </div>
            <ColorRow colors={HEADWEAR_COLORS} value={g.look.headwearColor} onPick={c => set({ headwearColor: c })} />
          </>
        )}
        {slot === 'pack' && (
          <>
            <div className="grid grid-cols-2 gap-1.5">
              {PACKS.map(o => (
                <Tile key={o.id} label={o.label} selected={g.look.pack === o.value} locked={locked(o)} onClick={() => tryPick(o, () => set({ pack: o.value }))}>
                  <BodyPreview look={{ ...g.look, pack: o.value }} />
                </Tile>
              ))}
            </div>
            <ColorRow colors={PACK_COLORS} value={g.look.packColor} onPick={c => set({ packColor: c })} />
          </>
        )}
        {slot === 'harness' && (
          <div className="grid grid-cols-4 gap-2">
            {HARNESSES.map(o => (
              <Swatch key={o.id} color={o.value} label={o.label} selected={g.look.harness === o.value} locked={locked(o)} onClick={() => tryPick(o, () => set({ harness: o.value }))} />
            ))}
          </div>
        )}
        {slot === 'chalk' && (
          <>
            <div className="grid grid-cols-2 gap-1.5">
              {CHALK_BAGS.map(o => (
                <Tile key={o.id} label={o.label} selected={g.look.bagPattern === o.value} locked={locked(o)} onClick={() => tryPick(o, () => set({ bagPattern: o.value }))}>
                  <BodyPreview look={{ ...g.look, bagPattern: o.value }} zoomBag />
                </Tile>
              ))}
            </div>
            <ColorRow colors={BAG_COLORS} value={g.look.chalkBag} onPick={c => set({ chalkBag: c })} />
          </>
        )}
        {slot === 'rope' && (
          <div className="grid grid-cols-5 gap-1.5">
            {ROPES.map(o => (
              <Tile key={o.id} label={o.label} selected={g.look.rope === o.value} locked={locked(o)} onClick={() => tryPick(o, () => set({ rope: o.value }))}>
                <RopeCoil color={o.value} size={38} />
              </Tile>
            ))}
          </div>
        )}
      </div>
      <div className={`mt-2 min-h-[20px] text-[13px] ${note?.startsWith('Locked') ? 'text-ember' : 'text-good'}`}>{note}</div>
    </div>
  )
}

function Swatch({ color, label, selected, locked, onClick }: { key?: React.Key; color: string; label: string; selected: boolean; locked: boolean; onClick: () => void }) {
  return (
    <button onClick={onClick} aria-pressed={selected} aria-label={`${label}${locked ? ', locked' : ''}`} className="flex flex-col items-center gap-1 rounded-[8px] py-1.5 transition-colors duration-150 hover:bg-paper-sunk">
      <span className={`relative grid h-11 w-11 place-items-center rounded-full ${selected ? 'ring-[3px] ring-spruce ring-offset-2 ring-offset-paper' : 'ring-1 ring-ink/20'}`} style={{ background: color, opacity: locked ? 0.45 : 1 }}>
        {selected && <Check size={18} className="text-paper drop-shadow" />}
        {locked && <Lock size={15} className="text-ink" />}
      </span>
      <span className={`whitespace-nowrap text-[12px] ${locked ? 'text-ink-muted' : 'text-ink'}`}>{label}</span>
    </button>
  )
}

function Tile({ label, selected, locked, onClick, children }: { key?: React.Key; label: string; selected: boolean; locked: boolean; onClick: () => void; children: React.ReactNode }) {
  return (
    <button onClick={onClick} aria-pressed={selected}
      className={`relative flex h-[72px] flex-col items-center justify-end overflow-hidden rounded-[8px] border pb-1 transition-colors duration-150 ${selected ? 'border-spruce bg-spruce/10' : 'border-paper-edge bg-paper-raised hover:border-ink-muted'}`}>
      <span className={`flex flex-1 items-center justify-center ${locked ? 'opacity-40' : ''}`}>{children}</span>
      <span className={`w-full truncate px-1 text-center text-[11px] leading-tight ${locked ? 'text-ink-muted' : 'text-ink'}`}>{label}</span>
      {locked && <Lock size={13} className="absolute right-1.5 top-1.5 text-ink-muted" />}
    </button>
  )
}

function ColorRow({ colors, value, onPick }: { colors: string[]; value: string; onPick: (c: string) => void }) {
  return (
    <div className="mt-2.5 flex items-center gap-2">
      {colors.map(c => (
        <button key={c} onClick={() => onPick(c)} aria-label={`Colour ${c}`} aria-pressed={value === c}
          className={`h-8 w-8 rounded-full ${value === c ? 'ring-[3px] ring-spruce ring-offset-2 ring-offset-paper' : 'ring-1 ring-ink/20'}`} style={{ background: c }} />
      ))}
    </div>
  )
}

function HeadPreview({ look }: { look: Look }) {
  return <div className="h-[44px] w-[52px] overflow-hidden"><Climber look={look} size={88} style={{ marginLeft: -18, marginTop: -8 }} /></div>
}

function BodyPreview({ look, zoomBag }: { look: Look; zoomBag?: boolean }) {
  return (
    <div className="h-[46px] w-[60px] overflow-hidden">
      <Climber look={look} view="back" size={zoomBag ? 120 : 60} style={zoomBag ? { marginLeft: -30, marginTop: -92 } : { marginLeft: 0, marginTop: -8 }} />
    </div>
  )
}

/** Character A only. Body type, then a matching colourway, skin and hair. Same unlocks and gameplay for both. */
function BodyPicker({ look, set, replace }: { look: Look; set: (p: Partial<Look>) => void; replace: (l: Look) => void }) {
  const body = look.body ?? 'm'
  const presets = body === 'f' ? PRESET_LOOKS_F : PRESET_LOOKS_M
  const choose = (b: 'm' | 'f') => {
    if (b === body) return
    const other = body === 'f' ? DEFAULT_LOOK_F : DEFAULT_LOOK
    const same = (Object.keys(other) as (keyof Look)[]).every(k => k === 'body' || other[k] === look[k])
    replace(same ? (b === 'f' ? DEFAULT_LOOK_F : DEFAULT_LOOK) : { ...look, body: b })
  }
  return (
    <div className="space-y-2.5">
      <div className="grid grid-cols-2 gap-2">
        {([['m', 'Male'], ['f', 'Female']] as const).map(([b, l]) => (
          <button key={b} onClick={() => choose(b)} aria-pressed={body === b}
            className={`relative flex h-[80px] items-end justify-between overflow-hidden rounded-[8px] border px-2 pb-1.5 transition-colors duration-150 ${body === b ? 'border-spruce bg-spruce/10' : 'border-paper-edge bg-paper-raised hover:border-ink-muted'}`}>
            <span className="font-display text-[15px] text-ink">{l}</span>
            <Hero look={{ ...look, body: b }} body={b} pose="idle" view="front" crop="bust" size={70} time={0.4} />
            {body === b && <Check size={14} className="absolute left-2 top-2 text-spruce" />}
          </button>
        ))}
      </div>
      <div>
        <div className="mb-1 text-[12px] font-medium text-ink-muted">Colourways</div>
        <div className="grid grid-cols-4 gap-1.5">
          {presets.map((p, i) => (
            <button key={i} onClick={() => replace(p)} aria-label={`Colourway ${i + 1}`}
              className="flex h-10 overflow-hidden rounded-[6px] ring-1 ring-paper-edge transition-transform duration-[120ms] ease-out active:scale-[0.96]">
              {[p.jacket, p.headwearColor, p.packColor, p.harness].map((c, k) => <span key={k} className="h-full flex-1" style={{ background: c }} />)}
            </button>
          ))}
        </div>
      </div>
      <div>
        <div className="mb-1 text-[12px] font-medium text-ink-muted">Skin</div>
        <div className="flex gap-1.5">{SKIN_TONES.map(c => <Dot key={c} c={c} on={look.skin === c} pick={() => set({ skin: c })} />)}</div>
      </div>
      <div>
        <div className="mb-1 text-[12px] font-medium text-ink-muted">Hair</div>
        <div className="flex gap-1.5">{HAIR_COLORS.map(c => <Dot key={c} c={c} on={look.hair === c} pick={() => set({ hair: c })} />)}</div>
      </div>
    </div>
  )
}

function Dot({ c, on, pick }: { key?: React.Key; c: string; on: boolean; pick: () => void }) {
  return (
    <button onClick={pick} aria-pressed={on} aria-label={c}
      className={`h-8 w-8 rounded-full transition-transform duration-[120ms] ease-out active:scale-[0.92] ${on ? 'ring-2 ring-spruce ring-offset-2 ring-offset-paper' : 'ring-1 ring-ink/25'}`} style={{ background: c }} />
  )
}
