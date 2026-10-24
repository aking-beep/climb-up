import React from 'react'
import { AnimatePresence, motion } from 'framer-motion'
import { useGame } from '../state/GameState'
import { Hub } from '../screens/Hub'
import { CragSelect } from '../screens/CragSelect'
import { CragClimb } from '../screens/CragClimb'
import { Profile } from '../screens/Profile'
import { Customize } from '../screens/Customize'
import { ExpeditionMap } from '../screens/ExpeditionMap'
import { CharacterPreview } from '../screens/CharacterPreview'
import { ExpeditionPrep } from '../screens/ExpeditionPrep'
import { Camp } from '../screens/Camp'
import { EncounterBarranco } from '../screens/EncounterBarranco'
import { EncounterKaranga } from '../screens/EncounterKaranga'
import { EncounterSummit } from '../screens/EncounterSummit'
import { Scorecard } from '../screens/Scorecard'
import { RecordsSheet } from '../overlays/RecordsSheet'
import { SettingsSheet } from '../overlays/SettingsSheet'
import { ScreenBoundary } from './ScreenBoundary'

/** Screen changes fade through ink, matching core/ui/transition.gd (out 160 ms, in 240 ms). */
export function ScreenHost() {
  const { screen, overlay, settings, go } = useGame()
  const rm = settings.reducedMotion
  return (
    <div className="absolute inset-0 bg-night">
      <AnimatePresence mode="wait">
        <motion.div
          key={screen}
          className="absolute inset-0"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1, transition: { duration: rm ? 0 : 0.24, ease: [0.23, 1, 0.32, 1] } }}
          exit={{ opacity: 0, transition: { duration: rm ? 0 : 0.16, ease: [0.23, 1, 0.32, 1] } }}
        >
          <ScreenBoundary resetKey={screen} onReset={() => go('hub')}>
          {screen === 'hub' && <Hub />}
          {screen === 'crag' && <CragSelect />}
          {screen === 'climb' && <CragClimb />}
          {screen === 'profile' && <Profile />}
          {screen === 'customize' && <Customize />}
          {screen === 'expedition' && <ExpeditionMap />}
          {screen === 'character' && <CharacterPreview />}
          {screen === 'prep' && <ExpeditionPrep />}
          {screen === 'camp' && <Camp />}
          {screen === 'enc-barranco' && <EncounterBarranco />}
          {screen === 'enc-karanga' && <EncounterKaranga />}
          {screen === 'enc-summit' && <EncounterSummit />}
          {screen === 'scorecard' && <Scorecard />}
          </ScreenBoundary>
        </motion.div>
      </AnimatePresence>
      <ScreenBoundary resetKey={overlay ?? 'none'} onReset={() => go('hub')}>
      <AnimatePresence>
        {overlay === 'records' && <RecordsSheet key="records" />}
        {overlay === 'settings' && <SettingsSheet key="settings" />}
      </AnimatePresence>
      </ScreenBoundary>
    </div>
  )
}
