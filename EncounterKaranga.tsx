import React, { useEffect, useMemo, useRef, useState } from 'react'
import { useGame } from '../state/GameState'
import { useExpedition } from '../state/Expedition'
import { Hero, HeroPose } from '../components/Hero'
import { PaperButton, PrimaryButton, SimTag } from '../components/ui'
import { Modal } from '../overlays/Modal'
import { EncounterHud } from '../encounter/EncounterHud'
import { ActionButton, ApkTag, BriefCard, EncounterResult, MechanicTag } from '../encounter/Panels'
import { WindStreaks } from '../encounter/BarrancoArt'
import { CarryTray, FindToast } from '../encounter/StageKit'
import { slipSummary, GEAR } from '../encounter/stageData'
import { Sim, T, freshSim, near, step, tryRest } from '../encounter/plat/engine'
import { buildKaranga } from '../encounter/plat/levels'
import { DynLayer, KARANGA_PAL, PropLayer, TerrainLayer, WaterFront } from '../encounter/plat/TileWorld'
import { PadRefs, PlatPad } from '../encounter/plat/PlatPad'
import { StickV } from '../encounter/Stick'

export { TEAM_LOOKS } from '../encounter/team'
export const KARANGA_BG = 'https://cdn.magicpatterns.com/patterns/generated-images/348553d4-2166-4768-904d-2f3368f8e3e0.jpg'

const HERO = 50
const K = HERO / 120
const FOG_FROM = 150 * T

type Mode = 'brief' | 'play' | 'done' | 'fail'
interface Stage { sim: Sim; mode: Mode; bottles: number; filled: boolean; drank: number; spilled: number; stars: number }

/**
 * CLIMB 2 — Karanga Ridge (PROPOSED level: Karanga → Barafu is an engine card
 * in the APK). Played solo as an APK-style tile platformer: the stream valley
 * and its last water, the valley wall, the junction where the line splits
 * (a windy crest with a notch and a cracked slab, or a scree traverse under
 * it with stones and a raven), cloud, then the rock band to Barafu.
 * Lands no ChallengeOutcome on the engine.
 */
export function EncounterKaranga() {
  const g = useGame()
  const x = useExpedition()
  const rm = g.settings.reducedMotion
  const barMax = Math.max(48, Math.min(100, Math.round((x.stats.health + x.stats.energy) / 2) + 15))
  const L = useMemo(buildKaranga, [])
  const fresh = (mode: Mode): Stage => ({ sim: freshSim(L, barMax), mode, bottles: 0, filled: false, drank: 0, spilled: 0, stars: 0 })
  const S = useRef<Stage>(fresh('brief'))
  const stickRef = useRef<StickV>({ x: 0, y: 0 })
  const hopRef = useRef(false)
  const pad = useMemo<PadRefs>(() => ({ stick: stickRef, hop: hopRef }), [])
  const [paused, setPaused] = useState(false)
  const [, setFrame] = useState(0)

  useEffect(() => {
    let raf = 0, last = performance.now()
    const loop = (now: number) => {
      const dt = Math.min(0.033, (now - last) / 1000); last = now
      const st = S.current
      if (!paused && st.mode === 'play') {
        const s = st.sim
        s.loadMul = 1 + st.bottles * 0.1
        step(s, L, { x: pad.stick.current.x, y: pad.stick.current.y, hop: pad.hop.current }, dt, [], rm)
        for (const e of s.events) {
          if (e.k === 'slip' && e.counted && st.bottles > 0) {
            st.bottles--; st.spilled++
            s.toast = { kind: 'lost', title: 'A bottle spills', body: 'The cap pops open in the fall. Go back to the stream, or carry on with less.', id: Date.now() }
          }
          if (e.k === 'fail') st.mode = 'fail'
          if (e.k === 'exit') { st.mode = 'done'; s.st = 'locked'; st.stars = 1 + (s.slips === 0 ? 1 : 0) + (st.bottles > 0 ? 1 : 0) }
        }
      }
      pad.hop.current = false
      setFrame(f => (f + 1) % 1e6)
      raf = requestAnimationFrame(loop)
    }
    raf = requestAnimationFrame(loop)
    return () => cancelAnimationFrame(raf)
    // pad refs are stable
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [paused, rm, L])

  const st = S.current
  const s = st.sim
  const playing = st.mode === 'play'
  const spring = playing && s.st === 'ground' ? near(s, L, 'F', 44) : null
  const sign = playing && s.st === 'ground' ? near(s, L, 'S', 34) : null
  const act = spring && st.bottles < 2 ? { label: 'FILL', sub: `${st.bottles}/2` } : sign ? { label: 'READ', sub: 'sign' } : null
  const onAct = () => {
    if (!playing) return
    if (spring && st.bottles < 2) {
      st.bottles = 2; st.filled = true
      s.toast = { kind: 'info', title: 'Two litres from the Karanga stream', body: 'The last water before the summit. Each full bottle makes every step a little heavier. DRINK when you need it, or carry it to Barafu.', id: Date.now() }
    } else if (sign) {
      const t = L.signs[`${sign.cx},${sign.cy}`]
      if (t) s.toast = { kind: 'info', title: t.title, body: t.body, id: Date.now() }
    }
  }
  const onRest = () => { if (!playing) return; if (s.st === 'rest') s.st = 'ground'; else tryRest(s, L, 0) }
  const drink = () => {
    if (!playing || st.bottles <= 0 || s.stamina >= s.barMax - 1) return
    st.bottles--; st.drank++
    s.stamina = Math.min(s.barMax, s.stamina + s.barMax * 0.3)
    s.caption = `A long drink: breath back (+${Math.round(s.barMax * 0.3)})`; s.tone = 'good'; s.capT = 1.6
  }
  const restart = () => { S.current = fresh('play') }
  const done = (r: 'complete' | 'retreat' | 'fail') => x.land(r, r === 'complete' ? st.stars : 0)

  const p = Math.max(0, Math.min(1, s.x / (L.w * T)))
  const fog = Math.max(0, Math.min(1, (s.x - FOG_FROM) / (30 * T))) * 0.4
  const meters = Math.round(3995 + ((19 - s.y / T) / 15) * 678)
  const pose: HeroPose = st.mode === 'done' ? 'celebrate' : s.st === 'slip' ? 'fall' : s.st === 'rest' ? 'sit' : s.st === 'climb' ? (Math.floor(s.climbPh) % 2 ? 'climbA' : 'climbB')
    : s.st === 'air' ? 'run' : s.st === 'stun' || (s.exposed && s.wind === 'gust') ? 'brace' : Math.abs(s.vx) > 8 ? 'walk' : 'idle'
  const view = s.st === 'climb' ? 'back' : pose === 'fall' || pose === 'celebrate' ? 'front' : 'side'

  return (
    <div className="absolute inset-0 overflow-hidden bg-[#8796a0]">
      <img src={KARANGA_BG} alt="" draggable={false} className="pointer-events-none absolute top-[-30px] h-[470px] max-w-none" style={{ width: 1180, left: -s.camX * 0.04, transform: `translateY(${-s.camY * 0.05}px)` }} />
      <svg width={915} height={412} className="pointer-events-none absolute inset-0" aria-hidden>
        <path d={`M0 ${300 - s.camY * 0.15} ${Array.from({ length: 13 }).map((_, i) => `L${i * 90 - (s.camX * 0.25) % 90} ${280 + ((i * 37) % 40) - s.camY * 0.15}`).join(' ')} L1000 412 L0 412 Z`} fill="#6a706c" opacity={0.7} />
      </svg>

      <div className="absolute left-0 top-0" style={{ transform: `translate(${-Math.round(s.camX)}px, ${-Math.round(s.camY)}px)` }}>
        <TerrainLayer L={L} pal={KARANGA_PAL} />
        <PropLayer L={L} pal={KARANGA_PAL} />
        <DynLayer L={L} s={s} pal={KARANGA_PAL} rm={rm} />
        <div className="pointer-events-none absolute" style={{ left: s.x - 60 * K, top: s.y + s.lift - 146 * K }}>
          <Hero look={g.look} pose={pose} view={view} size={HERO} kit="trek" facing={s.facing} seat={pose === 'sit'}
            time={pose === 'walk' || pose === 'run' ? s.walkPh : undefined} reducedMotion={rm}
            expression={s.stamina < s.barMax * 0.25 ? 'tired' : s.exposed && s.wind !== 'calm' ? 'worried' : undefined} />
        </div>
        <WaterFront L={L} pal={KARANGA_PAL} />
      </div>

      {/* cloud after the junction (PROPOSED): it thickens, and only the cairns read through it */}
      {fog > 0 && <div className="pointer-events-none absolute inset-0 bg-[#e3e8eb]" style={{ opacity: fog }} />}
      {fog > 0.12 && (L.by.K ?? []).map(m => {
        const sx = m.x - s.camX, sy = m.y - s.camY
        if (sx < -20 || sx > 935 || sy < -20 || sy > 430) return null
        return <svg key={m.key} className="pointer-events-none absolute" style={{ left: sx - 14, top: sy - 34 }} width={28} height={36} aria-hidden><g stroke="#1c1915" strokeWidth={1.4} fill="#a3988a"><ellipse cx={14} cy={30} rx={12} ry={4.5} /><ellipse cx={14} cy={21} rx={9} ry={4} /><ellipse cx={14} cy={13} rx={6} ry={3.2} /></g></svg>
      })}

      <WindStreaks on={s.exposed && s.wind !== 'calm'} strong={s.wind === 'gust'} rm={rm} />

      <EncounterHud title="Karanga Ridge" sub={`${meters.toLocaleString()} m`} stamina={s.stamina} barMax={s.barMax}
        note={`stumbles ${s.slips} of 3`} caption={s.caption} captionTone={s.tone} onPause={() => setPaused(true)}
        right={<RouteRail p={p} />} />
      {st.mode !== 'brief' && (
        <CarryTray gear={s.gear} gearTotal={L.gear.length} artifacts={0} artifactsTotal={0} spotter={null}
          extra={<span className={`inline-flex h-6 items-center gap-1.5 rounded-full px-2 text-[11px] font-medium ring-1 ring-white/10 ${st.bottles > 0 ? 'bg-[#2f5772] text-paper' : 'bg-scrim text-paper/85'}`}><BottleGlyph full={st.bottles > 0} />Water {st.bottles}/2</span>} />
      )}

      {(st.mode === 'play') && (
        <PlatPad refs={pad} act={act} onAct={onAct} resting={s.st === 'rest'} restSub={s.st === 'rest' ? 'stand' : `${s.rests} left`}
          restDisabled={s.st !== 'ground'} onRest={onRest} onKey={k => { if (k === 'b') drink() }}
          extra={<ActionButton x={826} y={236} size={60} tone="scrim" label="DRINK" sub={`${st.bottles} left`} disabled={st.bottles === 0 || s.stamina >= s.barMax - 1} onClick={drink} />} />
      )}

      <FindToast toast={s.toast} rm={rm} onClose={() => { s.toast = null }} />

      {st.mode !== 'brief' && (
        <div className="pointer-events-none absolute left-7 top-[108px] z-20 flex flex-col items-start gap-1">
          <SimTag className="!bg-paper/90">Simulated platformer</SimTag>
          <ApkTag className="!bg-paper/90">Walk · hop · climb · hazards: APK</ApkTag>
          <MechanicTag className="!bg-paper/90">Level, water, cloud: proposed</MechanicTag>
        </div>
      )}

      {st.mode === 'brief' && (
        <BriefCard kicker="Karanga Camp · after breakfast · proposed level" title="Karanga Ridge"
          text="On your own today: the team went ahead with the porters. Down to the Karanga stream for the last water, up the valley wall, then the long rise to Barafu. At the junction the line splits: the bare crest, or the scree traverse beneath it."
          rows={[
            ['Stamina bar (from camp condition)', `${barMax} of 100`, barMax >= 70 ? 'good' : 'warn'],
            ['Water', 'Last at Karanga stream · none at Barafu', 'warn'],
            ['Weather', 'Clear, west wind on the crest, cloud by midday', 'warn'],
            ['Creatures', 'Siafu · nettles · a raven · rolling stones', 'bad'],
            ['Stumbles allowed', '3 (cairns save progress)', 'neutral'],
            ['Engine', 'Lands nothing: your Karanga card already applied', 'neutral'],
          ]}
          existing={[
            'Walk, HOP about two tiles, push UP on a face to climb and top out (Climber)',
            'Edge guard: you never walk off a drop. Falls over 4 tiles are stumbles',
            'Exposed crest: stand still or REST in a gust; a hop in a gust is a stumble',
            'Siafu, nettles, a raven, rolling stones, a cracked slab, cairns + 2 rests',
            'Trekking poles and goggles (existing gear kinds, new placements)',
          ]}
          mechanics={[
            'The level itself: Karanga → Barafu played, not a card result',
            'FILL two bottles at the stream. Each full bottle adds 10% to every step',
            'DRINK a bottle any time for +30% of the bar. A counted stumble spills one',
            'Wade the stream (slow, costs breath) or hop the stepping stones',
            'Cloud after the junction: only the cairns read through it',
            'Third star: reach Barafu with water (this traverse has no artifacts)',
          ]}
          backLabel="Back to camp" onBack={() => done('retreat')} onStart={() => { st.mode = 'play'; s.caption = 'Down to the stream first: the bottles are empty.'; s.tone = 'info'; s.capT = 3 }} rm={rm} />
      )}

      {paused && (
        <Modal kicker="Paused" title="Karanga Ridge" onClose={() => setPaused(false)} width={420}
          footer={<><PaperButton onClick={() => done('retreat')}>Back to Karanga</PaperButton><PrimaryButton className="flex-1" onClick={() => setPaused(false)}>Resume</PrimaryButton></>}>
          <p className="text-[14px] leading-snug text-ink-soft">This traverse is a proposal: leaving it returns you to the map without changing any expedition value.</p>
        </Modal>
      )}

      {st.mode === 'done' && (
        <EncounterResult kicker="Karanga Ridge · proposed level" head="Barafu Camp." sub="High camp. Tents on bare rock, and no water."
          stars={st.stars} facts={[['Time', fmt(s.t)], ['Water', `${st.bottles}/2`], ['Stumbles', String(s.slips)]]}
          lines={[
            `${s.slips === 0 ? 'Star' : 'Missed'}: no stumbles that counted · ${st.bottles > 0 ? 'Star' : 'Missed'}: water carried to Barafu (proposed)`,
            st.filled ? `Filled at the stream · drank ${st.drank} · spilled ${st.spilled}` : 'You never filled the bottles: a dry night at Barafu.',
            ...(s.gear.length ? [`Gear: ${s.gear.map(k => GEAR[k].label.toLowerCase()).join(', ')}`] : []),
            ...(slipSummary(s.causes) ? [slipSummary(s.causes)] : []),
            'No expedition stats change from this traverse.',
          ]}
          primary="Pitch at Barafu" onPrimary={() => done('complete')} onReplay={restart} rm={rm} />
      )}
      {st.mode === 'fail' && (
        <EncounterResult kicker="Karanga Ridge · proposed level" head="Three stumbles." sub="Back down to Karanga for the night."
          stars={0} facts={[['Time', fmt(s.t)], ['Water', `${st.bottles}/2`], ['Stumbles', String(s.slips)]]}
          lines={[slipSummary(s.causes) || 'Three stumbles end the traverse.', 'No expedition stats change from this traverse.']}
          primary="Back to Karanga" onPrimary={() => done('fail')} onReplay={restart} rm={rm} />
      )}
    </div>
  )
}

function RouteRail({ p }: { p: number }) {
  const stops: [number, string][] = [[0, 'Camp'], [0.17, 'Stream'], [0.46, 'Junction'], [1, 'Barafu']]
  return (
    <div className="flex h-12 w-[250px] flex-col justify-center gap-1 rounded-full bg-scrim px-4 ring-1 ring-white/10">
      <div className="relative h-[6px] rounded-full bg-black/40">
        <span className="absolute inset-y-0 left-0 rounded-full bg-route" style={{ width: `${p * 100}%` }} />
        {stops.slice(1, 3).map(([q]) => <span key={q} className="absolute top-1/2 h-3 w-[2px] -translate-y-1/2 bg-paper/70" style={{ left: `${q * 100}%` }} />)}
        <span className="absolute top-1/2 h-3 w-3 -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-ink bg-paper" style={{ left: `${p * 100}%` }} />
      </div>
      <div className="relative h-[10px] text-[10px] leading-none text-paper/80">
        {stops.map(([q, l], i) => <span key={l} className="absolute" style={i === 0 ? { left: 0 } : i === stops.length - 1 ? { right: 0 } : { left: `${q * 100}%`, transform: 'translateX(-50%)' }}>{l}</span>)}
      </div>
    </div>
  )
}

function BottleGlyph({ full }: { full: boolean }) {
  return <svg width={9} height={13} viewBox="0 0 9 13" aria-hidden><rect x={2.5} y={0.5} width={4} height={2.5} rx={0.6} fill="#1c1915" /><rect x={0.8} y={3} width={7.4} height={9.4} rx={2} fill={full ? '#9cc3d6' : 'none'} stroke="#f7f4ee" strokeWidth={1.1} /></svg>
}

function fmt(t: number) { const s = Math.floor(t); return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}` }
