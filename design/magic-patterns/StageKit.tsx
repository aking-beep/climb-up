import React from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import { PaperButton, PrimaryButton } from '../components/ui'
import { Modal } from '../overlays/Modal'
import { GEAR, GearKind, Raven } from './stageData'

const INK = '#1c1915'

/**
 * Shared stage chrome for the played climbs: what you carry (gear, artifacts,
 * a held rope), the find toast, the APK's decide / fire panels, finds and the
 * raven drawn in the world. Tags say which layer each piece belongs to.
 */

/** Under the stamina bar: gear in hand, artifacts carried, rope/teammate ready to hold a slip. */
export function CarryTray({ gear, gearTotal, artifacts, artifactsTotal, spotter, extra }: {
  gear: GearKind[]; gearTotal: number; artifacts: number; artifactsTotal: number; spotter: string | null; extra?: React.ReactNode
}) {
  return (
    <div className="absolute left-7 top-[76px] z-20 flex max-w-[300px] flex-wrap items-center gap-1">
      {artifactsTotal > 0 && (
        <span className="inline-flex h-6 items-center gap-1.5 rounded-full bg-scrim px-2 text-[11px] font-medium text-paper ring-1 ring-white/10">
          <ArtifactGlyph size={11} />
          <span className="tabular">Artifacts {artifacts}/{artifactsTotal}</span>
        </span>
      )}
      {gearTotal > 0 && (
        <span className="inline-flex h-6 items-center gap-1 rounded-full bg-scrim px-2 text-[11px] text-paper/90 ring-1 ring-white/10">
          <CrateGlyph size={11} />
          {gear.length ? gear.map(g => GEAR[g].label).join(' · ') : `Gear 0/${gearTotal}`}
        </span>
      )}
      {spotter && <span className="inline-flex h-6 items-center rounded-full bg-good px-2 text-[11px] font-medium text-paper">{spotter}</span>}
      {extra}
    </div>
  )
}

export interface Toast { kind: 'gear' | 'artifact' | 'lost' | 'info'; title: string; body: string; id: number }

/** Bottom-centre find card. Never pauses the climb (APK shows finds as a HUD flash). */
export function FindToast({ toast, rm, onClose }: { toast: Toast | null; rm: boolean; onClose: () => void }) {
  return (
    <div className="pointer-events-none absolute bottom-10 left-1/2 z-30 -translate-x-1/2">
      <AnimatePresence>
        {toast && (
          <motion.button key={toast.id} onClick={onClose}
            initial={{ opacity: 0, y: 10, scale: 0.96 }} animate={{ opacity: 1, y: 0, scale: 1 }} exit={{ opacity: 0, y: 6 }}
            transition={{ duration: rm ? 0 : 0.2, ease: [0.23, 1, 0.32, 1] }}
            className="paper-grain pointer-events-auto flex w-[380px] items-start gap-3 rounded-[10px] border border-paper-edge px-3.5 py-2.5 text-left shadow-[0_10px_28px_rgb(0_0_0/0.45)]">
            <span className="mt-0.5 grid h-8 w-8 shrink-0 place-items-center rounded-full bg-paper-sunk">
              {toast.kind === 'artifact' ? <ArtifactGlyph size={16} /> : toast.kind === 'lost' ? <LostGlyph /> : <CrateGlyph size={16} />}
            </span>
            <span className="min-w-0">
              <span className="block font-display text-[16px] leading-tight text-ink">{toast.title}</span>
              <span className="mt-0.5 block text-[12px] leading-snug text-ink-soft">{toast.body}</span>
            </span>
          </motion.button>
        )}
      </AnimatePresence>
    </div>
  )
}

/** APK · ClimbLevel.decide_panel, after the teammate beat: continue, regroup (about an hour), or retreat. */
export function DecidePanel({ title, body, breath, mate, onContinue, onRegroup, onRetreat, retreatLabel }: {
  title: string; body: string; breath: number; mate: string
  onContinue: () => void; onRegroup: () => void; onRetreat: () => void; retreatLabel: string
}) {
  return (
    <Modal kicker="Halfway up · existing decide panel (ClimbLevel)" title={title} width={500}
      footer={<>
        <PaperButton onClick={onRetreat} className="px-3">{retreatLabel}</PaperButton>
        <PaperButton onClick={onRegroup} className="px-3">Regroup (~1 h)</PaperButton>
        <PrimaryButton className="flex-1" onClick={onContinue}>Keep climbing</PrimaryButton>
      </>}>
      <p className="text-[14px] leading-snug text-ink-soft">{mate} {body}</p>
      <dl className="mt-3 divide-y divide-paper-edge border-y border-paper-edge text-[13px]">
        <div className="flex justify-between py-1.5"><dt className="text-ink-muted">Your stamina</dt><dd className="tabular font-semibold">{breath}%</dd></div>
        <div className="flex justify-between py-1.5"><dt className="text-ink-muted">Regroup</dt><dd className="font-semibold">Full stamina · +2 energy at camp · about an hour</dd></div>
      </dl>
    </Modal>
  )
}

/** APK · ClimbLevel "fire" interaction: once per cairn, full rest and rests back for an hour of the expedition clock. */
export function FirePanel({ where, mate, onFire, onClose }: { where: string; mate?: string; onFire: () => void; onClose: () => void }) {
  return (
    <Modal kicker={`${where} · existing cairn fire`} title="Make a fire?" onClose={onClose} width={440}
      footer={<><PaperButton onClick={onClose}>Not now, keep moving</PaperButton><PrimaryButton className="flex-1" onClick={onFire}>Make a fire (1 hour)</PrimaryButton></>}>
      <p className="text-[14px] leading-snug text-ink-soft">
        A fire and a hot drink: full stamina, your rests back{mate ? `, and ${mate} gets their breath back` : ''}. It costs 1 hour of the expedition: the permit's clock, and the leader points for speed.
      </p>
    </Modal>
  )
}

/* ---------------------------------------------------------------- world glyphs */

/** A gear find in the world: a small strapped bundle, ringed so it reads at 40 dp. */
export function GearFind({ x, y, label, near }: { key?: React.Key; x: number; y: number; label: string; near: boolean }) {
  return (
    <g transform={`translate(${x} ${y})`} pointerEvents="none">
      <circle r={13} fill="none" stroke="#e9c46a" strokeWidth={near ? 2 : 1.2} strokeDasharray="3 3" opacity={near ? 1 : 0.7} />
      <rect x={-7} y={-6} width={14} height={11} rx={2} fill="#c98a2e" stroke={INK} strokeWidth={1.2} />
      <path d="M-7 -1 L7 -1" stroke={INK} strokeWidth={1} />
      <rect x={-2} y={-8} width={4} height={4} rx={1} fill="#7a5410" stroke={INK} strokeWidth={0.8} />
      {near && <text y={-18} textAnchor="middle" fontSize={10} fontFamily="Outfit" fontWeight={600} fill="#f7f4ee" style={{ paintOrder: 'stroke', stroke: 'rgb(0 0 0 / 0.6)', strokeWidth: 3 }}>{label}</text>}
    </g>
  )
}

/** An artifact in the world: a wrapped bundle with a gold tie, always on the dangerous ground. */
export function ArtifactFind({ x, y, near }: { key?: React.Key; x: number; y: number; near: boolean }) {
  return (
    <g transform={`translate(${x} ${y})`} pointerEvents="none">
      <circle r={14} fill="#e9c46a" opacity={near ? 0.28 : 0.16} />
      <path d="M0 -9 L8 0 L0 9 L-8 0 Z" fill="#f2b33d" stroke={INK} strokeWidth={1.3} strokeLinejoin="round" />
      <path d="M0 -9 L0 9 M-8 0 L8 0" stroke="#7a5410" strokeWidth={0.9} />
    </g>
  )
}

function ArtifactGlyph({ size }: { size: number }) {
  return <svg width={size} height={size} viewBox="-9 -9 18 18" aria-hidden><path d="M0 -8 L7 0 L0 8 L-7 0 Z" fill="#f2b33d" stroke={INK} strokeWidth={1.4} /></svg>
}
function CrateGlyph({ size }: { size: number }) {
  return <svg width={size} height={size} viewBox="-8 -8 16 16" aria-hidden><rect x={-6} y={-5} width={12} height={10} rx={2} fill="#c98a2e" stroke={INK} strokeWidth={1.3} /><path d="M-6 0 L6 0" stroke={INK} strokeWidth={1} /></svg>
}
function LostGlyph() {
  return <svg width={16} height={16} viewBox="-8 -8 16 16" aria-hidden><path d="M-5 -5 L5 5 M5 -5 L-5 5" stroke="#b8432a" strokeWidth={2.4} strokeLinecap="round" /></svg>
}

/** APK · Creatures raven: circles, calls (beak open, ring on the target), dives to where you were, climbs back. */
export function RavenSprite({ r, home, rm }: { r: Raven; home: [number, number]; rm: boolean }) {
  let x = home[0] + Math.cos(r.t * 1.6) * 60, y = home[1] + Math.sin(r.t * 3.2) * 12
  if (r.phase === 'dive') { const k = Math.min(1, r.t / 0.45); x = home[0] + (r.tx - home[0]) * k; y = home[1] + (r.ty - home[1]) * k }
  if (r.phase === 'back') { const k = Math.min(1, r.t / 1); x = r.tx + (home[0] - r.tx) * k; y = r.ty + (home[1] - r.ty) * k }
  const flap = rm ? 0 : Math.sin(r.t * 18) * 5
  return (
    <g pointerEvents="none">
      {r.phase === 'call' && <circle cx={r.tx} cy={r.ty} r={26} fill="none" stroke="#d9572b" strokeWidth={2} strokeDasharray="4 3" />}
      <g transform={`translate(${x} ${y})`}>
        <path d={`M-14 ${-2 + flap} Q-6 -6 0 0 Q6 -6 14 ${-2 + flap}`} fill="none" stroke={INK} strokeWidth={3.4} strokeLinecap="round" />
        <ellipse rx={5} ry={3.4} fill={INK} />
        <path d="M-1.6 -2.4 L1.6 -2.4 L0 -0.4 Z" fill="#f7f4ee" />
        {r.phase === 'call' && <path d="M5 -1 L10 -3 M5 1 L10 2" stroke={INK} strokeWidth={1.4} />}
      </g>
    </g>
  )
}

/** A small companion breath meter over a helped teammate's head (APK · ClimbLevel.mate_breath). */
export function MateBreath({ v, winded }: { v: number; winded: boolean }) {
  const col = v < 30 ? 'bg-stam-low' : v < 60 ? 'bg-stam-mid' : 'bg-stam-high'
  return (
    <div className="absolute left-1/2 top-[-14px] w-[46px] -translate-x-1/2">
      <div className="h-[5px] overflow-hidden rounded-full bg-black/50 ring-1 ring-white/20"><div className={`h-full ${col}`} style={{ width: `${v}%` }} /></div>
      {winded && <div className="world-text mt-0.5 whitespace-nowrap text-center text-[10px] font-semibold text-paper">Stopped</div>}
    </div>
  )
}
