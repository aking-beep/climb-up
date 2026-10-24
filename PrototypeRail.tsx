import React from 'react'
import { HudState, ScreenId, useGame } from '../state/GameState'
import { useExpedition, CampPhase } from '../state/Expedition'
import { EncounterId } from '../data/kili'

/** One list of places, in the order a player meets them. */
const PLACES: { label: string; screen: ScreenId; climb?: EncounterId; jump?: 'karanga' | 'summit'; intent?: string; hint: string }[] = [
  { label: 'Hub', screen: 'hub', hint: 'The title is a place. Tap your climber chip for your profile, Kibo for the expedition, Lion Rock for the crag.' },
  { label: 'Profile', screen: 'profile', hint: 'Tap your climber (or “Customize climber”) to choose Male or Female, colourways, skin, hair and gear.' },
  { label: 'Crag', screen: 'crag', hint: 'Tap a chalk line, pick shoes, Tie in.' },
  { label: 'Expedition map', screen: 'expedition', jump: 'karanga', hint: 'Karanga, day 6. “Enter camp” to explore, or “Today at Karanga” for the decision. Diamonds start the climbs.' },
  { label: 'Camp', screen: 'camp', jump: 'karanga', hint: 'Stick or WASD to walk. Walk up to a person or place and tap the icon. “Decisions” is top-right.' },
  { label: 'Barranco Wall', screen: 'enc-barranco', climb: 'barranco-wall', hint: 'Tap a ringed hold (or aim + REACH). TEST suspicious blocks. Grab gear and the two artifacts; a counted slip drops them. Stones in the gully are slips without the helmet. Keep moving under the raven.' },
  { label: 'Karanga Ridge', screen: 'enc-karanga', climb: 'karanga-ridge', hint: 'Solo. Down to the stream and FILL your bottles (Space hops the stones). Push UP on rock to climb. At the junction: up onto the windy crest (stand still in gusts, hop the notch, keep walking on the slab) or the scree under it (hop the stones, keep moving under the raven). DRINK with B.' },
  { label: 'Summit approach', screen: 'enc-summit', climb: 'summit-approach', hint: 'Solo, in the dark. Tap BREATHE (B) when it lights. Zigzag up: hop the holes, climb each pitch, ice slides until the crampons. Wait out the grit on the rock step. Grab Jun\'s glove on the ledge; meet the team at Uhuru, TALK, GIVE, then SUMMIT.' },
  { label: 'Summit & descent', screen: 'expedition', jump: 'summit', intent: 'open-decision', hint: '“The top is not the end”: choose a way down to open the descent, then the scorecard.' },
]

const HUD_STATES: { id: HudState; label: string }[] = [
  { id: 'live', label: 'Live sim' }, { id: 'normal', label: 'Climbing' }, { id: 'reach', label: 'Reaching' }, { id: 'clip', label: 'Clipping' },
  { id: 'rest', label: 'Resting' }, { id: 'fall', label: 'Falling' }, { id: 'complete', label: 'Complete' },
]

/** Reviewer controls. Lives outside the phone; not part of the game UI. */
export function PrototypeRail() {
  const g = useGame()
  const x = useExpedition()
  const [hint, setHint] = React.useState('Every number on screen is simulated. Nothing here runs in Godot.')

  return (
    <div className="shrink-0 border-t border-white/10 bg-[#0f0e0c] px-6 py-2.5 text-[12px] text-paper/80">
      <div className="flex items-center gap-1">
        <span className="mr-2 rounded-sm bg-ember px-2 py-[3px] text-[11px] font-semibold tracking-wide text-paper">PROTOTYPE</span>
        {PLACES.map(p => {
          const on = g.screen === p.screen && (p.screen !== 'expedition' || !p.intent)
          return (
            <button key={p.label}
              onClick={() => {
                setHint(p.hint)
                if (p.climb) { x.play(p.climb); return }
                if (p.jump) x.jump(p.jump)
                g.setIntent(p.intent ?? null)
                g.go(p.screen)
              }}
              className={`h-8 whitespace-nowrap rounded-md px-2.5 transition-colors duration-150 ${on ? 'bg-paper text-ink' : 'bg-white/5 text-paper/85 hover:bg-white/10'}`}>
              {p.label}
            </button>
          )
        })}
        <div className="ml-auto flex items-center gap-4 pl-3">
          <Toggle label="Specs" on={g.settings.showSpecs} set={v => g.setSettings({ ...g.settings, showSpecs: v })} />
          <Toggle label="Left-handed" on={g.settings.leftHanded} set={v => g.setSettings({ ...g.settings, leftHanded: v })} />
          <Toggle label="Reduced motion" on={g.settings.reducedMotion} set={v => g.setSettings({ ...g.settings, reducedMotion: v })} />
        </div>
      </div>
      <div className="mt-2 flex h-7 items-center gap-3">
        <span className="truncate text-paper/60">{hint}</span>
        {g.screen === 'camp' && (
          <div className="ml-auto flex shrink-0 items-center gap-1">
            <span className="mr-1 text-paper/50">Camp time (engine hour)</span>
            {(['day', 'evening', 'night'] as CampPhase[]).map(ph => (
              <button key={ph} onClick={() => x.setPhase(ph)} className={`h-7 rounded-md px-2 capitalize transition-colors duration-150 ${x.phase === ph ? 'bg-route text-ink' : 'bg-white/5 hover:bg-white/10'}`}>{ph}</button>
            ))}
          </div>
        )}
        {g.screen === 'climb' && (
          <div className="ml-auto flex shrink-0 items-center gap-1">
            <span className="mr-1 text-paper/50">HUD state</span>
            {HUD_STATES.map(s => (
              <button key={s.id} onClick={() => g.setHudState(s.id)} className={`h-7 rounded-md px-2 transition-colors duration-150 ${g.hudState === s.id ? 'bg-route text-ink' : 'bg-white/5 hover:bg-white/10'}`}>{s.label}</button>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

function Toggle({ label, on, set }: { label: string; on: boolean; set: (v: boolean) => void }) {
  return (
    <button onClick={() => set(!on)} className="flex items-center gap-2 whitespace-nowrap text-paper/75 hover:text-paper">
      <span className={`relative h-4 w-7 rounded-full transition-colors duration-150 ${on ? 'bg-route' : 'bg-white/15'}`}>
        <span className={`absolute top-0.5 h-3 w-3 rounded-full bg-paper transition-transform duration-150 ${on ? 'translate-x-3.5' : 'translate-x-0.5'}`} />
      </span>
      {label}
    </button>
  )
}
