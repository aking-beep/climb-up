import React, { useState } from 'react'
import { motion } from 'framer-motion'
import { Settings as SettingsIcon, Trophy } from 'lucide-react'
import { useGame } from '../state/GameState'
import { IconButton, Stars } from '../components/ui'
import { Climber } from '../components/Climber'
import { useParallax } from '../hub/useParallax'
import { Destination } from '../hub/Destination'
import { ContinueCard } from '../hub/ContinueCard'
import { DailyTicket } from '../hub/DailyTicket'
import { BoulderClimber } from '../hub/BoulderClimber'
import { HubForeground, HubMidground, CloudBand } from '../hub/HubLayers'
import { ROUTES, nextRoute } from '../data/routes'
import { SpecNote } from '../components/SpecNote'

export const HUB_PLATE = 'https://cdn.magicpatterns.com/patterns/generated-images/9fd008a9-b945-4665-a2e8-ea6788038a91.jpg'

/** Screen 1 — the title becomes a place: Lion Rock and Kibo are the two mode entrances. */
export function Hub() {
  const g = useGame()
  const rm = g.settings.reducedMotion
  const { ref, x, y, onMove, onLeave } = useParallax(rm)
  const [zoom, setZoom] = useState<null | { ox: string; oy: string }>(null)
  const totalStars = ROUTES.reduce((s, r) => s + (g.progress[r.id]?.stars ?? 0), 0)
  const next = nextRoute(g.progress)
  const topSent = [...ROUTES].reverse().find(r => r.grade !== 'Lesson' && (g.progress[r.id]?.sends ?? 0) > 0)

  const travel = (to: 'crag' | 'expedition', ox: string, oy: string) => {
    if (rm) return g.go(to)
    setZoom({ ox, oy })
    window.setTimeout(() => g.go(to), 260)
  }

  return (
    <div ref={ref} onPointerMove={onMove} onPointerLeave={onLeave} className="absolute inset-0 overflow-hidden bg-[#c9b79a]">
      {/* Far plate + destinations share one layer so markers stay pinned to the art */}
      <motion.div
        className="absolute top-0 h-[412px] w-[971px] left-[-28px]"
        style={{ x: x(-8), y: y(-4), transformOrigin: zoom ? `${zoom.ox} ${zoom.oy}` : '50% 50%' }}
        animate={{ scale: zoom ? 1.55 : 1.1 }}
        transition={{ duration: zoom ? 0.26 : 0, ease: [0.65, 0, 0.35, 1] }}
      >
        <img src={HUB_PLATE} alt="" draggable={false} className="absolute inset-0 h-full w-full object-fill" />
        <CloudBand rm={rm} />
        {/* atmospheric key light: one warm source, upper right (HD-2D staging) */}
        <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(60%_70%_at_78%_8%,rgb(255_214_160/0.28),transparent_70%)]" />
        <Destination
          left="19%" top="33%" align="right"
          place="Lion Rock" mode="Crag"
          line={`Next up · ${next.name} ${next.grade}`}
          extra={<span className="flex items-center gap-1.5"><Stars n={1} of={1} size={12} light /> {totalStars} of 21</span>}
          onClick={() => travel('crag', '19%', '33%')}
        />
        <Destination
          left="76%" top="21%" align="left"
          place="Kilimanjaro" mode="Expedition"
          line="Lemosho · Day 6 of 13"
          extra={<span>Karanga Camp · 4,035 m</span>}
          onClick={() => { g.setIntent('pick-expedition'); travel('expedition', '76%', '21%') }}
        />
      </motion.div>

      <HubMidground x={x(-16)} />
      <BoulderClimber x={x(-26)} rm={rm} onTap={() => g.go('profile')} />
      <HubForeground x={x(-34)} />
      <div className="pointer-events-none absolute inset-0 shadow-[inset_0_0_120px_rgb(20_14_8/0.45)]" />

      {/* Top chrome */}
      <div className="absolute left-7 top-4 flex items-center gap-3">
        <div className="world-text font-display text-[30px] leading-none text-paper">Climb Up</div>
      </div>
      <div className="absolute right-6 top-4 flex items-center gap-2">
        <button
          onClick={() => g.go('profile')}
          className="flex h-12 items-center gap-2 rounded-full bg-scrim pl-1 pr-4 text-paper ring-1 ring-white/15 transition-[transform,background-color] duration-[120ms] ease-out hover:bg-black/70 active:scale-[0.96]"
        >
          <span className="relative block h-10 w-10 overflow-hidden rounded-full bg-[#cfe0e8]">
            <Climber look={g.look} size={64} style={{ position: 'absolute', left: -12, top: 3 }} />
          </span>
          <span className="text-left leading-tight">
            <span className="block font-display text-[15px]">Your climber</span>
            <span className="block text-[12px] text-paper/75">{topSent ? topSent.grade : 'New'} · 1 summit</span>
          </span>
        </button>
        <IconButton dark label="Records" onClick={() => g.setOverlay('records')}><Trophy size={20} /></IconButton>
        <IconButton dark label="Settings" onClick={() => g.setOverlay('settings')}><SettingsIcon size={20} /></IconButton>
      </div>

      {/* Bottom: the one thing most players came back for, then today's route */}
      <div className="absolute bottom-4 left-7">
        <ContinueCard onClick={() => { g.setIntent(null); travel('expedition', '76%', '21%') }} />
      </div>
      <div className="absolute bottom-4 right-6">
        <DailyTicket onClick={() => { g.setRouteId('daily'); g.go('crag') }} />
      </div>

      {g.settings.showSpecs && (
        <>
          <SpecNote x={150} y={196} w={210}>Destination tag · tap 48 dp min · zoom 260 ms in-out</SpecNote>
          <SpecNote x={36} y={268} w={180}>Primary: Continue (last session)</SpecNote>
          <SpecNote x={720} y={60} w={170}>Chrome 48 dp · 24 dp safe inset</SpecNote>
          <SpecNote x={420} y={196} w={150}>Tap climber → Profile</SpecNote>
        </>
      )}
    </div>
  )
}
