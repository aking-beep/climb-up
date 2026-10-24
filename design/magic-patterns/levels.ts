// Level geometry for the played Karanga Ridge (PROPOSED: no Godot level) and
// Summit night (EXISTING level `summit-night`, laid out after
// summit_night.txt: stacked switchbacks joined by loose / face / scramble
// columns, holes in the floors, ice, a rock-step chute, rim saddles with a
// lee cairn and rest stone, Stella Point, Uhuru). Written as builder calls so
// the layout reads; in Godot this becomes a .txt map from tools/levels.
//
// Legend (APK terrain.gd): # rock · i ice · c cracked slab · C face · L loose
// · s scramble · E exposed (wind) · ~ stream (PROPOSED) · markers: P start,
// K cairn, S sign, X exit, T tent, R rest stone, r rockfall, b/d rolling
// stone, n nettle, a siafu, v raven, 1-5 gear, A/B artifacts.
// PROPOSED markers: F the Karanga stream (fill bottles), g Jun's glove,
// l/m/j Lena, Marco, Jun at the summit, U the Uhuru board.

import { Level, grid, parseLevel } from './engine'

export const KARANGA_SPAN: [number, number, number, number] = [0, 30, 91, 199]

export function buildKaranga(): Level {
  const b = grid(200, 26)
  // Karanga Camp, then down into the stream valley
  b.ground(0, 21, 19)
  b.ground(22, 23, 20); b.ground(24, 25, 21); b.ground(26, 29, 22)
  b.ground(30, 40, 24); b.rect(30, 22, 40, 23, '~')
  ;[32, 35, 38].forEach(x => b.rect(x, 22, x, 23, '#'))
  b.ground(41, 47, 22)
  b.rect(45, 16, 47, 21, 'C') // the valley wall
  // the alpine desert, rising
  b.ground(48, 57, 16); b.ground(58, 63, 15); b.ground(64, 79, 14); b.ground(76, 77, 12); b.ground(80, 93, 13)
  // the junction: a lower traverse under the crest, or up the face onto it
  b.ground(94, 127, 13); b.ground(128, 131, 15); b.ground(132, 147, 13)
  b.rect(96, 6, 147, 8, '#')
  b.rect(96, 4, 147, 5, 'E')
  b.rect(94, 6, 95, 12, 'C')
  b.rect(112, 6, 113, 8, '.') // a notch in the crest: hop it
  b.rect(124, 6, 128, 6, 'c'); b.rect(124, 7, 128, 8, '.') // a cracked slab bridge
  b.rect(146, 6, 147, 7, '.')
  b.ground(148, 149, 12); b.ground(150, 159, 11); b.ground(160, 165, 10)
  // the last rock band to Barafu
  b.ground(166, 167, 10); b.rect(166, 6, 167, 9, 's')
  b.ground(168, 185, 6); b.rect(172, 6, 173, 25, '.'); b.ground(176, 185, 5)
  b.ground(186, 199, 4)

  b.set(3, 18, 'P'); b.set(19, 18, 'K')
  b.sign(6, 18, 'Karanga 3,995 m', 'Karanga Camp · 3,995 m', 'The last water on the southern circuit. Fill your bottles at the stream below: there is none at Barafu.')
  b.set(10, 18, 'T'); b.set(14, 18, 'T')
  b.set(26, 21, 'n'); b.set(29, 21, 'F')
  b.set(60, 14, 'a'); b.set(66, 13, 'K'); b.set(70, 13, '1')
  b.sign(91, 12, 'Junction', 'The junction', 'Upper ridge: up the face and along a bare crest in the west wind, a notch to hop and a cracked slab. Lower traverse: under the crest, sheltered, but stones come down the scree and a raven works the path.')
  b.set(100, 12, 'K'); b.set(99, 5, '2'); b.set(105, 5, 'K')
  b.set(118, 9, 'v'); b.set(145, 12, 'b')
  b.set(156, 10, 'K')
  b.sign(158, 10, 'Cloud', 'The trails rejoin', 'Cloud comes up from the south by midday. Follow the cairns.')
  b.set(180, 4, 'K')
  b.sign(188, 3, 'Barafu 4,673 m', 'Barafu Camp · 4,673 m', 'Barafu is Swahili for ice. Tents on bare rock, and no water at all.')
  b.set(191, 3, 'T'); b.set(194, 3, 'T'); b.set(197, 3, 'X')

  return parseLevel(b, {
    id: 'karanga', maxSlips: 3, rockPeriod: 6, drain: 0.9, restRate: 20, cold: false, snacks: false,
    gear: [
      { kind: 'poles', where: 'Leaning on the cairn, left by a porter going down.' },
      { kind: 'shell', where: 'Wedged in a crack where the crest starts.' },
    ],
  })
}

/** Floor rows of the summit tiers, bottom (Barafu) to top (Uhuru). */
export const SUMMIT_F = [48, 41, 34, 27, 20, 13, 6]

export function buildSummit(): Level {
  const F = SUMMIT_F
  const b = grid(64, 50)
  b.rect(0, 0, 1, 49, '#'); b.rect(62, 0, 63, 49, '#')
  F.forEach(f => b.rect(2, f, 61, Math.min(49, f + 1), '#'))
  const col = (x0: number, k: number, c: string) => b.rect(x0, F[k + 1], x0 + 2, F[k] - 1, c)

  // tier 0 · Barafu, walking east
  b.set(3, 47, 'K'); b.set(4, 47, 'P')
  b.sign(7, 47, 'Barafu 4,670 m', 'Barafu · 4,670 m', 'Midnight. The crater rim is above you, a line of headlamps on the dark.')
  b.set(10, 47, 'T'); b.set(13, 47, 'T'); b.set(16, 47, '1')
  b.rect(22, 48, 26, 48, 'i'); b.rect(30, 48, 31, 49, '.')
  b.rect(38, 46, 39, 47, '#'); b.rect(44, 48, 47, 48, 'i')
  col(57, 0, 'L')

  // tier 1 · west
  b.set(52, 40, '2')
  b.rect(36, 41, 49, 41, 'i'); b.rect(33, 41, 34, 42, '.')
  b.sign(27, 40, 'Switchbacks', 'The switchbacks', 'Scree and short rock steps. The cold slows how fast your arms come back: sit at the cairns.')
  b.set(23, 40, 'K')
  b.set(2, 40, '3')
  col(4, 1, 'C')

  // tier 2 · east
  b.rect(14, 32, 15, 33, '#')
  b.rect(29, 34, 34, 34, 'i'); b.set(33, 33, 'A'); b.rect(36, 34, 37, 35, '.')
  b.set(41, 33, '#'); b.rect(43, 31, 45, 31, '#'); b.set(44, 30, 'g')
  b.set(49, 33, 'K'); b.set(53, 33, '4')
  col(57, 2, 'C'); b.set(58, 25, 'r')

  // tier 3 · west
  b.rect(46, 25, 47, 26, '#'); b.set(8, 26, 'd')
  b.set(36, 26, 'R')
  b.rect(20, 27, 21, 28, '.'); b.rect(23, 27, 27, 27, 'i')
  col(4, 3, 's')

  // tier 4 · east
  b.set(12, 19, 'K')
  b.rect(30, 20, 36, 20, 'i'); b.rect(38, 20, 39, 21, '.')
  b.rect(46, 18, 47, 19, '#')
  b.set(54, 19, '5')
  col(57, 4, 'C')

  // tier 5 · the crater rim, west: two saddles in the wind, a lee between
  b.sign(55, 12, 'Crater rim', 'The crater rim', 'Two open saddles take the wind; the rock between them is a lee, with a cairn and a rest stone. In a saddle, when the wind rises, don\'t move: REST until it passes.')
  b.rect(40, 8, 52, 12, 'E')
  b.set(37, 12, 'K'); b.set(33, 12, 'R')
  b.rect(12, 8, 29, 12, 'E')
  b.rect(20, 13, 23, 13, 'c'); b.rect(20, 14, 23, 14, '.')
  b.set(16, 12, 'B')
  b.sign(8, 12, 'Stella Pt 5,756 m', 'Stella Point · 5,756 m', 'First light. Uhuru is along the rim. The team is coming up the other line.')
  b.rect(3, F[6], 5, F[5] - 1, 's')

  // tier 6 · the summit rim to Uhuru, east
  b.rect(24, 6, 30, 6, 'i')
  b.set(42, 5, 'l'); b.set(46, 5, 'm'); b.set(50, 5, 'j'); b.set(56, 5, 'U')

  return parseLevel(b, {
    id: 'summit', maxSlips: 2, rockPeriod: 4.8, drain: 1.1, restRate: 14, cold: true, snacks: true,
    gear: [
      { kind: 'rope', where: 'By the tents at Barafu.' },
      { kind: 'crampons', where: 'Left by a party coming down.' },
      { kind: 'headlamp', where: 'In a niche off the switchbacks.' },
      { kind: 'helmet', where: 'On the bench below the last rock step.' },
      { kind: 'shell', where: 'Below the crater rim, out of the wind.' },
    ],
  })
}
