import React, { useEffect, useRef, useState } from 'react'
import { useGame } from '../state/GameState'
import { useExpedition } from '../state/Expedition'
import { Hero, heroHipPx } from '../components/Hero'
import { PaperButton, PrimaryButton, SimTag } from '../components/ui'
import { Modal } from '../overlays/Modal'
import { EncounterHud } from '../encounter/EncounterHud'
import { Stick, StickV } from '../encounter/Stick'
import { ActionButton, BriefCard, EncounterResult, MechanicTag } from '../encounter/Panels'
import { WallArt, HoldGlyph, StoneFall, WindStreaks, DistantClimbers } from '../encounter/BarrancoArt'
import { ArtifactFind, CarryTray, DecidePanel, FindToast, FirePanel, GearFind, RavenSprite, Toast } from '../encounter/StageKit'
import { APK, GEAR, GearKind, Raven, SlipCause, apkResultLines, apkStars, artifactsFor, freshRaven } from '../encounter/stageData'
import {
  CHECKPOINTS, COST, DRAIN, GULLY_BAND, GULLY_X, GUST_BAND, HOLDS, METERS, TOP, WALL_H,
} from '../encounter/barrancoData'

export const BARRANCO_BG = 'https://cdn.magicpatterns.com/patterns/generated-images/c51944e8-6995-4e59-98e7-085ab3bff6cb.jpg'

type Mode = 'brief' | 'climb' | 'rest' | 'slip' | 'mantle' | 'marco' | 'decide' | 'fire' | 'done' | 'fail'
type P = [number, number]
interface Limbs { hL: number; hR: number; fL: number; fR: number }

const HERO = 170
const K = HERO / 120
const SHOULDER = 36
const ARM_REACH = 120

/** Finds on the wall, each on a hold (APK places gear "before what it helps with", artifacts on the worst ground). */
const FINDS: { kind: 'gear' | 'artifact'; gear?: GearKind; art?: number; hold: number }[] = [
  { kind: 'gear', gear: 'gloves', hold: 5 },      // off left under the first faces
  { kind: 'gear', gear: 'rope', hold: 10 },       // on ledge 1
  { kind: 'gear', gear: 'shell', hold: 13 },      // where the wind starts
  { kind: 'artifact', art: 0, hold: 16 },         // past the cracked block, in the gust band
  { kind: 'gear', gear: 'helmet', hold: 24 },     // foot of the gully, off to the right
  { kind: 'artifact', art: 1, hold: 27 },         // inside the stone column
]
const GEAR_TOTAL = FINDS.filter(f => f.kind === 'gear').length
/** Prototype estimate of each face's cost from its ledge (Godot computes face_cost() from the map). */
const FACE_COST = [34, 42, 46, 40]
const RAVEN_HOME: P = [640, 200]
const RAVEN_BELOW = 372

/**
 * CLIMB 1 — Barranco Wall. Hold-choice faces (proposed) on top of the APK's
 * ClimbLevel rules: gear and artifacts on the wall, stones down the gully
 * (a hit is a slip unless you found the helmet), gusts on the traverse, a
 * raven over the last face, Marco and the decide panel, fires and snacks.
 * Simulated: nothing here is Godot logic.
 */
export function EncounterBarranco() {
  const g = useGame()
  const x = useExpedition()
  const rm = g.settings.reducedMotion
  const barMax = Math.max(48, Math.min(100, Math.round((x.stats.health + x.stats.energy) / 2) + 15))
  const arts = artifactsFor('barranco-wall', x.routeName)
  const food = x.stats.supplies
  const hip0 = heroHipPx(g.build, HERO)

  const S = useRef(fresh(barMax, 0))
  const [, setFrame] = useState(0)
  const stick = useRef<StickV>({ x: 0, y: 0 })
  const [paused, setPaused] = useState(false)

  useEffect(() => {
    let raf = 0, last = performance.now()
    const step = (now: number) => {
      const dt = Math.min(0.05, (now - last) / 1000); last = now
      if (!paused) tick(S.current, dt, rm, arts)
      setFrame(f => (f + 1) % 1e6)
      raf = requestAnimationFrame(step)
    }
    raf = requestAnimationFrame(step)
    return () => cancelAnimationFrame(raf)
  }, [paused, rm, arts])

  const s = S.current
  const reach = reachable(s)
  const aimed = s.mode === 'climb' ? aim(s, reach, stick.current) : null
  const ledge = ledgeAt(s.limbs)
  const onLedge = ledge >= 0
  const restReady = s.mode === 'climb' && onLedge && s.stamina < s.barMax - 1
  const fireReady = s.mode === 'climb' && ledge > 0 && ledge === s.checkpoint && !s.fires.includes(ledge)
  const hipNow = s.disp.hip
  const meters = Math.round(METERS[0] + (1 - (hipNow[1] - 95) / (WALL_H - 95)) * (METERS[1] - METERS[0]))

  const tap = (i: number) => tryMove(s, i, arts)
  const restart = () => { S.current = fresh(barMax, 1) }
  const done = (result: 'complete' | 'retreat' | 'fail') => x.land(result, result === 'complete' ? s.stars : 0)

  const hip = s.disp.hip
  const rel = (p: P, dy = 0): P => [(p[0] - hip[0]) / K, (p[1] + dy - hip[1]) / K]
  const handsAvgX = (s.disp.hL[0] + s.disp.hR[0]) / 2
  const sitting = s.mode === 'rest'
  const falling = s.mode === 'slip'
  const topped = s.mode === 'done'
  const spotter = s.spotter === 'rope' ? 'Rope: Lena holds your next slip' : s.spotter === 'marco' ? 'Marco will catch your next slip' : null
  const restLabel = s.mode === 'rest' ? 'UP' : 'REST'
  const restSub = s.mode === 'rest' ? 'stand' : s.rests > 0 ? `${s.rests} left` : food - s.snacks * APK.SNACK >= APK.SNACK ? 'snack' : 'none'

  return (
    <div className="absolute inset-0 overflow-hidden bg-[#3a3a36]">
      <img src={BARRANCO_BG} alt="" draggable={false} className="pointer-events-none absolute left-0 top-[-40px] h-[500px] w-[915px] object-cover" style={{ transform: `translateY(${(s.cam / (WALL_H - 412)) * 30}px)` }} />
      <DistantClimbers t={s.t} />

      <div className="absolute left-0 top-0 w-[915px]" style={{ height: WALL_H, transform: `translateY(${-s.cam}px)` }}>
        <WallArt />
        <svg width={915} height={WALL_H} className="absolute inset-0">
          {HOLDS.map((h, i) => (
            <HoldGlyph key={i} h={h} i={i} reachable={reach.includes(i)} aimed={aimed === i} used={Object.values(s.limbs).includes(i)}
              onTap={() => tap(i)} broken={s.broken.includes(i)} tested={s.tested.includes(i)} />
          ))}
          {s.finds.map((f, i) => {
            if (f.taken) return null
            const h = HOLDS[f.hold]
            const near = reach.includes(f.hold)
            return f.kind === 'artifact'
              ? <ArtifactFind key={i} x={h.x + 17} y={h.y - 13} near={near} />
              : <GearFind key={i} x={h.x + 17} y={h.y - 13} near={near} label={GEAR[f.gear!].label} />
          })}
          {/* the last ledge's fire, once made */}
          {s.fires.map(c => <Fire key={c} x={HOLDS[CHECKPOINTS[c].limbs[1]].x + 40} y={CHECKPOINTS[c].y} rm={rm} t={s.t} />)}
          <StoneFall stone={s.stone} gully={GULLY_X} band={GULLY_BAND} rm={rm} />
          {hip[1] < RAVEN_BELOW + 160 && <RavenSprite r={s.raven} home={RAVEN_HOME} rm={rm} />}
        </svg>

        {/* Marco: waits on the gully ledge; climbs behind you once helped (APK · Companion.helped/catch_up) */}
        {s.marco !== 'left' && (
          <div className="pointer-events-none absolute" style={{ left: s.marcoPos[0] - 26, top: s.marcoPos[1] - 146 * (52 / 120) }}>
            <Hero look={MARCO} pose={s.marco === 'helped' ? (topped ? 'celebrate' : 'climb') : 'brace'} view={s.marco === 'helped' && !topped ? 'back' : 'side'} size={52} facing={1} kit="climb" phase={s.t * 0.8} reducedMotion={rm} expression={s.marco === 'helped' ? 'happy' : 'worried'} />
          </div>
        )}

        <div className="pointer-events-none absolute" style={sitting || topped
          ? { left: hip[0] - 60 * K, top: (sitting ? s.restY : 95) - 146 * K }
          : { left: hip[0] - hip0[0], top: hip[1] - hip0[1] }}>
          {sitting ? (
            <Hero look={g.look} pose="sit" view="side" size={HERO} seat reducedMotion={rm} />
          ) : topped ? (
            <Hero look={g.look} pose="celebrate" view="front" size={HERO} reducedMotion={rm} />
          ) : falling ? (
            <Hero look={g.look} pose="fall" view="back" size={HERO} reducedMotion={rm} />
          ) : (
            <Hero look={g.look} pose={s.mode === 'mantle' ? 'mantle' : 'climb'} view="back" size={HERO} reducedMotion={rm}
              lean={Math.max(-12, Math.min(12, (handsAvgX - hip[0]) * 0.3 + (s.testT > 0 ? 6 : 0)))}
              expression={s.stamina < s.barMax * 0.3 ? 'effort' : (s.wind === 'gust' && inBand(hip[1], GUST_BAND)) || s.raven.phase === 'call' ? 'worried' : undefined}
              targets={s.mode === 'mantle' ? undefined : { hL: rel(s.disp.hL), hR: rel(s.disp.hR), fL: rel(s.disp.fL, -6), fR: rel(s.disp.fR, -6) }} />
          )}
        </div>
      </div>

      <WindStreaks on={s.wind !== 'calm' && inBand(hip[1], GUST_BAND)} strong={s.wind === 'gust'} rm={rm} />

      <EncounterHud
        title="Barranco Wall"
        sub={`${meters.toLocaleString()} m`}
        stamina={s.stamina}
        barMax={s.barMax}
        note={`slips ${s.slips} of 3`}
        caption={s.caption}
        captionTone={s.captionTone}
        onPause={() => setPaused(true)}
        right={<VerticalRail hipY={hip[1]} />}
      />
      {s.mode !== 'brief' && <CarryTray gear={s.gear} gearTotal={GEAR_TOTAL} artifacts={s.carried.length} artifactsTotal={arts.length} spotter={spotter} />}

      {(s.mode === 'climb' || s.mode === 'rest') && (
        <>
          <Stick onChange={v => { stick.current = v; if (S.current.mode === 'rest' && (Math.abs(v.x) > 0.3 || Math.abs(v.y) > 0.3)) S.current.mode = 'climb' }} zoneW={300} zoneH={250} label="Aim a reach" />
          {s.mode === 'climb' && reach.length === 0 ? (
            <ActionButton x={826} y={340} label="DOWN" sub="to last ledge" tone="route" onClick={() => { respawn(s); say(s, 'You climb back down to the ledge and look again.', 'info', 2) }} />
          ) : (
            <ActionButton x={826} y={340} label={aimed !== null ? 'REACH' : 'AIM'} sub={aimed !== null ? holdWord(s, aimed) : 'or tap a hold'} tone={aimed !== null && s.tested.includes(aimed) && HOLDS[aimed].type === 'loose' ? 'route' : 'paper'}
              disabled={aimed === null} onClick={() => aimed !== null && tap(aimed)} />
          )}
          {/* TEST: load a hold before trusting it (proposed). Grit and a creak give a cracked one away. */}
          <ActionButton x={826} y={250} size={60} tone="scrim" label="TEST" sub={aimed !== null ? '−2' : 'aim first'} disabled={aimed === null || s.testT > 0}
            onClick={() => aimed !== null && testHold(s, aimed)} />
          <ActionButton x={736} y={362} size={60} tone="scrim" label={restLabel} sub={restSub} disabled={!restReady && s.mode !== 'rest'}
            onClick={() => { if (s.mode === 'rest') s.mode = 'climb'; else if (restReady) startRest(s, food) }} />
          {fireReady && <ActionButton x={652} y={370} size={56} tone="scrim" label="FIRE" sub="1 hour" onClick={() => { s.mode = 'fire' }} />}
          {s.mode === 'climb' && s.marco === 'waiting' && s.marcoCool && ledge === 3 && (
            <ActionButton x={736} y={284} size={60} tone="route" label="HELP" sub="Marco" onClick={() => { s.mode = 'marco' }} />
          )}
        </>
      )}

      <FindToast toast={s.toast} rm={rm} onClose={() => { s.toast = null }} />

      {/* prototype markers: clear of the stick label and the right-hand action buttons; the brief carries its own */}
      {s.mode !== 'brief' && (
        <div className="pointer-events-none absolute bottom-3 left-[312px] z-20 flex flex-col items-start gap-1">
          <SimTag className="!bg-paper/90">Simulated climb</SimTag>
          <MechanicTag className="!bg-paper/90">Hold-choice + TEST proposed</MechanicTag>
          <MechanicTag className="!bg-paper/90">Finds, raven, fire from APK</MechanicTag>
        </div>
      )}

      {s.mode === 'brief' && (
        <BriefCard
          kicker="Barranco Camp · morning · played climb"
          title="The Barranco Wall"
          text="A steep morning scramble. Choose each hand hold; your feet follow. Gear is tucked on the wall before what it helps with, and two pieces of history sit on the worst ground. REST on ledges. Don't move in a gust. Marco is somewhere above you."
          rows={[
            ['Stamina bar (from camp condition)', `${barMax} of 100`, barMax >= 70 ? 'good' : 'warn'],
            ['Weather', '14 °C at camp, 1 °C at the top · gusts on the ledge', 'warn'],
            ['Dangers', 'Stones down the gully (a hit is a slip) · cracked holds · a raven', 'bad'],
            ['Gear on the wall', 'Gloves · rope · goggles · helmet', 'good'],
            ['Artifacts', `${arts.length} on this route · 6 leader points each`, 'good'],
            ['Rests', '2 between ledges, then camp food (supplies −3)', 'neutral'],
          ]}
          mechanics={['TEST a hold before you load it: −2, and a cracked one shows itself', 'Leaving a ledge tells you what the next face costs', 'A raven dives where you hang still: keep moving under it', 'A counted slip drops the artifacts you carry']}
          backLabel="Back off"
          onBack={() => done('retreat')}
          onStart={() => { s.mode = 'climb'; say(s, 'Hands on rock, feet on rock, nothing in a hurry. — Lena', 'info', 3) }}
          rm={rm}
        />
      )}

      {s.mode === 'marco' && (
        <Modal kicker="Gully ledge · existing teammate beat" title="Marco has stopped on the ledge" width={480}
          footer={<>
            <PaperButton onClick={() => { s.marcoCool = true; s.mode = 'climb'; say(s, 'You step back. Marco is still there.', 'info', 2) }} className="px-3">Step back</PaperButton>
            <PaperButton onClick={() => { s.marco = 'left'; s.mode = 'decide' }}>Leave him for Lena</PaperButton>
            <PrimaryButton className="flex-1" disabled={s.stamina < 15} onClick={() => { s.marco = 'helped'; s.spotter = 'marco'; s.stamina -= 15; s.mode = 'decide'; s.toast = { kind: 'info', title: 'Marco is moving', body: 'He climbs behind you now, and he will catch your next slip.', id: Date.now() } }}>
              {s.stamina < 15 ? 'Help (need 15: rest first)' : 'Free his pack · −15'}
            </PrimaryButton>
          </>}>
          <p className="text-[14px] leading-snug text-ink-soft">His pack is wedged against the rock and he has frozen above the drop. Helping costs 15 stamina now; he would climb behind you after, and catch you if you slip. Lena is an hour behind.</p>
        </Modal>
      )}

      {s.mode === 'decide' && (
        <DecidePanel
          title={s.marco === 'helped' ? 'Marco is moving again. Now what?' : 'Lena will bring Marco. Now what?'}
          mate={s.marco === 'helped' ? 'Marco climbs behind you now.' : 'Marco waits for Lena. You are on your own from here.'}
          body="The loose gully above is the last of the wall."
          breath={Math.round((s.stamina / s.barMax) * 100)}
          retreatLabel="Back off"
          onContinue={() => { s.mode = 'climb' }}
          onRegroup={() => { s.regrouped = true; s.stamina = s.barMax; s.rests = APK.REST_LIMIT; s.mode = 'climb'; say(s, 'The party catches up. About an hour passes.', 'good', 2.4) }}
          onRetreat={() => done('retreat')}
        />
      )}

      {s.mode === 'fire' && (
        <FirePanel where={CHECKPOINTS[s.checkpoint].name} mate={s.marco === 'helped' ? 'Marco' : undefined}
          onClose={() => { s.mode = 'climb' }}
          onFire={() => { s.fires.push(s.checkpoint); s.stamina = s.barMax; s.rests = APK.REST_LIMIT; s.mode = 'climb'; say(s, `A fire on the ledge: full stamina and fresh rests. The expedition is ${s.fires.length} hour${s.fires.length > 1 ? 's' : ''} later.`, 'good', 3) }} />
      )}

      {paused && (
        <Modal kicker="Paused" title="Barranco Wall" onClose={() => setPaused(false)} width={420}
          footer={<><PaperButton onClick={() => done('retreat')}>Back off to Barranco</PaperButton><PrimaryButton className="flex-1" onClick={() => setPaused(false)}>Resume</PrimaryButton></>}>
          <p className="text-[14px] leading-snug text-ink-soft">Turning back is always open. It costs the day, not the expedition. What you carry down is yours; progress saves at the last ledge.</p>
        </Modal>
      )}

      {s.mode === 'done' && (
        <EncounterResult
          kicker="Barranco Wall · played climb" head="Over the top." sub="Karanga is ahead."
          stars={s.stars}
          facts={[['Time', fmt(s.t)], ['Artifacts', `${s.carried.length}/${arts.length}`], ['Slips', String(s.slips)]]}
          lines={[
            ...apkResultLines({ slips: s.slips, artifacts: s.carried.length, total: arts.length, fires: s.fires.length, snacks: s.snacks, gear: s.gear, gearTotal: GEAR_TOTAL, hurt: s.hurt, causes: s.causes }),
            `${s.marco === 'helped' ? 'Marco came off the wall with you' : 'Lena brought Marco up behind you'}${s.caught ? ` · ${s.caught} slip${s.caught > 1 ? 's' : ''} caught` : ''}${s.regrouped ? ' · regrouped' : ''}`,
          ]}
          primary={x.pending?.choice ? 'On to Karanga' : 'Back to the map'}
          onPrimary={() => done('complete')} onReplay={restart} rm={rm}
        />
      )}
      {s.mode === 'fail' && (
        <EncounterResult
          kicker="Barranco Wall · played climb" head="The wall said no today." sub="Back to Barranco."
          stars={0} facts={[['Time', fmt(s.t)], ['Moves', String(s.moves)], ['Slips', String(s.slips)]]}
          lines={['Three slips end the attempt. The gear goes back where it was found; artifacts carried stay on the wall.', ...apkResultLines({ slips: s.slips, artifacts: 0, total: arts.length, fires: s.fires.length, snacks: s.snacks, gear: [], gearTotal: 0, hurt: s.hurt, causes: s.causes }).slice(1)]}
          primary="Back to camp" onPrimary={() => done('fail')} onReplay={restart} rm={rm}
        />
      )}
    </div>
  )
}

/* ---------------------------------------------------------------- simulation */

interface Sim {
  mode: Mode
  limbs: Limbs
  prev: Limbs | null
  logical: { hip: P; hL: P; hR: P; fL: P; fR: P }
  disp: { hip: P; hL: P; hR: P; fL: P; fR: P }
  cam: number
  stamina: number
  barMax: number
  lowest: number
  rests: number
  rested: number
  restY: number
  slips: number
  caught: number
  moves: number
  stars: number
  t: number
  checkpoint: number
  warnedFrom: number
  wind: 'calm' | 'rising' | 'gust'
  windT: number
  stone: { phase: 'idle' | 'warn' | 'fall'; t: number }
  caption: string | null
  captionTone: 'info' | 'warn' | 'bad' | 'good'
  captionT: number
  broken: number[]
  tested: number[]
  testT: number
  slipT: number
  mantleT: number
  pendingFeet: number
  marco: 'waiting' | 'helped' | 'left'
  marcoCool: boolean
  marcoPos: P
  gear: GearKind[]
  finds: { kind: 'gear' | 'artifact'; gear?: GearKind; art?: number; hold: number; taken: boolean }[]
  carried: number[]
  spotter: 'rope' | 'marco' | null
  raven: Raven
  ravenCall: number
  lastMove: number
  fires: number[]
  snacks: number
  hurt: number
  regrouped: boolean
  causes: Partial<Record<SlipCause, number>>
  toast: Toast | null
  toastT: number
}

function fresh(barMax: number, startMode: 0 | 1): Sim {
  const c = CHECKPOINTS[0]
  const limbs = { fL: c.limbs[0], fR: c.limbs[1], hL: c.limbs[2], hR: c.limbs[3] }
  const pos = positions(limbs)
  return {
    mode: startMode ? 'climb' : 'brief', limbs, prev: null, logical: pos, disp: clone(pos), cam: WALL_H - 412,
    stamina: barMax, barMax, lowest: 100, rests: APK.REST_LIMIT, rested: 0, restY: 0, slips: 0, caught: 0, moves: 0, stars: 0, t: 0, checkpoint: 0, warnedFrom: -1,
    wind: 'calm', windT: 0, stone: { phase: 'idle', t: 0 }, caption: null, captionTone: 'info', captionT: 0,
    broken: [], tested: [], testT: 0, slipT: 0, mantleT: 0, pendingFeet: -1, marco: 'waiting', marcoCool: false, marcoPos: [520, 411],
    gear: [], finds: FINDS.map(f => ({ ...f, taken: false })), carried: [], spotter: null, raven: freshRaven(), ravenCall: 0, lastMove: 0,
    fires: [], snacks: 0, hurt: 0, regrouped: false, causes: {}, toast: null, toastT: 0,
  }
}

function tick(s: Sim, dt: number, rm: boolean, arts: [string, string][]) {
  const k = rm ? 1 : 1 - Math.exp(-dt / (s.mode === 'slip' ? 0.05 : 0.075))
  ;(['hip', 'hL', 'hR', 'fL', 'fR'] as const).forEach(key => {
    s.disp[key] = [s.disp[key][0] + (s.logical[key][0] - s.disp[key][0]) * k, s.disp[key][1] + (s.logical[key][1] - s.disp[key][1]) * k]
  })
  const camTarget = clamp(s.disp.hip[1] - 250, 0, WALL_H - 412)
  s.cam += (camTarget - s.cam) * (rm ? 1 : 1 - Math.exp(-dt / 0.12))
  if (s.captionT > 0) { s.captionT -= dt; if (s.captionT <= 0) s.caption = null }
  if (s.toast) { s.toastT += dt; if (s.toastT > (s.toast.kind === 'artifact' ? 5 : 3)) { s.toast = null; s.toastT = 0 } } else s.toastT = 0
  if (s.testT > 0) s.testT -= dt
  // Marco climbs behind and below you once helped
  if (s.marco === 'helped') {
    const want: P = s.mode === 'done' ? [560, 95] : [s.disp.hip[0] - 46, s.disp.hip[1] + 118]
    const mk = rm ? 1 : 1 - Math.exp(-dt / 0.45)
    s.marcoPos = [s.marcoPos[0] + (want[0] - s.marcoPos[0]) * mk, s.marcoPos[1] + (want[1] - s.marcoPos[1]) * mk]
  }

  if (s.mode === 'brief' || s.mode === 'done' || s.mode === 'fail' || s.mode === 'marco' || s.mode === 'decide' || s.mode === 'fire') return
  s.t += dt

  if (s.pendingFeet > 0) {
    s.pendingFeet -= dt
    if (s.pendingFeet <= 0) settleFeet(s)
  }

  if (s.mode === 'slip') {
    s.slipT -= dt
    if (s.slipT <= 0) respawn(s)
    return
  }
  if (s.mode === 'mantle') {
    s.mantleT -= dt
    s.logical.hip = [s.logical.hip[0], s.logical.hip[1] - dt * 40]
    if (s.mantleT <= 0) {
      s.mode = 'done'
      s.stars = apkStars('complete', s.slips, s.carried.length, arts.length)
      s.logical.hip = [615, 95 - 50]
    }
    return
  }

  const hipY = s.disp.hip[1]
  const shell = s.gear.includes('shell')
  // wind on the exposed traverse: calm 4.5 s, rising 1.3 s, gust 2.4 s
  s.windT += dt
  const cycle = s.windT % 8.2
  const prev = s.wind
  s.wind = cycle < 4.5 ? 'calm' : cycle < 5.8 ? 'rising' : 'gust'
  const exposed = inBand(hipY, GUST_BAND)
  if (exposed && prev !== s.wind) {
    if (s.wind === 'rising') say(s, 'Wind rising: stop moving, REST on a ledge or hold tight', 'warn', 1.3)
    if (s.wind === 'gust') say(s, shell ? 'Gust! The goggles help, but don\'t move' : 'Gust! Moving now will fail', 'bad', 2.4)
    if (s.wind === 'calm') say(s, 'Calm. Move between gusts, not through them', 'good', 1.6)
  }

  // stones down the gully: idle 3.2 s, grit 1.3 s, stone 0.5 s (APK: a hit is a slip; a helmet makes it −12)
  const nearGully = hipY > GULLY_BAND[0] - 60 && hipY < GULLY_BAND[1] + 80
  s.stone.t += dt
  const sc = s.stone.t % 5
  const stonePrev = s.stone.phase
  s.stone.phase = !nearGully ? 'idle' : sc < 3.2 ? 'idle' : sc < 4.5 ? 'warn' : 'fall'
  if (nearGully && stonePrev !== s.stone.phase && s.stone.phase === 'warn') say(s, 'Grit trickling down the gully: step out of the column', 'warn', 1.3)
  if (stonePrev === 'fall' && s.stone.phase === 'idle' && s.mode !== 'rest') {
    const pts = [s.disp.hL, s.disp.hR, s.disp.hip]
    const hit = pts.some(p => p[0] > GULLY_X[0] - 6 && p[0] < GULLY_X[1] + 6 && inBand(p[1], GULLY_BAND))
    if (hit) {
      if (s.gear.includes('helmet')) { hurt(s, APK.HELMET_HIT, arts); say(s, `Stone! The helmet took it (−${APK.HELMET_HIT})`, 'bad', 2) }
      else { slip(s, 'A falling stone knocks you off.', 'rock', arts); return }
    }
  }

  // the raven over the last face (APK · Creatures): hang still and it calls, then dives where you were
  if (hipY < RAVEN_BELOW && s.mode === 'climb') raven(s, dt, arts)
  // climbing on past Marco without stopping leaves him for Lena (APK · _meet_mate passDir)
  if (s.marco === 'waiting' && hipY < 352) { s.marco = 'left'; say(s, 'You climb on past Marco. Lena will bring him.', 'info', 2.6) }

  if (s.mode === 'rest') {
    s.stamina = Math.min(s.barMax, s.stamina + 22 * dt)
    if (s.stamina >= s.barMax) { s.mode = 'climb'; say(s, 'Full breath. Back on the rock', 'good', 1.4) }
  } else {
    const gloves = s.gear.includes('gloves') ? 0.8 : 1
    const drain = ((DRAIN[HOLDS[s.limbs.hL].type] + DRAIN[HOLDS[s.limbs.hR].type]) / 2) * gloves
    const gust = exposed && s.wind === 'gust' ? (shell ? 1.3 : 2.6) : 0
    s.stamina -= (drain + gust) * dt
  }
  s.lowest = Math.min(s.lowest, (s.stamina / s.barMax) * 100)
  if (s.stamina <= 0) slip(s, 'Your arms are gone.', 'arms', arts)
}

function raven(s: Sim, dt: number, arts: [string, string][]) {
  const r = s.raven
  r.t += dt
  if (r.phase === 'circle') {
    r.still += dt
    if (r.still > 2.2) { r.phase = 'call'; r.t = 0; r.tx = s.disp.hip[0]; r.ty = s.disp.hip[1] - 40; s.ravenCall = s.t; say(s, 'A raven calls overhead: move!', 'warn', APK.RAVEN_WARN + 0.3) }
  } else if (r.phase === 'call' && r.t >= APK.RAVEN_WARN) { r.phase = 'dive'; r.t = 0 }
  else if (r.phase === 'dive' && r.t >= APK.RAVEN_DIVE) {
    const missed = s.lastMove > s.ravenCall
    if (missed) say(s, 'The raven misses. Keep moving under it.', 'good', 1.4)
    else {
      hurt(s, APK.RAVEN_HURT, arts)
      const lost = s.carried.pop()
      if (lost !== undefined) {
        const f = s.finds.find(f => f.kind === 'artifact' && f.art === lost)
        if (f) f.taken = false
        s.toast = { kind: 'lost', title: `The raven took ${arts[lost][0]}`, body: 'It drops it back where you found it.', id: Date.now() }
      }
      say(s, `The raven hits you (−${APK.RAVEN_HURT})`, 'bad', 1.8)
    }
    r.phase = 'back'; r.t = 0
  } else if (r.phase === 'back' && r.t >= 1) { r.phase = 'circle'; r.t = 0; r.still = -APK.RAVEN_REST }
}

function positions(l: Limbs) {
  const hL = pt(l.hL), hR = pt(l.hR), fL = pt(l.fL), fR = pt(l.fR)
  return { hL, hR, fL, fR, hip: hipFor(hL, hR, fL, fR) }
}

function hipFor(hL: P, hR: P, fL: P, fR: P): P {
  const hx = (hL[0] + hR[0]) / 2, hy = (hL[1] + hR[1]) / 2
  const fx = (fL[0] + fR[0]) / 2, fy = (fL[1] + fR[1]) / 2
  let y = (hy + fy) / 2 + 8
  y = Math.min(y, Math.min(hL[1], hR[1]) + SHOULDER + 46)
  y = Math.max(y, Math.max(fL[1], fR[1]) - 60)
  return [hx * 0.55 + fx * 0.45, y]
}

function reachable(s: Sim): number[] {
  if (s.mode !== 'climb') return []
  const sh: P = [s.logical.hip[0], s.logical.hip[1] - SHOULDER]
  const topHand = Math.min(s.logical.hL[1], s.logical.hR[1])
  const lowHand = Math.max(s.logical.hL[1], s.logical.hR[1])
  return HOLDS.map((h, i) => i).filter(i => {
    const h = HOLDS[i]
    if (s.broken.includes(i) || i === s.limbs.hL || i === s.limbs.hR) return false
    if (h.y > lowHand + 6 || h.y < topHand - 90) return false
    return Math.hypot(h.x - sh[0], h.y - sh[1]) <= ARM_REACH
  })
}

function aim(s: Sim, reach: number[], v: StickV): number | null {
  if (!reach.length) return null
  const sh: P = [s.logical.hip[0], s.logical.hip[1] - SHOULDER]
  const len = Math.hypot(v.x, v.y)
  if (len < 0.3) return null
  let best: number | null = null, bestDot = 0.55
  reach.forEach(i => {
    const dx = HOLDS[i].x - sh[0], dy = HOLDS[i].y - sh[1]
    const d = Math.hypot(dx, dy) || 1
    const dot = (dx * v.x + dy * v.y) / (d * len)
    if (dot > bestDot) { bestDot = dot; best = i }
  })
  return best
}

function holdWord(s: Sim, i: number) {
  const t = HOLDS[i].type
  if (t === 'loose') return s.tested.includes(i) ? 'cracked!' : 'block'
  return t
}

/** TEST (proposed): weight a hold before trusting it. Costs a little breath and half a second. */
function testHold(s: Sim, i: number) {
  if (s.mode !== 'climb') return
  s.stamina -= 2
  s.testT = 0.5
  moved(s)
  if (!s.tested.includes(i)) s.tested.push(i)
  if (HOLDS[i].type === 'loose') say(s, 'It shifts and grit runs out of the crack. Not that one.', 'warn', 2)
  else say(s, `Solid ${HOLDS[i].type}.`, 'good', 1.2)
}

function tryMove(s: Sim, i: number, arts: [string, string][]) {
  if (s.mode === 'rest') s.mode = 'climb'
  if (s.mode !== 'climb') return
  if (!reachable(s).includes(i)) { say(s, 'Out of reach from here', 'info', 1.2); return }
  const exposed = inBand(s.disp.hip[1], GUST_BAND)
  const shell = s.gear.includes('shell')
  if (exposed && s.wind === 'gust') { const c = shell ? 6 : 12; s.stamina -= c; say(s, `The gust pushes you back onto your holds (−${c})`, 'bad', 1.8); return }
  // face-cost warning on leaving a ledge (APK · ClimbLevel._face_warning)
  const from = ledgeAt(s.limbs)
  if (from >= 0 && s.warnedFrom !== from && from < FACE_COST.length) {
    s.warnedFrom = from
    const cost = Math.round(FACE_COST[from] * (s.gear.includes('gloves') ? 0.8 : 1))
    if (cost > s.stamina) say(s, `This face takes about ${cost} stamina and you have ${Math.round(s.stamina)}. Climb down and rest first.`, 'bad', 3)
    else if (cost > s.stamina * 0.7) say(s, `Tight: this face takes about ${cost} of your ${Math.round(s.stamina)}. Keep moving.`, 'warn', 2.6)
  }
  const h = HOLDS[i]
  const L = s.logical.hL, R = s.logical.hR
  let hand: 'hL' | 'hR' = L[1] > R[1] ? 'hL' : 'hR'
  if (h.x < Math.min(L[0], R[0]) - 24) hand = 'hL'
  if (h.x > Math.max(L[0], R[0]) + 24) hand = 'hR'
  if (hand === 'hL' && h.x > R[0] + 18) hand = 'hR'
  if (hand === 'hR' && h.x < L[0] - 18) hand = 'hL'
  s.prev = { ...s.limbs }
  s.limbs[hand] = i
  s.logical[hand] = pt(i)
  s.moves++
  moved(s)
  const other = hand === 'hL' ? s.logical.hR : s.logical.hL
  const stretched = Math.abs(other[1] - h.y) > 62
  s.stamina -= (COST[h.type] + (stretched ? 4 : 0)) * (s.gear.includes('gloves') ? 0.8 : 1)
  if (h.type === 'loose') {
    s.broken.push(i)
    slip(s, 'The hold breaks!', 'fall', arts)
    return
  }
  collect(s, i, arts)
  if (i === TOP) {
    s.mode = 'mantle'; s.mantleT = 1.1
    say(s, 'Mantle over the lip', 'good', 1.1)
    return
  }
  if (stretched) say(s, 'Stretched: bring your feet up (+4 cost)', 'warn', 1.2)
  s.pendingFeet = 0.2
}

function collect(s: Sim, hold: number, arts: [string, string][]) {
  s.finds.forEach(f => {
    if (f.taken || f.hold !== hold) return
    f.taken = true
    if (f.kind === 'gear' && f.gear) {
      if (!s.gear.includes(f.gear)) s.gear.push(f.gear)
      if (f.gear === 'rope' && !s.spotter) s.spotter = 'rope'
      s.toast = { kind: 'gear', title: `Found: ${GEAR[f.gear].label}`, body: GEAR[f.gear].effect, id: Date.now() }
    } else if (f.art !== undefined) {
      s.carried.push(f.art)
      s.toast = { kind: 'artifact', title: `Artifact: ${arts[f.art][0]}`, body: arts[f.art][1], id: Date.now() }
    }
  })
}

function settleFeet(s: Sim) {
  const hy = (s.logical.hL[1] + s.logical.hR[1]) / 2
  const hx = (s.logical.hL[0] + s.logical.hR[0]) / 2
  const want = hy + 95
  const pick = (tx: number, avoid: number) => {
    let best = -1, score = Infinity
    HOLDS.forEach((h, i) => {
      if (h.type === 'loose' || h.type === 'top' || s.broken.includes(i) || i === s.limbs.hL || i === s.limbs.hR) return
      if (h.y < hy + 52 || h.y > hy + 165) return
      const sc = Math.abs(h.y - want) + 0.6 * Math.abs(h.x - tx) + (i === avoid ? 14 : 0)
      if (sc < score) { score = sc; best = i }
    })
    return best
  }
  const fL = pick(hx - 18, -1)
  const fR = pick(hx + 18, fL)
  if (fL >= 0) s.limbs.fL = fL
  if (fR >= 0) s.limbs.fR = fR
  if (HOLDS[s.limbs.fL].x > HOLDS[s.limbs.fR].x) { const t = s.limbs.fL; s.limbs.fL = s.limbs.fR; s.limbs.fR = t }
  s.logical = positions(s.limbs)
  // feet pick finds up too (the rope on ledge 1)
  ;[s.limbs.fL, s.limbs.fR].forEach(f => s.finds.forEach(fd => { if (!fd.taken && fd.hold === f && fd.kind === 'gear' && fd.gear) { fd.taken = true; if (!s.gear.includes(fd.gear)) s.gear.push(fd.gear); if (fd.gear === 'rope' && !s.spotter) s.spotter = 'rope'; s.toast = { kind: 'gear', title: `Found: ${GEAR[fd.gear].label}`, body: GEAR[fd.gear].effect, id: Date.now() } } }))
  const c = ledgeAt(s.limbs)
  if (c > s.checkpoint) {
    s.checkpoint = c
    const freshRests = s.rests < APK.REST_LIMIT
    s.rests = APK.REST_LIMIT
    say(s, `${CHECKPOINTS[c].name} · cairn ${c} of 3${freshRests ? ' · rests back to 2' : ''}`, 'good', 2)
    if (c === 3 && s.marco === 'waiting' && !s.marcoCool) s.mode = 'marco'
  }
}

/** APK · ClimbLevel._rest_gate: a rest from this stretch, else a snack from camp food, else nothing. */
function startRest(s: Sim, food: number) {
  if (s.rests > 0) {
    s.rests--
    if (s.rests === 0) say(s, 'Your last rest before the next ledge. After this, resting eats camp food.', 'warn', 2.4)
    else say(s, 'Sitting on the ledge: breath comes back', 'info', 1.4)
  } else if (food - s.snacks * APK.SNACK >= APK.SNACK) {
    s.snacks++
    say(s, `No rests left: you eat from the camp food (supplies −${APK.SNACK}).`, 'warn', 2.6)
  } else { say(s, 'No rests left and no food to spare. Make for the next ledge.', 'bad', 2.6); return }
  s.mode = 'rest'
  s.rested++
  s.restY = Math.max(s.logical.fL[1], s.logical.fR[1])
}

function hurt(s: Sim, amount: number, arts: [string, string][]) {
  s.hurt += amount
  s.stamina -= amount
  if (s.stamina <= 0) slip(s, 'Too hurt to go on: you collapse.', 'hurt', arts)
}

function slip(s: Sim, why: string, cause: SlipCause, arts: [string, string][]) {
  // a rope or a helped teammate holds it: it doesn't count (APK · climber.spotter / caught)
  if (s.spotter) {
    const who = s.spotter === 'rope' ? 'Lena holds the rope.' : 'Marco grabs your pack.'
    s.spotter = null
    s.caught++
    if (s.prev) { s.limbs = { ...s.prev }; s.logical = positions(s.limbs) }
    s.stamina = Math.max(s.stamina, s.barMax * 0.3)
    say(s, `${why} ${who} That slip doesn't count.`, 'good', 2.6)
    return
  }
  s.slips++
  s.causes[cause] = (s.causes[cause] ?? 0) + 1
  const lost = s.carried.length
  s.carried.forEach(a => { const f = s.finds.find(f => f.kind === 'artifact' && f.art === a); if (f) f.taken = false })
  s.carried = []
  if (lost) s.toast = { kind: 'lost', title: lost === 1 ? 'You drop the artifact' : 'You drop both artifacts', body: 'Back where you found them. Climb to them again.', id: Date.now() }
  say(s, s.slips >= 3 ? `Slip ${s.slips} of 3: the climb is over.` : `${why} Back to the last ledge.`, 'bad', 2.4)
  if (s.slips >= 3) { s.mode = 'fail'; s.gear = []; return }
  s.mode = 'slip'; s.slipT = 0.9
  const c = CHECKPOINTS[s.checkpoint]
  s.logical.hip = [s.logical.hip[0], c.y - 50]
  void arts
}

function respawn(s: Sim) {
  const c = CHECKPOINTS[s.checkpoint]
  s.limbs = { fL: c.limbs[0], fR: c.limbs[1], hL: c.limbs[2], hR: c.limbs[3] }
  s.logical = positions(s.limbs)
  s.disp = clone(s.logical)
  s.stamina = Math.max(s.stamina, s.barMax * 0.6)
  s.rests = APK.REST_LIMIT
  s.raven = freshRaven()
  s.mode = 'climb'
}

function ledgeAt(l: Limbs) {
  return CHECKPOINTS.findIndex(c => [c.limbs[0], c.limbs[1]].includes(l.fL) || [c.limbs[0], c.limbs[1]].includes(l.fR))
}

/** Any reach or test counts as moving for the raven. */
function moved(s: Sim) { s.lastMove = s.t; if (s.raven.still > 0) s.raven.still = 0 }
function say(s: Sim, text: string, tone: Sim['captionTone'], secs: number) { s.caption = text; s.captionTone = tone; s.captionT = secs }
function pt(i: number): P { return [HOLDS[i].x, HOLDS[i].y] }
function clone<T>(o: T): T { return JSON.parse(JSON.stringify(o)) }
function clamp(v: number, a: number, b: number) { return Math.max(a, Math.min(b, v)) }
function inBand(y: number, b: [number, number]) { return y >= b[0] && y <= b[1] }
function fmt(t: number) { const s = Math.floor(t); return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}` }

function Fire({ x, y, rm, t }: { key?: React.Key; x: number; y: number; rm: boolean; t: number }) {
  const f = rm ? 0 : Math.sin(t * 14) * 1.5
  return (
    <g transform={`translate(${x} ${y})`} pointerEvents="none">
      <path d="M-8 1 L8 1" stroke="#3a2a22" strokeWidth={3} strokeLinecap="round" />
      <path d={`M-5 0 Q-6 ${-8 + f} 0 ${-15 - f} Q6 ${-8 + f} 5 0 Z`} fill="#d9572b" />
      <path d={`M-2.5 0 Q-3 -5 0 ${-9 + f} Q3 -5 2.5 0 Z`} fill="#ffd37a" />
    </g>
  )
}

function VerticalRail({ hipY }: { hipY: number }) {
  const f = clamp(1 - (hipY - 95) / (WALL_H - 95), 0, 1)
  return (
    <div className="flex h-[150px] items-stretch gap-1.5 rounded-full bg-scrim px-2 py-2 ring-1 ring-white/10">
      <div className="relative w-[6px] rounded-full bg-black/40">
        {CHECKPOINTS.map(c => <span key={c.name} className="absolute left-1/2 h-[2px] w-3 -translate-x-1/2 bg-paper/70" style={{ bottom: `${(1 - (c.y - 95) / (WALL_H - 95)) * 100}%` }} />)}
        <span className="absolute inset-x-0 bottom-0 rounded-full bg-route" style={{ height: `${f * 100}%` }} />
        <span className="absolute left-1/2 h-3 w-3 -translate-x-1/2 translate-y-1/2 rounded-full border-2 border-ink bg-paper" style={{ bottom: `${f * 100}%` }} />
      </div>
      <div className="tabular flex flex-col justify-between text-[10px] leading-none text-paper/80"><span>Top</span><span>{Math.round(f * 100)}%</span><span>Camp</span></div>
    </div>
  )
}

const MARCO = {
  jacket: '#a8432a', jacketTrim: '#7e3520', headwear: 'helmet' as const, headwearColor: '#f3efe6', pack: 'daypack' as const, packColor: '#3a342c',
  harness: '#4c5866', chalkBag: '#d8c7a4', bagPattern: 'plain' as const, rope: '#4fa3d9', skin: '#e0b48e', hair: '#5a3a22',
}
