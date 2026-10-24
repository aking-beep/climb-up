// The 12 crag achievements are verbatim from godot/modes/crag/logbook.gd
// (protected). Expedition achievements are PROPOSED, additive, and need
// a new persistent `expedition_achievements` record.

export interface Achievement {
  id: string
  title: string
  how: string
  mode: 'crag' | 'expedition'
  proposed?: boolean
  icon: 'flag' | 'eye' | 'repeat' | 'target' | 'feather' | 'droplet' | 'arm' | 'bolt' | 'broom' | 'crown' | 'sun' | 'star' | 'users' | 'gem' | 'mountain' | 'turn'
}

export const ACHIEVEMENTS: Achievement[] = [
  { id: 'first-send', title: 'First send', how: 'Finish First Climb.', mode: 'crag', icon: 'flag' },
  { id: 'onsight', title: 'Onsight', how: 'Onsight a graded route: first go, no falls, no beta.', mode: 'crag', icon: 'eye' },
  { id: 'redpoint', title: 'Redpoint', how: 'Send a route clean after trying it before.', mode: 'crag', icon: 'repeat' },
  { id: 'perfect-catch', title: 'Perfect catch', how: 'Catch a dyno right on the contact.', mode: 'crag', icon: 'target' },
  { id: 'feather', title: 'Feather touch', how: "Do Sundown's challenge: slopers with a light, steady touch.", mode: 'crag', icon: 'feather' },
  { id: 'economy', title: 'Economy', how: "Do The Pinch's challenge: few, well-timed squeezes.", mode: 'crag', icon: 'droplet' },
  { id: 'no-sitting', title: 'Iron arms', how: "Do Lion's Roof's challenge: no rests on the rope.", mode: 'crag', icon: 'arm' },
  { id: 'runout', title: 'Run-out', how: 'Send Thunderhead without a fall.', mode: 'crag', icon: 'bolt' },
  { id: 'clean-sweep', title: 'Clean sweep', how: 'A clean send (redpoint or better) of every graded route.', mode: 'crag', icon: 'broom' },
  { id: 'master', title: 'Master of Lion Rock', how: 'Three stars on all seven routes.', mode: 'crag', icon: 'crown' },
  { id: 'daily', title: 'Daily climber', how: 'Send a daily route.', mode: 'crag', icon: 'sun' },
  { id: 'daily-clean', title: 'Daily onsight', how: 'Send a daily route on your first go without falling.', mode: 'crag', icon: 'star' },
  { id: 'exp-all-home', title: 'Everyone home', how: 'Summit by Umbwe and bring all four home.', mode: 'expedition', proposed: true, icon: 'users' },
  { id: 'exp-artifacts', title: 'Keeper of stories', how: 'Bring home all 8 artifacts of one route in a single expedition.', mode: 'expedition', proposed: true, icon: 'gem' },
  { id: 'exp-descent', title: 'Down is the summit', how: 'Three stars on the Descent.', mode: 'expedition', proposed: true, icon: 'mountain' },
  { id: 'exp-turned', title: 'The mountain will wait', how: 'Turn back together with everyone healthy.', mode: 'expedition', proposed: true, icon: 'turn' },
]
