import React, { createContext, useCallback, useContext, useMemo, useState } from 'react'
import { DEFAULT_LOOK, Look } from '../data/cosmetics'
import { INITIAL_PROGRESS, RouteProgress } from '../data/routes'
import { Build, HeroBuildContext } from '../components/Hero'

export type ScreenId =
  | 'hub' | 'crag' | 'climb' | 'profile' | 'customize' | 'expedition'
  // Phase 2
  | 'character' | 'prep' | 'camp' | 'enc-barranco' | 'enc-karanga' | 'enc-summit' | 'scorecard'
export type Overlay = null | 'records' | 'settings'
export type HudState = 'live' | 'normal' | 'reach' | 'clip' | 'rest' | 'fall' | 'complete'

export interface Settings {
  music: number
  effects: number
  vibration: boolean
  controlSize: number
  leftHanded: boolean
  reducedMotion: boolean
  graphics: 'low' | 'high'
  showSpecs: boolean
}

interface GameCtx {
  screen: ScreenId
  go: (s: ScreenId) => void
  overlay: Overlay
  setOverlay: (o: Overlay) => void
  look: Look
  setLook: (l: Look) => void
  routeId: string
  setRouteId: (id: string) => void
  shoes: 'neutral' | 'aggressive'
  setShoes: (s: 'neutral' | 'aggressive') => void
  progress: Record<string, RouteProgress>
  recordSend: (id: string, style: RouteProgress['best'], seconds: number, stars: number) => void
  earned: string[]
  earn: (ids: string[]) => void
  settings: Settings
  setSettings: (s: Settings) => void
  hudState: HudState
  setHudState: (s: HudState) => void
  expeditionStarted: boolean
  setExpeditionStarted: (b: boolean) => void
  /** One-shot deep link from the prototype rail, e.g. 'achievements', 'pick-expedition'. */
  intent: string | null
  setIntent: (i: string | null) => void
  /** Phase 2 character direction drawn everywhere (A recommended). */
  build: Build
  setBuild: (b: Build) => void
}

const Ctx = createContext<GameCtx | null>(null)

export function GameProvider({ children }: { children: React.ReactNode }) {
  const [screen, setScreen] = useState<ScreenId>('hub')
  const [overlay, setOverlay] = useState<Overlay>(null)
  const [look, setLook] = useState<Look>(DEFAULT_LOOK)
  const [routeId, setRouteId] = useState('the-pinch')
  const [shoes, setShoes] = useState<'neutral' | 'aggressive'>('neutral')
  const [progress, setProgress] = useState(INITIAL_PROGRESS)
  const [earned, setEarned] = useState<string[]>(['first-send', 'onsight', 'redpoint', 'daily'])
  const [hudState, setHudState] = useState<HudState>('live')
  const [expeditionStarted, setExpeditionStarted] = useState(true)
  const [intent, setIntent] = useState<string | null>(null)
  const [build, setBuild] = useState<Build>('A')
  const [settings, setSettings] = useState<Settings>({
    music: 70, effects: 80, vibration: true, controlSize: 100, leftHanded: false,
    reducedMotion: false, graphics: 'high', showSpecs: false,
  })

  const go = useCallback((s: ScreenId) => {
    setOverlay(null)
    if (s === 'climb') setHudState('live')
    setScreen(s)
  }, [])

  const recordSend = useCallback((id: string, style: RouteProgress['best'], seconds: number, stars: number) => {
    setProgress(p => {
      const prev = p[id] ?? { attempts: 0, sends: 0, best: '', bestSeconds: 0, stars: 0, highBolt: 0 }
      return {
        ...p,
        [id]: {
          attempts: prev.attempts + 1,
          sends: prev.sends + 1,
          best: prev.best === '' ? style : prev.best,
          bestSeconds: prev.bestSeconds === 0 ? seconds : Math.min(prev.bestSeconds, seconds),
          stars: Math.max(prev.stars, stars),
          highBolt: 99,
        },
      }
    })
  }, [])

  const earn = useCallback((ids: string[]) => setEarned(e => Array.from(new Set([...e, ...ids]))), [])

  const value = useMemo(() => ({
    screen, go, overlay, setOverlay, look, setLook, routeId, setRouteId, shoes, setShoes,
    progress, recordSend, earned, earn, settings, setSettings, hudState, setHudState,
    expeditionStarted, setExpeditionStarted, intent, setIntent, build, setBuild,
  }), [screen, go, overlay, look, routeId, shoes, progress, recordSend, earned, earn, settings, hudState, expeditionStarted, intent, build])

  return (
    <Ctx.Provider value={value}>
      <HeroBuildContext.Provider value={build}>{children}</HeroBuildContext.Provider>
    </Ctx.Provider>
  )
}

export function useGame() {
  const c = useContext(Ctx)
  if (!c) throw new Error('useGame outside GameProvider')
  return c
}
