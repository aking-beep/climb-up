import React, { useEffect, useRef, useState } from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import { MessageCircle, Tent as TentIcon, Map as MapIcon, Eye, Flame, Package, LogOut, Compass } from 'lucide-react'
import { useGame } from '../state/GameState'
import { useExpedition } from '../state/Expedition'
import { Hero } from '../components/Hero'
import { BackButton, PaperButton, PrimaryButton, SimTag } from '../components/ui'
import { CAMPS, Choice } from '../data/kili'
import { DecisionCard } from '../expedition/DecisionCard'
import { Modal } from '../overlays/Modal'
import { Stick, StickV } from '../encounter/Stick'
import { ActionButton } from '../encounter/Panels'
import { WindStreaks } from '../encounter/BarrancoArt'
import { SpecNote } from '../components/SpecNote'
import { BOUNDS, CAMP_H, CAMP_PLATE, CAMP_W, COLLIDERS, NPCS, PHASE_COPY, SPOTS, Spot } from '../camp/campData'
import { Fire, GearPile, Lantern, MapTable, MessTent, Signpost, Stove, Supplies, Tent } from '../camp/CampArt'
import { DialoguePanel, ExitPanel, GearPanel, GuidePanel, TentPanel, ViewpointPanel } from '../camp/CampPanels'

type Panel = null | { kind: Spot['kind']; id: string }
const HERO = 70
const K = HERO / 120
const VW = 915, VH = 412

/**
 * Interactive camp (optional). Walk with the stick, approach a person or a
 * place, an icon appears, tap to open its panel, close to keep exploring.
 * "Decisions" (top right) opens the existing camp decision immediately.
 * Camp state (day / evening / night) is read from the engine's hour; the
 * camp never changes time or weather.
 */
export function Camp() {
  const g = useGame()
  const x = useExpedition()
  const rm = g.settings.reducedMotion
  const phase = x.phase
  const P = useRef({ x: 640, y: 400, facing: 1 as 1 | -1, walk: 0, moving: false, camX: 200, camY: 120, t: 0 })
  const stick = useRef<StickV>({ x: 0, y: 0 })
  const [panel, setPanel] = useState<Panel>(null)
  const [decision, setDecision] = useState(false)
  const [preview, setPreview] = useState<Choice | null>(null)
  const [retreat, setRetreat] = useState<Choice | null>(null)
  const [, setFrame] = useState(0)
  const busy = panel !== null || decision

  useEffect(() => {
    let raf = 0, last = performance.now()
    const step = (now: number) => {
      const dt = Math.min(0.05, (now - last) / 1000); last = now
      const p = P.current
      p.t += dt
      const v = busy ? { x: 0, y: 0 } : stick.current
      const mag = Math.min(1, Math.hypot(v.x, v.y))
      p.moving = mag > 0.1
      if (p.moving) {
        let nx = p.x + v.x * 150 * dt, ny = p.y + v.y * 110 * dt
        nx = Math.max(BOUNDS.x0, Math.min(BOUNDS.x1, nx)); ny = Math.max(BOUNDS.y0, Math.min(BOUNDS.y1, ny))
        COLLIDERS.forEach(([cx, cy, r]) => {
          const dx = nx - cx, dy = (ny - cy) * 1.4, d = Math.hypot(dx, dy)
          if (d < r) { nx = cx + (dx / (d || 1)) * r; ny = cy + (dy / (d || 1)) * r / 1.4 }
        })
        p.x = nx; p.y = ny
        if (Math.abs(v.x) > 0.15) p.facing = v.x > 0 ? 1 : -1
        p.walk += mag * dt * 1.25
      }
      const tx = Math.max(0, Math.min(CAMP_W - VW, p.x - VW / 2)), ty = Math.max(0, Math.min(CAMP_H - VH, p.y - VH * 0.58))
      const k = rm ? 1 : 1 - Math.exp(-dt / 0.14)
      p.camX += (tx - p.camX) * k; p.camY += (ty - p.camY) * k
      setFrame(f => (f + 1) % 1e6)
      raf = requestAnimationFrame(step)
    }
    raf = requestAnimationFrame(step)
    return () => cancelAnimationFrame(raf)
  }, [busy, rm])

  const p = P.current
  const npcs = NPCS.map(n => {
    const a = n.at[phase]
    let nx = a.x, facing = a.facing, walking = false
    if (a.patrol) {
      const span = a.patrol[1] - a.patrol[0]
      const c = (p.t * 40) % (span * 2)
      nx = a.patrol[0] + (c < span ? c : span * 2 - c)
      facing = c < span ? 1 : -1
      walking = true
    }
    return { n, a, x: nx, y: a.y, facing, walking }
  })
  const awake = npcs.filter(e => !e.a.asleep)
  type Target = { kind: Spot['kind']; id: string; x: number; y: number; label: string; verb: string; npc?: typeof npcs[number] }
  const targets: Target[] = [
    ...SPOTS.map(s => ({ ...s })),
    ...awake.map(e => ({ kind: 'npc' as const, id: e.n.id, x: e.x, y: e.y, label: `${e.n.name} · ${e.a.doing}`, verb: 'Talk', npc: e })),
  ]
  let near: Target | null = null
  let best = 74
  targets.forEach(t => { const d = Math.hypot(t.x - p.x, (t.y - p.y) * 1.3); if (d < best) { best = d; near = t } })
  const nearT = near as Target | null

  const open = (t: Target) => {
    if (t.kind === 'exit' && !x.event) { g.go('expedition'); return }
    setPanel({ kind: t.kind, id: t.id })
  }
  const openDecision = () => { setPanel(null); setDecision(true) }
  const confirm = (c: Choice) => {
    if (c.move === 'retreat') { setRetreat(c); return }
    setDecision(false); setPreview(null)
    x.apply(c)
    if (!c.climb && (c.move === 'up' || c.move === 'summit')) g.go('expedition')
  }

  const lit = phase !== 'day'
  const lights: [number, number, number][] = [
    ...(lit ? [[430, 590, 120], [860, 480, 60], [780, 300, 80], [300, 310, 46], [1060, 330, 44]] as [number, number, number][] : []),
    ...(phase === 'night' ? [[p.x, p.y - 30, 70]] as [number, number, number][] : []),
  ]
  const tint = phase === 'night' ? { c: '#0a1430', o: 0.66 } : phase === 'evening' ? { c: '#7a3a1e', o: 0.3 } : { c: '#000', o: 0 }

  // y-sorted world entities
  const ents: { y: number; el: React.ReactNode }[] = [
    { y: 290, el: <Tent x={300} y={330} w={104} color={g.look.packColor} lit={lit} /> },
    { y: 250, el: <Tent x={180} y={280} color="#c98a2e" lit={phase === 'evening'} /> },
    { y: 252, el: <Tent x={440} y={282} color="#3f6f8a" lit={phase === 'evening'} door={-1} /> },
    { y: 240, el: <MessTent x={780} y={290} lit={lit} /> },
    { y: 300, el: <MapTable x={1060} y={318} /> },
    { y: 470, el: <GearPile x={570} y={500} rope={g.look.rope} /> },
    { y: 500, el: <Stove x={900} y={510} steam rm={rm} /> },
    { y: 600, el: <Supplies x={700} y={620} /> },
    { y: 596, el: <Fire x={430} y={612} lit={phase !== 'day'} rm={rm} /> },
    { y: 330, el: <Lantern x={720} y={330} lit={lit} /> },
    { y: 600, el: <Signpost x={1400} y={610} /> },
    ...awake.map(e => ({
      y: e.y,
      el: (
        <div key={e.n.id} className="pointer-events-none absolute" style={{ left: e.x - 60 * K, top: e.y - 146 * K }}>
          <Hero look={e.n.look} pose={e.walking ? 'walk' : e.a.pose} view={e.a.pose === 'talk' || e.a.pose === 'idle' ? 'front' : 'side'} size={HERO} kit="camp" facing={e.facing} seat={e.a.pose === 'sit'} phase={e.n.id.length * 0.37} reducedMotion={rm} />
          {e.n.id === 'neema' && phase === 'day' && <div className="absolute left-[20px] top-[52px] h-[16px] w-[11px] rounded-[3px] border border-ink bg-[#e9c46a]" />}
        </div>
      ),
    })),
    {
      y: p.y,
      el: (
        <div key="you" className="pointer-events-none absolute" style={{ left: p.x - 60 * K, top: p.y - 146 * K }}>
          <Hero look={phase === 'night' ? { ...g.look, headwear: 'headlamp' } : g.look} pose={p.moving ? 'walk' : 'idle'} view={p.moving ? 'side' : 'front'} size={HERO} kit="camp" facing={p.facing} time={p.moving ? p.walk : undefined} reducedMotion={rm} />
        </div>
      ),
    },
  ].sort((a, b) => a.y - b.y)

  const iconFor = (t: Target) => t.kind === 'npc' ? <MessageCircle size={18} /> : t.kind === 'tent' ? <TentIcon size={18} /> : t.kind === 'guide' ? <Compass size={18} /> : t.kind === 'equipment' ? <Package size={18} /> : t.kind === 'campfire' ? <Flame size={18} /> : t.kind === 'viewpoint' ? <Eye size={18} /> : <LogOut size={18} />
  const activeNpc = panel?.kind === 'npc' ? NPCS.find(n => n.id === panel.id) : panel?.kind === 'campfire' ? NPCS.find(n => n.id === (phase === 'evening' ? 'lena' : 'marco')) : undefined

  return (
    <div className="absolute inset-0 overflow-hidden bg-[#5a4e42]">
      <div className="absolute left-0 top-0" style={{ width: CAMP_W, height: CAMP_H, transform: `translate(${-p.camX}px, ${-p.camY}px)` }}>
        <img src={CAMP_PLATE} alt="" draggable={false} className="pointer-events-none absolute inset-0 h-full w-full object-cover" />
        {/* far edge: the viewpoint outcrop */}
        <svg className="pointer-events-none absolute" style={{ left: 1260, top: 150 }} width={160} height={90} aria-hidden><path d="M10 80 L40 30 L110 18 L150 60 L150 90 L10 90 Z" fill="#6b5d4e" stroke="#1c1915" strokeWidth={1.4} /></svg>
        {ents.map((e, i) => <React.Fragment key={i}>{e.el}</React.Fragment>)}
        {/* night lighting with light pools cut out (stepped edges) */}
        {tint.o > 0 && (
          <svg width={CAMP_W} height={CAMP_H} className="pointer-events-none absolute inset-0" aria-hidden>
            <defs>
              <mask id="camplight">
                <rect width={CAMP_W} height={CAMP_H} fill="white" />
                {lights.map(([lx, ly, r], i) => <g key={i}><ellipse cx={lx} cy={ly} rx={r * 1.35} ry={r * 0.95} fill="#999" /><ellipse cx={lx} cy={ly} rx={r} ry={r * 0.7} fill="#333" /></g>)}
              </mask>
            </defs>
            <rect width={CAMP_W} height={CAMP_H} fill={tint.c} opacity={tint.o} mask="url(#camplight)" />
            {phase === 'night' && Array.from({ length: 40 }).map((_, i) => <circle key={i} cx={(i * 211) % CAMP_W} cy={(i * 37) % 140} r={1} fill="#fff" opacity={0.7} />)}
          </svg>
        )}
        {/* interaction icon over the nearest target */}
        <AnimatePresence>
          {nearT && !busy && (
            <motion.button key={nearT.id} initial={{ opacity: 0, y: 4, scale: 0.96 }} animate={{ opacity: 1, y: 0, scale: 1 }} exit={{ opacity: 0 }} transition={{ duration: rm ? 0 : 0.15, ease: [0.23, 1, 0.32, 1] }}
              onClick={() => open(nearT)}
              className="absolute z-30 flex h-10 -translate-x-1/2 items-center gap-1.5 whitespace-nowrap rounded-full bg-paper-raised pl-2.5 pr-3 text-[13px] font-medium text-ink shadow-[0_3px_10px_rgb(0_0_0/0.35)] ring-1 ring-paper-edge"
              style={{ left: nearT.x, top: nearT.y - (nearT.kind === 'npc' ? 104 : 86) }}>
              <span className="text-spruce">{iconFor(nearT)}</span>{nearT.label}
            </motion.button>
          )}
        </AnimatePresence>
      </div>

      <WindStreaks on={x.weather === 'wind' && phase === 'day'} strong={false} rm={rm} />

      {/* chrome */}
      <div className="absolute left-7 top-4 z-20 flex items-center gap-3">
        <BackButton dark label="Map" onClick={() => g.go('expedition')} />
        <div className="world-text text-paper">
          <div className="font-display text-[20px] leading-none">{CAMPS[x.at].name}</div>
          <div className="tabular mt-1 text-[12px] text-paper/85">{CAMPS[x.at].meters.toLocaleString()} m · Day {x.day} · {PHASE_COPY[phase].name}</div>
        </div>
      </div>
      <div className="absolute right-6 top-4 z-20 flex items-center gap-2">
        <PrimaryButton onClick={openDecision} disabled={!x.event}><MapIcon size={18} /> {x.event ? 'Decisions' : 'Decided'}</PrimaryButton>
      </div>

      {!busy && (
        <>
          <Stick zoneW={330} zoneH={250} onChange={v => { stick.current = v }} label="Walk" />
          <ActionButton x={826} y={336} label={nearT ? nearT.verb : 'Explore'} sub={nearT ? undefined : 'walk closer'} disabled={!nearT} tone={nearT ? 'route' : 'paper'} onClick={() => nearT && open(nearT)} />
        </>
      )}

      <div className="pointer-events-none absolute bottom-3 left-1/2 z-10 -translate-x-1/2"><SimTag className="!bg-paper/90">Optional camp · simulated · engine untouched</SimTag></div>

      <AnimatePresence>
        {activeNpc && <DialoguePanel key={activeNpc.id + phase} npc={activeNpc} phase={phase} you={g.look} rm={rm} onClose={() => setPanel(null)} onEngine={t => x.say(`${t} (simulated)`)} onDecision={openDecision} />}
        {panel?.kind === 'tent' && <TentPanel key="tent" you={g.look} onClose={() => setPanel(null)} rm={rm} />}
        {panel?.kind === 'guide' && <GuidePanel key="guide" onClose={() => setPanel(null)} onDecision={openDecision} rm={rm} />}
        {panel?.kind === 'equipment' && <GearPanel key="gear" onClose={() => setPanel(null)} rm={rm} />}
        {panel?.kind === 'viewpoint' && <ViewpointPanel key="view" phase={phase} onClose={() => setPanel(null)} rm={rm} />}
        {panel?.kind === 'exit' && <ExitPanel key="exit" onClose={() => setPanel(null)} onMap={() => g.go('expedition')} onDecision={openDecision} rm={rm} />}
        {decision && x.event && (
          <DecisionCard key="dec" camp={CAMPS[x.at]} event={x.event} preview={preview} setPreview={setPreview} onConfirm={confirm} onClose={() => { setDecision(false); setPreview(null) }} rm={rm} />
        )}
      </AnimatePresence>

      <AnimatePresence>
        {x.toast && (
          <motion.div initial={{ opacity: 0, y: -4 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} transition={{ duration: 0.18 }}
            className="absolute left-1/2 top-[70px] z-50 max-w-[440px] -translate-x-1/2 rounded-[8px] bg-scrim px-4 py-2 text-center text-[13px] text-paper ring-1 ring-white/15">{x.toast}</motion.div>
        )}
      </AnimatePresence>

      {retreat && (
        <Modal kicker="Turn around" title="Walk out from here?" onClose={() => setRetreat(null)} width={440}
          footer={<><PaperButton onClick={() => setRetreat(null)}>Not yet</PaperButton><PrimaryButton className="flex-1" onClick={() => { const c = retreat; setRetreat(null); setDecision(false); x.apply(c) }}>Turn around</PrimaryButton></>}>
          <p className="text-[14px] leading-snug text-ink-soft">{retreat.detail} Turning around while the way down still exists is scored as judgment, not failure.</p>
        </Modal>
      )}

      {g.settings.showSpecs && (
        <>
          <SpecNote x={330} y={90} w={200}>Prompt appears within 74 px; nearest target wins; tap icon or action button</SpecNote>
          <SpecNote x={600} y={90} w={200}>Decisions shortcut: same card and engine call as the map</SpecNote>
        </>
      )}
    </div>
  )
}
