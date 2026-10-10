import type { Pose } from './sim';

/**
 * Sprite-sheet animation. A clip is an explicit list of sheet frames, each
 * with its own duration. Frame indices refer to the order written by
 * tools/art/characters.py; a hand-drawn replacement sheet must keep the same
 * frame size and order, or ship its own clip table.
 */
export type ClipFrame = { index: number; ms: number };
export type Clip = { frames: readonly ClipFrame[]; loop: boolean };

export type SpriteSheet = {
  source: number;
  frameWidth: number;
  frameHeight: number;
  columns: number;
  /** Pixels from the frame's left edge to the feet, and from its top to the feet. */
  anchor: { x: number; y: number };
  clips: Record<Pose, Clip>;
  /** True while the art is a stand-in, not the intended final art. */
  placeholder: boolean;
};

function frames(indices: readonly number[], ms: number): ClipFrame[] {
  return indices.map((index) => ({ index, ms }));
}

export const CLIMBER_CLIPS: Record<Pose, Clip> = {
  idle: { frames: [{ index: 0, ms: 700 }, { index: 1, ms: 500 }], loop: true },
  walk: { frames: frames([2, 3, 4, 5], 120), loop: true },
  tired: { frames: frames([23, 24, 25, 26], 190), loop: true },
  climb: { frames: frames([6, 7, 8, 9], 170), loop: true },
  hang: { frames: [{ index: 10, ms: 600 }, { index: 11, ms: 450 }], loop: true },
  fall: { frames: frames([12, 13], 90), loop: true },
  slip: { frames: [{ index: 12, ms: 90 }, { index: 13, ms: 90 }, { index: 14, ms: 160 }, { index: 15, ms: 400 }], loop: false },
  rest: { frames: [{ index: 16, ms: 800 }, { index: 17, ms: 700 }], loop: true },
  brace: { frames: [{ index: 18, ms: 1000 }], loop: true },
  help: { frames: [{ index: 19, ms: 260 }, { index: 20, ms: 260 }], loop: true },
  celebrate: { frames: [{ index: 21, ms: 300 }, { index: 22, ms: 300 }], loop: true },
};

const SHEET = { frameWidth: 24, frameHeight: 32, columns: 8, anchor: { x: 12, y: 32 }, placeholder: false };

/** Side-view party sheets from tools/art/characters.py. */
export const SHEETS = {
  you: { ...SHEET, source: require('../../../assets/hd2d/characters/you.png'), clips: CLIMBER_CLIPS },
  marco: { ...SHEET, source: require('../../../assets/hd2d/characters/marco.png'), clips: CLIMBER_CLIPS },
  lena: { ...SHEET, source: require('../../../assets/hd2d/characters/lena.png'), clips: CLIMBER_CLIPS },
  jun: { ...SHEET, source: require('../../../assets/hd2d/characters/jun.png'), clips: CLIMBER_CLIPS },
} satisfies Record<string, SpriteSheet>;

/** The sheet frame to show `elapsedMs` into a clip. */
export function frameAt(clip: Clip, elapsedMs: number): number {
  const total = clip.frames.reduce((sum, frame) => sum + frame.ms, 0);
  if (total <= 0) return clip.frames[0]?.index ?? 0;
  let t = Math.max(0, elapsedMs);
  if (clip.loop) t %= total;
  else if (t >= total) return clip.frames[clip.frames.length - 1].index;
  for (const frame of clip.frames) {
    if (t < frame.ms) return frame.index;
    t -= frame.ms;
  }
  return clip.frames[clip.frames.length - 1].index;
}

/** Source rectangle of a frame in the sheet, in sheet pixels. */
export function frameRect(sheet: Pick<SpriteSheet, 'frameWidth' | 'frameHeight' | 'columns'>, index: number) {
  return {
    x: (index % sheet.columns) * sheet.frameWidth,
    y: Math.floor(index / sheet.columns) * sheet.frameHeight,
    width: sheet.frameWidth,
    height: sheet.frameHeight,
  };
}
