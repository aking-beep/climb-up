// Shared stage data for the played expedition climbs.
//
// Everything tagged APK below is copied from the connected repo
// (godot/modes/expedition/levels/climb_level.gd, artifacts.gd,
// core/world/hazards.gd, core/world/creatures.gd) so the prototype plays the
// same rules the Godot build already ships. Nothing here is code to port:
// in Godot these values already live in those files.

export type GearKind = 'poles' | 'gloves' | 'shell' | 'crampons' | 'headlamp' | 'helmet' | 'rope'

/** APK · ClimbLevel.GEAR + each level's "gear" list wording. */
export const GEAR: Record<GearKind, { label: string; effect: string }> = {
  rope: { label: 'Short rope', effect: 'Lena can hold your next slip on it: it will not count.' },
  gloves: { label: 'Gloves', effect: 'Rock costs less with them on (×0.8 on every move and hang).' },
  helmet: { label: 'Helmet', effect: 'A falling stone costs 12 breath instead of knocking you off.' },
  shell: { label: 'Goggles & buff', effect: 'Gusts push you less, and sitting on windy ground gives some breath back.' },
  crampons: { label: 'Crampons', effect: 'On ice they bite: no sliding, and ice costs half.' },
  headlamp: { label: 'Headlamp', effect: 'You see your footing: a wider beam, and the cold no longer slows your walk.' },
  poles: { label: 'Trekking poles', effect: 'Walking costs less (×0.7).' },
}

/** APK constants (climb_level.gd, hazards.gd, creatures.gd, artifacts.gd). */
export const APK = {
  REST_LIMIT: 2,
  SNACK: 3,
  FIRE_HOURS: 1,
  REGROUP_HOURS: 1,
  ARTIFACT_POINTS: 6,
  HELMET_HIT: 12,
  RAVEN_HURT: 12,
  ANT_HURT: 12,
  PLANT_HURT: 10,
  RAVEN_WARN: 0.7,
  RAVEN_DIVE: 0.45,
  RAVEN_REST: 3.5,
  SLAB_HOLD: 1.0,
  WATER: 0.45,
  STONE_WARN: 1.2,
}

export type SlipCause = 'rock' | 'fall' | 'arms' | 'wind' | 'hurt' | 'ice' | 'slab'

/** APK · ClimbLevel.SLIP_LESSONS (ice and slab lines added for the proposed mechanics). */
export const SLIP_LESSONS: Record<SlipCause, [string, string]> = {
  rock: ['falling stones', 'Watch for grit trickling over a column: a stone follows. Step to the side until it passes.'],
  fall: ['long falls', 'Climb down to the ledge instead of reaching past what your arms can hold.'],
  arms: ['empty arms', 'Rest to full before a face (the warning when you leave a ledge says what it costs), and keep moving on it.'],
  wind: ['the wind', 'On exposed ground, don\'t move in a gust: stop, REST or brace until it passes, then go.'],
  hurt: ['thorns, ants and ravens', 'Hop over thistles and ants; keep moving under a raven so it misses.'],
  ice: ['ice', 'Ice has no grip: let go of the stick early, hop before a hole, or find the crampons first.'],
  slab: ['cracked slabs', 'Keep walking across a creaking slab. Stop on it and it goes.'],
}

export type ClimbKey = 'barranco-wall' | 'summit-night'
type RouteKey = 'lemosho' | 'machame' | 'umbwe'

/** APK · Artifacts.DATA (names and stories verbatim; cells are Godot map cells, not used here). */
export const ARTIFACTS: Record<ClimbKey, Record<RouteKey, [string, string][]>> = {
  'barranco-wall': {
    lemosho: [
      ['a kihamba banana leaf', 'A Chagga kihamba is a home garden of bananas, coffee, beans and tall shade trees, layered like a forest. The UN food agency lists the system among the world\'s agricultural heritage.'],
      ['a coffee bean pouch', 'Missionaries planted coffee on the slopes in the 1890s. In the early 1930s Chagga growers formed the Kilimanjaro Native Cooperative Union, one of Africa\'s oldest cooperatives.'],
    ],
    machame: [
      ['a mangi\'s staff', 'The Chagga lived in many small chiefdoms, each led by a mangi. In the 1800s rulers such as Rindi of Moshi and Sina of Kibosho made alliances and fought for trade.'],
      ['a caravan trade bead', 'In the 1800s caravans from the Swahili coast passed the mountain trading cloth and glass beads for ivory. Beads served as money along the way.'],
    ],
    umbwe: [
      ['Yohani Lauwo\'s walking stick', 'Yohani Kinyala Lauwo, a young Chagga man from Marangu, guided Hans Meyer and Ludwig Purtscheller on the first recorded climb to the summit in October 1889.'],
      ['Purtscheller\'s ice axe', 'Ludwig Purtscheller, an Austrian alpinist, reached the top with Hans Meyer on 6 October 1889. They called it Kaiser-Wilhelm-Spitze; in 1961 it was renamed Uhuru Peak.'],
    ],
  },
  'summit-night': {
    lemosho: [
      ['a summit certificate', 'The park gives climbers a certificate: one for reaching the crater rim at Gilman\'s or Stella Point, and a gold one for Uhuru Peak, the summit.'],
      ['a word for the mountain', 'Nobody is sure where the name Kilimanjaro comes from. One guess joins the Swahili kilima, a hill, with njaro, a word that may mean whiteness or greatness.'],
    ],
    machame: [
      ['a note from Leopard Point', 'In 1926 the pastor Richard Reusch found a frozen leopard high on the crater rim. Nobody knows why it climbed so high. Hemingway\'s story The Snows of Kilimanjaro opens with it.'],
      ['a flame of the Uhuru Torch', 'At Tanganyika\'s independence in December 1961 a torch was lit on the summit, and the highest point became Uhuru Peak: uhuru means freedom.'],
    ],
    umbwe: [
      ['an ice core marker', 'In 2000 scientists drilled through the summit glaciers. The oldest ice was about 11,700 years old. Most of the ice mapped in 1912 has since melted.'],
      ['Nyerere\'s candle', 'In 1959 Julius Nyerere said Tanganyika would light a candle on top of Kilimanjaro to shine beyond its borders: hope where there was despair, dignity where there was humiliation.'],
    ],
  },
}

export function artifactsFor(climb: ClimbKey, routeName: string): [string, string][] {
  const k = routeName.toLowerCase() as RouteKey
  return ARTIFACTS[climb][k] ?? ARTIFACTS[climb].lemosho
}

/** APK · ClimbLevel.star_count: top out; no slips that counted; every artifact kept. */
export function apkStars(kind: 'complete' | 'retreat' | 'fail', slips: number, artifacts: number, total: number) {
  if (kind !== 'complete') return 0
  return 1 + (slips === 0 ? 1 : 0) + (artifacts >= total ? 1 : 0)
}

/** APK · ClimbLevel.finish result lines, in the same order. */
export function apkResultLines(o: {
  slips: number; artifacts: number; total: number; fires: number; snacks: number
  gear: GearKind[]; gearTotal: number; hurt: number; causes: Partial<Record<SlipCause, number>>
}) {
  const lines: string[] = [
    `${o.slips === 0 ? 'Star' : 'Missed'}: no slips that counted (${o.slips}) · ${o.artifacts >= o.total ? 'Star' : 'Missed'}: artifacts ${o.artifacts} of ${o.total}`,
  ]
  if (o.gearTotal > 0) lines.push(`Gear ${o.gear.length} of ${o.gearTotal}${o.gear.length ? ` (${o.gear.map(g => GEAR[g].label.toLowerCase()).join(', ')})` : ''}`)
  if (o.fires) lines.push(`Fires at the ledges: ${o.fires} (the expedition is ${o.fires * APK.FIRE_HOURS} hour${o.fires > 1 ? 's' : ''} later)`)
  if (o.snacks) lines.push(`Camp food eaten on the climb: ${o.snacks} (supplies −${o.snacks * APK.SNACK})`)
  if (o.hurt > 0) lines.push(`Stamina lost to hits: ${Math.round(o.hurt)}`)
  const why = slipSummary(o.causes)
  if (why) lines.push(why)
  return lines
}

export function slipSummary(causes: Partial<Record<SlipCause, number>>) {
  const keys = Object.keys(causes) as SlipCause[]
  if (!keys.length) return ''
  const worst = keys.reduce((a, b) => ((causes[b] ?? 0) > (causes[a] ?? 0) ? b : a))
  return `Slips: ${keys.map(k => `${causes[k]} from ${SLIP_LESSONS[k][0]}`).join(', ')}. Try next: ${SLIP_LESSONS[worst][1]}`
}

/** Raven cycle (APK · Creatures): stand about under it and it calls, then dives where you were. */
export type RavenPhase = 'circle' | 'call' | 'dive' | 'back'
export interface Raven { phase: RavenPhase; t: number; still: number; tx: number; ty: number }
export const freshRaven = (): Raven => ({ phase: 'circle', t: 0, still: 0, tx: 0, ty: 0 })
