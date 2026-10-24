import React, { useState } from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import { useGame } from '../state/GameState'
import { BackButton, Stars } from '../components/ui'
import { DAILY, ROUTES, isUnlocked, nextRoute } from '../data/routes'
import { RouteTopo } from '../crag/RouteTopo'
import { GradeStrip } from '../crag/GradeStrip'
import { RouteCard } from '../crag/RouteCard'
import { SpecNote } from '../components/SpecNote'

export const CRAG_PLATE = 'https://cdn.magicpatterns.com/patterns/generated-images/6a8cd8b8-f08a-4bbe-bb77-040c07107f92.jpg'

/** Screen 2 — the crag itself is the menu: routes are chalk lines on Lion Rock. */
export function CragSelect() {
  const g = useGame()
  const [reading, setReading] = useState(false)
  const route = g.routeId === 'daily' ? DAILY : ROUTES.find(r => r.id === g.routeId) ?? ROUTES[0]
  const rec = nextRoute(g.progress)
  const totalStars = ROUTES.reduce((s, r) => s + (g.progress[r.id]?.stars ?? 0), 0)

  const select = (id: string) => { setReading(false); g.setRouteId(id) }

  const read = () => {
    setReading(true)
    window.setTimeout(() => setReading(false), g.settings.reducedMotion ? 1600 : 2400)
  }

  return (
    <div className="absolute inset-0 overflow-hidden bg-[#3a2a1c]">
      <motion.img
        src={CRAG_PLATE}
        alt=""
        draggable={false}
        className="absolute left-0 top-0 h-[515px] w-[915px] max-w-none object-cover"
        animate={{ y: reading ? 0 : -40, scale: reading ? 1.08 : 1 }}
        transition={{ duration: g.settings.reducedMotion ? 0 : 2.2, ease: [0.65, 0, 0.35, 1] }}
        style={{ transformOrigin: '30% 10%' }}
      />
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(70%_80%_at_85%_20%,rgb(255_210_150/0.18),transparent_70%)]" />

      <RouteTopo
        selected={route.id}
        recommended={rec.id}
        onSelect={select}
        dimmed={reading}
      />

      {/* Top-left: way home, the crag's name, its stars */}
      <div className="absolute left-7 top-4 flex items-center gap-3">
        <BackButton dark label="Hub" onClick={() => g.go('hub')} />
        <div className="world-text text-paper">
          <div className="font-display text-[24px] leading-none">Lion Rock</div>
          <div className="mt-1 flex items-center gap-1.5 text-[13px] text-paper/85"><Stars n={1} of={1} size={13} light /> {totalStars} of 21 stars · 7 routes</div>
        </div>
      </div>

      <div className="absolute bottom-4 left-7">
        <GradeStrip selected={route.id} recommended={rec.id} onSelect={select} />
      </div>

      <div className="absolute bottom-4 right-6 top-4 w-[344px]">
        <RouteCard
          key={route.id}
          route={route}
          locked={!isUnlocked(route.id, g.progress)}
          recommended={route.id === rec.id}
          onRead={read}
          onTieIn={() => g.go('climb')}
          coach={g.intent === 'focus-tiein'}
        />
      </div>

      <AnimatePresence>
        {reading && (
          <motion.div
            initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }}
            transition={{ duration: 0.18, ease: [0.23, 1, 0.32, 1] }}
            className="absolute left-1/2 top-20 -translate-x-[70%] rounded-full bg-scrim px-4 py-2 text-[13px] text-paper ring-1 ring-white/15"
          >
            Reading the route · camera flies up the line · free, not a go <span className="ml-1 text-route">(simulated)</span>
          </motion.div>
        )}
      </AnimatePresence>

      {g.settings.showSpecs && (
        <>
          <SpecNote x={300} y={120} w={210}>Route line hit area: 24 dp stroke + 48 dp grade flag</SpecNote>
          <SpecNote x={40} y={300} w={210}>Grade strip: 56×48 dp tabs, scrolls if a 2nd crag adds routes</SpecNote>
          <SpecNote x={560} y={4} w={200}>Journal card 344 dp · progressive: crux only, beta in brief</SpecNote>
        </>
      )}
    </div>
  )
}
