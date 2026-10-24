import React, { useEffect, useMemo, useRef, useState } from 'react'
import { useGame } from '../state/GameState'
import { useExpedition } from '../state/Expedition'
import { Hero, HeroPose } from '../components/Hero'
import { PaperButton, PrimaryButton, SimTag } from '../components/ui'
import { Modal } from '../overlays/Modal'
import { EncounterHud } from '../encounter/EncounterHud'
import { ActionButton, ApkTag, BriefCard, EncounterResult, MechanicTag } from '../encounter/Panels'
import { WindStreaks } from '../encounter/BarrancoArt'
import { CarryTray, FindToast, FirePanel } from '../encounter/StageKit'
import { APK, apkResultLines, apkStars, artifactsFor } from '../encounter/stageData'
import { Marker, Sim, T, freshSim, near, step, tryRest } from '../encounter/plat/engine'
import { SUMMIT_F, buildSummit } from '../encounter/plat/levels'
import { DynLayer, PropLayer, SUMMIT_PAL, TerrainLayer } from '../encounter/plat/TileWorld'
import { PadRefs, PlatPad } from '../encounter/plat/PlatPad'
import { StickV } from '../encounter/Stick'
import { TEAM_LOOKS } from '../encounter/team'

export const SUMMIT_BG = 'https://cdn.magicpatterns.com/patterns/generated-images/9b003b19-5136-4441-8126-941de13ddea8.jpg'

const HERO = 50
const K = HERO / 120
const BEAT = 1.6
const WIN = 0.28
const F0 = SUMMIT_F[0] * T
const TOP = SUMMIT_F[6] * T

type Mode = 'brief' | 'play' | 'fire' | 'summit' | 'done' | 'fail'
interface Stage {
  sim: Sim; mode: Mode; breath: number; winded: number; glove: boolean; gaveGlove: boolean
  talked: Record<string, number>; talkT: Record<string, number>; fires: string[]; fireAt: string
  stars: number; hits: number; misses: number; usedBeat: number; flash: number; summitT: number; thermos: boolean
}

const MATES: Record<string, { name: string; look: number; lines: string[] }> = {
  l: { name: 'Lena', look: 0, lines: ['Lena: You came up on your own lamp. We took the slow line with Jun.', 'Lena: Get to the sign. Then we go down: the top is not the end.'] },
  m: { name: 'Marco', look: 1, lines: ['Marco: Thermos. Drink, even if you don\'t want to.', 'Marco: I\'ve got the camera. Over to the sign when you\'re ready.'] },
  j: { name: 'Jun', look: 2, lines: ['Jun: I dropped a glove on the zigzags. Lena gave me hers.', 'Jun: Count the zigzags with me on the way down.'] },
}

/**
 * CLIMB 3 — Summit night (EXISTING level `summit-night`), played solo as the
 * APK's tile platformer: switchbacks stacked up the cone, joined by loose,
 * face and scramble pitches; holes, ice, the rock-step chute, rim saddles,
 * the lee, Stella Point, then the rim to Uhuru, where the team arrives by the
 * other line. PROPOSED: breathing on the beat, the headlamp cone + line of
 * lamps, Jun's glove and the summit reunion.
 */
export function EncounterSummit() {
  const g = useGame()
  const x = useExpedition()
  const rm = g.settings.reducedMotion
  const barMax = Math.max(48, Math.min(100, Math.round((x.stats.health + x.stats.energy) / 2) + 10))
  const arts = artifactsFor('summit-night', x.routeName)
  const food = x.stats.supplies
  const L = useMemo(buildSummit, [])
  const fresh = (mode: Mode): Stage => ({
    sim: freshSim(L, barMax), mode, breath: 100, winded: 0, glove: false, gaveGlove: false, talked: {}, talkT: {}, fires: [], fireAt: '',
    stars: 0, hits: 0, misses: 0, usedBeat: -1, flash: -9, summitT: 0, thermos: false,
  })
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
      const s = st.sim
      if (!paused && st.mode === 'play') {
        s.speedMul = st.breath < 30 ? 0.7 : 1
        const bx = s.x, by = s.y
        step(s, L, { x: pad.stick.current.x, y: pad.stick.current.y, hop: pad.hop.current }, dt, arts, rm)
        breathe(st, dt, Math.abs(s.x - bx) + Math.abs(s.y - by))
        for (const e of s.events) {
          if (e.k === 'fail') st.mode = 'fail'
          if (e.k === 'hop') st.breath -= 5
          if (e.k === 'find' && e.m.ch === 'g') {
            st.glove = true
            s.toast = { kind: 'info', title: 'Jun\'s glove', body: 'He dropped it on the scree tonight. He is on the slower line with Lena and Marco. Carry it to the top.', id: Date.now() }
          }
        }
        for (const k in st.talkT) st.talkT[k] -= dt
      } else if (st.mode === 'summit') {
        st.summitT += dt
        s.t += dt
        if (st.summitT > 1.9) st.mode = 'done'
      }
      pad.hop.current = false
      setFrame(f => (f + 1) % 1e6)
      raf = requestAnimationFrame(loop)
    }
    raf = requestAnimationFrame(loop)
    return () => cancelAnimationFrame(raf)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [paused, rm, L, arts])

  const st = S.current
  const s = st.sim
  const playing = st.mode === 'play' && s.st === 'ground'
  const prog = Math.max(0, Math.min(1, (F0 - s.y) / (F0 - TOP)))
  const dawn = Math.max(0, Math.min(1, (SUMMIT_F[4] * T - s.y) / ((SUMMIT_F[4] - SUMMIT_F[6]) * T)))
  const tier = Math.max(0, SUMMIT_F.findIndex(f => s.y > (f - 7) * T))
  const hour = prog * 6.3
  const lamp = s.gear.includes('headlamp') ? 185 : 115

  // ACT: the summit board > Jun's glove > a teammate > a cairn fire > a sign
  const board = playing ? near(s, L, 'U', 54) : null
  const mate = playing ? near(s, L, 'lmj', 40) : null
  const cairn = playing ? near(s, L, 'K', 30) : null
  const sign = playing ? near(s, L, 'S', 34) : null
  const fireOk = cairn && (s.visited[cairn.key] ?? 0) > 0 && !st.fires.includes(cairn.key)
  const act = board ? { label: 'SUMMIT', sub: 'photo' }
    : mate ? (mate.ch === 'j' && st.glove && !st.gaveGlove ? { label: 'GIVE', sub: 'glove' } : { label: 'TALK', sub: MATES[mate.ch].name })
    : fireOk ? { label: 'FIRE', sub: '1 hour' } : sign ? { label: 'READ', sub: 'sign' } : null
  const onAct = () => {
    if (!playing) return
    if (board) { st.mode = 'summit'; s.st = 'locked'; st.stars = apkStars('complete', s.slips, s.carried.length, arts.length); s.caption = 'Uhuru Peak at sunrise'; s.tone = 'good'; s.capT = 2; return }
    if (mate) {
      const m = MATES[mate.ch]
      st.talkT[mate.ch] = 2
      if (mate.ch === 'j' && st.glove && !st.gaveGlove) { st.gaveGlove = true; s.caption = 'Jun: My glove! My hands are coming back. Thank you.'; s.tone = 'good'; s.capT = 2.6; return }
      const n = st.talked[mate.ch] ?? 0
      st.talked[mate.ch] = n + 1
      const line = mate.ch === 'j' && st.gaveGlove ? m.lines[1] : m.lines[Math.min(n, m.lines.length - 1)]
      if (mate.ch === 'm' && !st.thermos) { st.thermos = true; st.breath = 100; s.stamina = Math.min(s.barMax, s.stamina + 10) }
      s.caption = line; s.tone = 'info'; s.capT = 2.8
      return
    }
    if (fireOk && cairn) { st.mode = 'fire'; st.fireAt = cairn.key; return }
    if (sign) { const t = L.signs[`${sign.cx},${sign.cy}`]; if (t) s.toast = { kind: 'info', title: t.title, body: t.body, id: Date.now() } }
  }
  const onRest = () => { if (st.mode !== 'play') return; if (s.st === 'rest') s.st = 'ground'; else tryRest(s, L, food) }
  const beatIdx = Math.round(s.t / BEAT)
  const ph = s.t % BEAT
  const inWin = ph < WIN || ph > BEAT - WIN
  const onBreathe = () => {
    if (st.mode !== 'play') return
    if (inWin && st.usedBeat !== beatIdx) { st.usedBeat = beatIdx; st.breath = Math.min(100, st.breath + 16); st.hits++; st.flash = s.t }
    else { st.breath = Math.max(0, st.breath - 3); st.misses++; if (s.capT <= 0) { s.caption = 'On the beat: breathe out when the button lights.'; s.tone = 'warn'; s.capT = 1.4 } }
  }
  const restart = () => { S.current = fresh('play') }
  const done = (r: 'complete' | 'retreat' | 'fail') => x.land(r, r === 'complete' ? st.stars : 0)

  const celebrating = st.mode === 'summit' || st.mode === 'done'
  const pose: HeroPose = celebrating ? 'celebrate' : s.st === 'slip' ? 'fall' : s.st === 'rest' ? 'sit' : s.st === 'climb' ? (Math.floor(s.climbPh) % 2 ? 'climbA' : 'climbB')
    : s.st === 'air' ? 'run' : s.st === 'stun' ? (s.stunT > 0.6 ? 'rest' : 'brace') : s.exposed && s.wind === 'gust' ? 'brace' : Math.abs(s.vx) > 8 ? 'walk' : 'idle'
  const view = s.st === 'climb' && !celebrating ? 'back' : pose === 'fall' || pose === 'celebrate' ? 'front' : 'side'
  const hs: [number, number] = [s.x - s.camX, s.y - s.camY - 34]
  const dir = s.facing
  const spotter = s.spotter ? 'Rope: holds your next slip' : null

  return (
    <div className="absolute inset-0 overflow-hidden bg-[#0b1024]">
      <img src={SUMMIT_BG} alt="" draggable={false} className="pointer-events-none absolute left-0 top-[-20px] h-[460px] w-[915px] object-cover" style={{ transform: `translateY(${-(s.camY / (L.h * T)) * 24}px)` }} />
      <div className="pointer-events-none absolute inset-x-0 top-[120px] h-[26px] bg-[#d8a8b8]" style={{ opacity: dawn * 0.5 }} />
      <div className="pointer-events-none absolute inset-x-0 top-[146px] h-[20px] bg-[#ffd4b8]" style={{ opacity: dawn * 0.65 }} />
      {dawn > 0.5 && <div className="pointer-events-none absolute h-[44px] w-[44px] rounded-full bg-[#ffd37a]" style={{ left: 150, top: 166 - (dawn - 0.5) * 70 }} />}

      <div className="absolute left-0 top-0" style={{ transform: `translate(${-Math.round(s.camX)}px, ${-Math.round(s.camY)}px)` }}>
        <TerrainLayer L={L} pal={SUMMIT_PAL} />
        <PropLayer L={L} pal={SUMMIT_PAL} />
        <DynLayer L={L} s={s} pal={SUMMIT_PAL} rm={rm} glove />
        {st.fires.map(k => { const m = L.markers.find(mm => mm.key === k); return m ? <Fire key={k} m={m} t={s.t} rm={rm} /> : null })}
        {(['l', 'm', 'j'] as const).map((ch, i) => {
          const m = L.by[ch]?.[0]
          if (!m) return null
          return <Mate key={ch} m={m} i={i} s={s} st={st} rm={rm} />
        })}
        <div className="pointer-events-none absolute" style={{ left: s.x - 60 * K, top: s.y + s.lift - 146 * K }}>
          <Hero look={{ ...g.look, headwear: 'headlamp' }} pose={pose} view={view} size={HERO} kit="trek" facing={s.facing} seat={pose === 'sit'}
            time={pose === 'walk' || pose === 'run' ? s.walkPh : undefined} reducedMotion={rm}
            expression={celebrating ? 'happy' : st.breath < 30 ? 'tired' : s.exposed && s.wind !== 'calm' ? 'worried' : undefined} />
        </div>
      </div>

      {/* the dark, with the headlamp cut out (stepped edge, no gradient) */}
      <svg width={915} height={412} className="pointer-events-none absolute inset-0" aria-hidden>
        <defs>
          <mask id="lamp-cone">
            <rect width={915} height={412} fill="white" />
            <circle cx={hs[0]} cy={hs[1]} r={lamp + 26} fill="#8a8a8a" />
            <polygon points={`${hs[0]},${hs[1] - 18} ${hs[0] + dir * (lamp + 110)},${hs[1] - 90} ${hs[0] + dir * (lamp + 110)},${hs[1] + 80}`} fill="#666" />
            <circle cx={hs[0]} cy={hs[1]} r={lamp} fill="black" />
            <polygon points={`${hs[0]},${hs[1] - 14} ${hs[0] + dir * (lamp + 80)},${hs[1] - 66} ${hs[0] + dir * (lamp + 80)},${hs[1] + 58}`} fill="black" />
          </mask>
        </defs>
        <rect width={915} height={412} fill="#060a1a" opacity={0.9 * (1 - dawn)} mask="url(#lamp-cone)" />
        {/* the line of headlamps on the switchbacks above (PROPOSED presentation): it shows the way in the dark */}
        {dawn < 0.9 && SUMMIT_F.slice(tier + 1, 6).flatMap((f, j) => [0, 1].map(i => {
          const k = tier + 1 + j
          const span = 52 * T
          const u = ((s.t * 16 + i * 820 + k * 310) % span) / span
          const wx = (k % 2 === 0 ? u : 1 - u) * span + 5 * T
          const sx = wx - s.camX, sy = f * T - 40 - s.camY
          if (sx < -10 || sx > 925 || sy < -10 || sy > 420) return null
          return <g key={`${k}-${i}`} opacity={1 - dawn}><circle cx={sx} cy={sy} r={6} fill="#ffd37a" opacity={0.18} /><circle cx={sx} cy={sy} r={2.4} fill="#ffd37a" /></g>
        }))}
      </svg>

      <WindStreaks on={s.exposed && s.wind !== 'calm'} strong={s.wind === 'gust'} rm={rm} />

      <EncounterHud title="Summit night" sub={`${String(Math.floor(hour)).padStart(2, '0')}:${String(Math.floor((hour % 1) * 60)).padStart(2, '0')} · ${Math.round(4670 + prog * 1225).toLocaleString()} m`}
        stamina={s.stamina} barMax={s.barMax} note={`slips ${s.slips} of 2`} caption={s.caption} captionTone={s.tone} onPause={() => setPaused(true)}
        right={<BreathMeter breath={st.breath} lit={inWin && st.mode === 'play'} />} />
      {st.mode !== 'brief' && (
        <CarryTray gear={s.gear} gearTotal={L.gear.length} artifacts={s.carried.length} artifactsTotal={arts.length} spotter={spotter}
          extra={st.glove ? <span className="inline-flex h-6 items-center rounded-full bg-[#7a5410] px-2 text-[11px] font-medium text-paper">{st.gaveGlove ? 'Glove returned' : 'Jun\'s glove'}</span> : null} />
      )}

      {st.mode === 'play' && (
        <>
          <PlatPad refs={pad} act={act} onAct={onAct} resting={s.st === 'rest'} onRest={onRest} restDisabled={s.st !== 'ground'}
            restSub={s.st === 'rest' ? 'stand' : s.rests > 0 ? `${s.rests} left` : food - s.snacks * APK.SNACK >= APK.SNACK ? 'snack' : 'none'}
            onKey={k => { if (k === 'b') onBreathe() }}
            extra={<>
              {!rm && <BeatRing ph={ph} />}
              <ActionButton x={826} y={236} size={60} tone={inWin ? 'route' : 'scrim'} label="BREATHE" sub="on the beat" onDown={onBreathe} />
            </>} />
        </>
      )}

      <FindToast toast={s.toast} rm={rm} onClose={() => { s.toast = null }} />

      {st.mode !== 'brief' && (
        <div className="pointer-events-none absolute left-7 top-[108px] z-20 flex flex-col items-start gap-1">
          <SimTag className="!bg-paper/90">Simulated platformer</SimTag>
          <ApkTag className="!bg-paper/90">Level, hazards, gear, finds: APK</ApkTag>
          <MechanicTag className="!bg-paper/90">Breathing, lamp, reunion: proposed</MechanicTag>
        </div>
      )}

      {st.mode === 'brief' && (
        <BriefCard kicker="Barafu · midnight · played climb (summit_night)" title="Summit night"
          text="Midnight, alone on your own lamp. The team is taking the slower line with Jun and will meet you at the top. Zigzag up the cone: hop the holes, climb each pitch, keep off the ice until you have crampons, and breathe on the beat."
          rows={[
            ['Stamina bar (from camp condition)', `${barMax} of 100`, barMax >= 70 ? 'good' : 'warn'],
            ['Temperature', '−7 °C, −16 °C before dawn', 'bad'],
            ['Dangers', 'Ice · holes · stones on the rock step · cracked slabs', 'bad'],
            ['Gear on the way', 'Rope · crampons · headlamp · helmet · goggles', 'good'],
            ['Artifacts', `${arts.length} on this route · 6 leader points each`, 'good'],
            ['Slips allowed', '2 (existing maxSlips)', 'warn'],
          ]}
          existing={[
            'Switchbacks joined by loose, face and scramble pitches; holes in the floors (summit_night.txt)',
            'Ice without crampons: no edge guard, you slide. Falls over 4 tiles are slips',
            'Stones down the rock step: a slip, or −12 with the helmet',
            'Rim saddles in the wind, the lee cairn and rest stone, cracked slabs',
            'Gear in the APK order and copy, 2 artifacts, fires, rests then snacks, the cold until the headlamp',
          ]}
          mechanics={[
            'Solo: Jun\'s mid-climb help beat moves to the summit reunion',
            'BREATHE on the beat: moving drains breath; empty means a forced stop',
            'Headlamp cone hides what is outside it; a line of lamps above shows the way',
            'Jun\'s glove on a ledge off the switchbacks: carry it up and GIVE it back',
            'Reunion at Uhuru: TALK to Lena, Marco and Jun, then the summit photo',
            'Engine: GIVE would set ChallengeOutcome.assisted (today: helping Jun mid-climb)',
          ]}
          backLabel="Turn the headlamp around" onBack={() => done('retreat')}
          onStart={() => { st.mode = 'play'; s.caption = 'Breathe out on the beat, step on the breath. Pole pole.'; s.tone = 'info'; s.capT = 3 }} rm={rm} />
      )}

      {st.mode === 'fire' && (
        <FirePanel where="The cairn" onClose={() => { st.mode = 'play' }}
          onFire={() => { st.fires.push(st.fireAt); s.stamina = s.barMax; st.breath = 100; s.rests = APK.REST_LIMIT; s.restOpen = false; st.mode = 'play'; s.caption = `A fire and a hot drink: full stamina. The expedition is ${st.fires.length} hour${st.fires.length > 1 ? 's' : ''} later.`; s.tone = 'good'; s.capT = 3 }} />
      )}

      {paused && (
        <Modal kicker="Paused" title="Summit night" onClose={() => setPaused(false)} width={420}
          footer={<><PaperButton onClick={() => done('retreat')}>Back down to Barafu</PaperButton><PrimaryButton className="flex-1" onClick={() => setPaused(false)}>Resume</PrimaryButton></>}>
          <p className="text-[14px] leading-snug text-ink-soft">If anyone turns around tonight, the whole party turns with them. Turning back costs the day, not the expedition.</p>
        </Modal>
      )}

      {st.mode === 'done' && (
        <EncounterResult kicker="Uhuru Peak · 5,895 m" head="The roof of Africa." sub="The top is not the end. The walk down starts here."
          stars={st.stars} facts={[['Time', fmt(s.t)], ['Artifacts', `${s.carried.length}/${arts.length}`], ['Slips', String(s.slips)]]}
          lines={[
            ...apkResultLines({ slips: s.slips, artifacts: s.carried.length, total: arts.length, fires: st.fires.length, snacks: s.snacks, gear: s.gear, gearTotal: L.gear.length, hurt: s.hurt, causes: s.causes }),
            `${st.gaveGlove ? 'You gave Jun his glove back at the top' : 'Jun\'s glove stayed on the mountain'} · winded ${st.winded}× · on the beat ${st.hits}×`,
          ]}
          primary="Decide the descent" onPrimary={() => done('complete')} onReplay={restart} rm={rm} />
      )}
      {st.mode === 'fail' && (
        <EncounterResult kicker="Summit night" head="The mountain kept the summit tonight." sub="Back down to Barafu."
          stars={0} facts={[['Time', fmt(s.t)], ['Winded', String(st.winded)], ['Slips', String(s.slips)]]}
          lines={['Two slips end the attempt on summit night. The gear goes back where it was found; artifacts carried stay on the mountain.', ...apkResultLines({ slips: s.slips, artifacts: 0, total: arts.length, fires: st.fires.length, snacks: s.snacks, gear: [], gearTotal: 0, hurt: s.hurt, causes: s.causes }).slice(1)]}
          primary="Back to Barafu" onPrimary={() => done('fail')} onReplay={restart} rm={rm} />
      )}
    </div>
  )
}

/** PROPOSED · pressure breathing: moving drains breath (more in thin air and on rock); standing and sitting give it back. Empty on open ground is a forced stop. */
function breathe(st: Stage, dt: number, moved: number) {
  const s = st.sim
  const thin = 1 + Math.max(0, (F0 - s.y) / (F0 - TOP)) * 0.5
  if (s.st === 'rest') st.breath += 30 * dt
  else if (s.st === 'climb' && moved > 0.2) st.breath -= 6 * thin * dt
  else if (s.st === 'ground' && moved > 0.3) st.breath -= 4 * thin * dt
  else if (s.st === 'stun') st.breath += 16 * dt
  else st.breath += 8 * dt
  if (st.breath <= 0 && s.st === 'ground') {
    st.breath = 0; st.winded++
    s.st = 'stun'; s.stunT = 2.4; s.vx = 0
    s.caption = 'Out of breath. Stop. Breathe out on the beat.'; s.tone = 'bad'; s.capT = 2.4
  }
  st.breath = Math.max(0, Math.min(100, st.breath))
}

function Mate({ m, i, s, st, rm }: { key?: React.Key; m: Marker; i: number; s: Sim; st: Stage; rm: boolean }) {
  const info = MATES[m.ch]
  const celebrating = st.mode === 'summit' || st.mode === 'done'
  const board = 56 * T + T / 2
  const mx = celebrating ? board - 70 + i * 30 : m.x
  const close = Math.abs(s.x - m.x) < 8 * T && Math.abs(s.y - m.y) < 2 * T
  const talking = (st.talkT[m.ch] ?? 0) > 0
  const pose: HeroPose = celebrating ? 'celebrate' : talking ? 'talk' : close && !(st.talked[m.ch] ?? 0) ? 'wave' : 'idle'
  const facing: 1 | -1 = s.x < mx ? -1 : 1
  return (
    <div className="pointer-events-none absolute" style={{ left: mx - 60 * K, top: m.y - 146 * K }}>
      <Hero look={{ ...TEAM_LOOKS[info.look], headwear: 'headlamp' }} pose={pose} view={celebrating ? 'front' : 'side'} size={HERO} kit="trek" facing={facing} phase={i * 0.7} reducedMotion={rm}
        expression={celebrating ? 'happy' : talking ? 'talk' : undefined} />
      {close && !celebrating && <div className="world-text absolute left-1/2 top-[-8px] -translate-x-1/2 whitespace-nowrap text-[11px] font-semibold text-paper">{info.name}</div>}
    </div>
  )
}

function Fire({ m, t, rm }: { key?: React.Key; m: Marker; t: number; rm: boolean }) {
  const f = rm ? 0 : Math.sin(t * 14) * 1.5
  return (
    <svg className="pointer-events-none absolute" style={{ left: m.x + 10, top: m.y - 24 }} width={24} height={26} aria-hidden>
      <path d="M2 24 L22 24" stroke="#3a2a22" strokeWidth={3} strokeLinecap="round" />
      <path d={`M6 23 Q5 ${13 + f} 12 ${4 - f} Q19 ${13 + f} 18 23 Z`} fill="#d9572b" />
      <path d={`M9 23 Q9 17 12 ${12 + f} Q15 17 15 23 Z`} fill="#ffd37a" />
    </svg>
  )
}

function BreathMeter({ breath, lit }: { breath: number; lit: boolean }) {
  const word = breath >= 60 ? 'Even' : breath >= 30 ? 'Short' : 'Gasping'
  const fill = breath >= 60 ? 'bg-stam-high' : breath >= 30 ? 'bg-stam-mid' : 'bg-stam-low'
  return (
    <div className="flex h-12 w-[220px] flex-col justify-center gap-1 rounded-[24px] bg-scrim px-4 ring-1 ring-white/10">
      <div className="flex items-center gap-2">
        <div className="relative h-[8px] flex-1 overflow-hidden rounded-full bg-black/45">
          <span className={`absolute inset-y-0 left-0 rounded-full ${fill}`} style={{ width: `${breath}%` }} />
        </div>
        <span className={`h-2.5 w-2.5 rounded-full ${lit ? 'bg-route' : 'bg-white/20'}`} aria-label={lit ? 'Breathe now' : 'Wait for the beat'} />
      </div>
      <div className="flex justify-between text-[10px] leading-none text-paper/85">
        <span>Breath · <span className="font-semibold">{word}</span></span>
        <span className="tabular">{Math.round(breath)}%</span>
      </div>
    </div>
  )
}

/** The beat as a closing ring around BREATHE (off under reduced motion; the button's colour carries it). */
function BeatRing({ ph }: { ph: number }) {
  const k = 1 - ph / BEAT
  const c = 2 * Math.PI * 36
  return (
    <svg className="pointer-events-none absolute z-20" style={{ left: 826 - 40, top: 236 - 40 }} width={80} height={80} aria-hidden>
      <circle cx={40} cy={40} r={36} fill="none" stroke="rgb(255 255 255 / 0.15)" strokeWidth={3} />
      <circle cx={40} cy={40} r={36} fill="none" stroke="#e9c46a" strokeWidth={3} strokeDasharray={`${c * k} ${c}`} transform="rotate(-90 40 40)" />
    </svg>
  )
}

function fmt(t: number) { const s = Math.floor(t); return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}` }
