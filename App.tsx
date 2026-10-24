import React from 'react'
import { GameProvider } from './state/GameState'
import { ExpeditionProvider } from './state/Expedition'
import { DeviceFrame } from './shell/DeviceFrame'
import { ScreenHost } from './shell/ScreenHost'
import { PrototypeRail } from './shell/PrototypeRail'

export function App() {
  return (
    <GameProvider>
      <ExpeditionProvider>
      <div className="h-screen w-full flex flex-col bg-[#141210] text-paper overflow-hidden">
        <div className="flex-1 min-h-0 flex items-center justify-center px-6 pt-5 pb-3">
          <DeviceFrame>
            <ScreenHost />
          </DeviceFrame>
        </div>
        <PrototypeRail />
      </div>
      </ExpeditionProvider>
    </GameProvider>
  )
}
