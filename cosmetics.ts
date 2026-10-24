// Cosmetic-only options for "You". No currency, no purchases: every lock is a
// skill condition taken from data the game already keeps (stars,
// achievements, expedition endings). Party members keep fixed looks.

// 'cap' is used by fixed-look NPCs (camp support team) only; it is not a player option.
export type Headwear = 'helmet' | 'beanie' | 'sunhat' | 'headlamp' | 'cap' | 'none'
export type Pack = 'daypack' | 'crag' | 'expedition' | 'none'
export type BagPattern = 'plain' | 'stripe' | 'topo' | 'dots'

export interface Look {
  jacket: string
  jacketTrim: string
  headwear: Headwear
  headwearColor: string
  pack: Pack
  packColor: string
  harness: string
  chalkBag: string
  bagPattern: BagPattern
  rope: string
  skin: string
  hair: string
  /** Body type: same rig, clips, kit and unlocks for both. Default 'm'. */
  body?: 'm' | 'f'
}

export const DEFAULT_LOOK: Look = {
  jacket: '#6f7a3f', jacketTrim: '#4f5a2c', headwear: 'helmet', headwearColor: '#e9c46a',
  pack: 'crag', packColor: '#a8432a', harness: '#1f3d34', chalkBag: '#d8c7a4', bagPattern: 'stripe',
  rope: '#d9572b', skin: '#c68a62', hair: '#2a1d16',
}

/** Female default: mirrors DEFAULT_LOOK slot for slot, with its own colourway. */
export const DEFAULT_LOOK_F: Look = {
  jacket: '#2d5a4b', jacketTrim: '#1f3d34', headwear: 'helmet', headwearColor: '#d9572b',
  pack: 'crag', packColor: '#c98a2e', harness: '#a8432a', chalkBag: '#e9c46a', bagPattern: 'topo',
  rope: '#4fa3d9', skin: '#a8714f', hair: '#3a1f14', body: 'f',
}

/** Preset colourways, male and female mirrored pairs (same slots, own palettes). */
export const PRESET_LOOKS_M: Look[] = [
  DEFAULT_LOOK,
  { ...DEFAULT_LOOK, jacket: '#b4512f', jacketTrim: '#7e3520', headwear: 'beanie', headwearColor: '#f3efe6', pack: 'daypack', packColor: '#1f3d34', skin: '#7a4a2e', hair: '#1c1410' },
  { ...DEFAULT_LOOK, jacket: '#6f9fbf', jacketTrim: '#4a7593', headwear: 'sunhat', headwearColor: '#d8c7a4', pack: 'expedition', packColor: '#c98a2e', skin: '#e0b48e', hair: '#8a5a32' },
  { ...DEFAULT_LOOK, jacket: '#2b3256', jacketTrim: '#1b2340', headwear: 'headlamp', headwearColor: '#a8432a', pack: 'crag', packColor: '#3a342c', skin: '#d9a77c', hair: '#1c1915' },
]
export const PRESET_LOOKS_F: Look[] = [
  DEFAULT_LOOK_F,
  { ...DEFAULT_LOOK_F, jacket: '#c98a2e', jacketTrim: '#94621c', headwear: 'beanie', headwearColor: '#2d5a4b', pack: 'daypack', packColor: '#a8432a', skin: '#5e3a24', hair: '#120c08' },
  { ...DEFAULT_LOOK_F, jacket: '#e8e1d2', jacketTrim: '#bdb29c', headwear: 'sunhat', headwearColor: '#a8432a', pack: 'expedition', packColor: '#4a7593', skin: '#f0c9a6', hair: '#b5793e' },
  { ...DEFAULT_LOOK_F, jacket: '#6f7a3f', jacketTrim: '#4f5a2c', headwear: 'headlamp', headwearColor: '#e9c46a', pack: 'crag', packColor: '#1f3d34', skin: '#c68a62', hair: '#5a2a1e' },
]

export const SKIN_TONES = ['#f0c9a6', '#e0b48e', '#d9a77c', '#c68a62', '#a8714f', '#7a4a2e', '#5e3a24']
export const HAIR_COLORS = ['#120c08', '#2a1d16', '#3a1f14', '#5a2a1e', '#8a5a32', '#b5793e', '#d8c7a4']

export interface Option<T = string> {
  id: string
  label: string
  value: T
  trim?: string
  lock?: string // skill condition; undefined = available
  source?: 'existing' | 'new'
}

export const JACKETS: Option[] = [
  { id: 'olive', label: 'Olive', value: '#6f7a3f', trim: '#4f5a2c', source: 'existing' },
  { id: 'ember', label: 'Ember', value: '#b4512f', trim: '#7e3520' },
  { id: 'spruce', label: 'Spruce', value: '#2d5a4b', trim: '#1f3d34' },
  { id: 'glacier', label: 'Glacier', value: '#6f9fbf', trim: '#4a7593' },
  { id: 'ochre', label: 'Ochre', value: '#c98a2e', trim: '#94621c', lock: '2 stars on Warm-up Wall' },
  { id: 'saffron', label: 'Saffron', value: '#e0a52c', trim: '#a8771a', lock: 'Achievement: Daily onsight' },
  { id: 'night', label: 'Summit night', value: '#2b3256', trim: '#1b2340', lock: 'Reach Uhuru Peak' },
  { id: 'chalk', label: 'Chalk', value: '#e8e1d2', trim: '#bdb29c', lock: 'Achievement: Clean sweep' },
]

export const HEADWEAR: Option<Headwear>[] = [
  { id: 'helmet', label: 'Crag helmet', value: 'helmet' },
  { id: 'beanie', label: 'Beanie', value: 'beanie' },
  { id: 'sunhat', label: 'Sun hat', value: 'sunhat' },
  { id: 'headlamp', label: 'Buff & headlamp', value: 'headlamp', lock: '3 stars on Summit Night' },
  { id: 'none', label: 'Bare head', value: 'none' },
]

export const HEADWEAR_COLORS = ['#e9c46a', '#f3efe6', '#a8432a', '#2d5a4b', '#6f9fbf', '#1c1915']

export const PACKS: Option<Pack>[] = [
  { id: 'crag', label: 'Crag pack', value: 'crag' },
  { id: 'daypack', label: 'Daypack', value: 'daypack' },
  { id: 'expedition', label: 'Expedition 45 L', value: 'expedition', lock: 'Finish any expedition ending' },
  { id: 'none', label: 'No pack', value: 'none' },
]

export const PACK_COLORS = ['#a8432a', '#1f3d34', '#c98a2e', '#4a7593', '#3a342c']

export const HARNESSES: Option[] = [
  { id: 'spruce', label: 'Spruce', value: '#1f3d34' },
  { id: 'ember', label: 'Ember', value: '#a8432a' },
  { id: 'slate', label: 'Slate', value: '#4c5866' },
  { id: 'gold', label: 'Gold', value: '#d9a441', lock: 'Achievement: Perfect catch' },
]

export const CHALK_BAGS: Option<BagPattern>[] = [
  { id: 'plain', label: 'Canvas', value: 'plain' },
  { id: 'stripe', label: 'Ridge stripe', value: 'stripe' },
  { id: 'topo', label: 'Topo lines', value: 'topo', lock: 'Achievement: Feather touch' },
  { id: 'dots', label: 'Chalk dots', value: 'dots', lock: 'Achievement: Economy' },
]

export const BAG_COLORS = ['#d8c7a4', '#a8432a', '#2d5a4b', '#e9c46a', '#4a7593']

export const ROPES: Option[] = [
  { id: 'ember', label: 'Ember', value: '#d9572b' },
  { id: 'lime', label: 'Lime', value: '#9cc23a' },
  { id: 'sky', label: 'Sky', value: '#4fa3d9' },
  { id: 'violet', label: 'Violet', value: '#8a5cc2' },
  { id: 'sun', label: 'Sun', value: '#f2c14e', lock: 'Achievement: Run-out' },
]
