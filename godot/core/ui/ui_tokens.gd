class_name UiTokens
extends RefCounted
## The field-journal palette and sizes of CLIMB UP 2.0, shared by every new
## screen (from the design reference's index.css). Colour never carries
## meaning alone: a state also has a word or a shape.

const PAPER := Color("#f3efe6")
const PAPER_RAISED := Color("#faf7f0")
const PAPER_SUNK := Color("#e9e3d6")
const PAPER_EDGE := Color("#cdc2ad")
const INK := Color("#1c1915")
const INK_SOFT := Color("#3a342c")
const INK_MUTED := Color("#6b6257")
const SPRUCE := Color("#1f3d34")
const SPRUCE_HOVER := Color("#2b5246")
const SPRUCE_INK := Color("#e8f0e8")
const EMBER := Color("#a8432a")
const EMBER_SOFT := Color("#d9572b")
const STAR := Color("#f2b33d")
const ROUTE := Color("#e9c46a")
const GOOD := Color("#3f8a4a")
const WARN := Color("#c9922e")
const BAD := Color("#b8432a")
const NIGHT := Color("#0b0b0e")
const SCRIM := Color(0.07, 0.06, 0.047, 0.66)
const SCRIM_SOFT := Color(0.07, 0.06, 0.047, 0.42)
const CHALK := Color("#f7f4ee")
const SKY := Color("#7f98a6")
const GLACIER := Color("#cfe0e8")
const SUMMIT_NIGHT := Color("#1b2340")
const HEADLAMP := Color("#ffd37a")

## Sizes in the 480 × 270 view (about 2.25 px per dp on a phone held
## sideways): touch targets at least 22 px (48 dp), an edge inset of 10.
const TAP := 22.0
const EDGE := 10.0
const RADIUS := 4
const TEXT_S := 7
const TEXT := 8
const TEXT_L := 10
const TITLE := 14
const HERO_TITLE := 20

## Motion: short and eased; instant with reduced motion.
const FAST := 0.12
const MEDIUM := 0.22
const SLOW := 0.36
