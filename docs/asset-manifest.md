# Asset manifest

Pictures live in `assets/world`. Dimensions were read from the files in the repository. The repository `LICENSE` is the Expo template MIT license. It does not name the artwork. Treat the pictures as in-repo game art. None of these are a finished production set.

`frame count` is 1 for every row. Nothing in this list is a sprite sheet.

| File | Scene | Size | Status |
| --- | --- | --- | --- |
| `pixel-you.png` | Party, Barranco player | 43×96 RGBA | Used. Single image. |
| `pixel-lena.png` | Party, Barranco companion | 43×96 RGBA | Used. Single image. |
| `pixel-marco.png` | Party, Barranco companion | 43×96 RGBA | Used until his decision. |
| `pixel-jun.png` | Party diorama | 43×96 RGBA | Used on the expedition view. Not on the wall. |
| `pixel-tent.png` | Barranco camp | 96×60 RGBA | Used. Two copies at the start. |
| `far-mountains.png` | Barranco distance | 960×540 RGBA | Used. Parallax plate. |
| `clouds.png` | Barranco sky | 1139×286 RGBA | Used. Three scaled copies. |
| `ground-rock.png` | Barranco ledges and foreground | 960×540 RGBA | Used. Cropped. Transparent sky at the top. |
| `diorama-desert.jpg` | Barranco valley | 1280×720 RGB | Used. Flat plate, placeholder depth. |
| `diorama-rainforest.jpg` | Expedition diorama | 1280×720 RGB | Used by the camp view. |
| `diorama-moorland.jpg` | Expedition diorama | 1280×720 RGB | Used by the camp view. |
| `diorama-forest.jpg` | Older plate | 1280×720 RGB | Kept. Not the Barranco scene. |
| `diorama-rock.jpg` | Older plate | 1280×720 RGB | Kept. |
| `diorama-snow.jpg` | Older plate | 1280×720 RGB | Kept. |
| `diorama-valley.jpg` | Older plate | 1280×720 RGB | Kept. |
| `ground-forest.png` | Older side view | 960×357 RGBA | Kept. Unused by the scramble. |
| `ground-valley.png` | Older side view | 960×540 RGBA | Kept. |
| `ground-snow.png` | Older side view | 960×540 RGBA | Kept. |
| `foreground-snow.png` | Older snow fringe | 960×540 RGBA | Kept. Wrong biome for Barranco. |
| `camp-tents.png` | Older camp | 960×283 RGBA | Kept. |
| `everest-massif.png` | Older Everest plate | 875×417 RGBA | Kept. The playable mountain is Kilimanjaro. |
| `climber-lead.png` | Painted figure | 295×520 RGBA | Kept. Different style from the pixel party. |
| `climber-guide.png` | Painted figure | 295×520 RGBA | Kept. |
| `climber-marco.png` | Painted figure | 295×520 RGBA | Kept. |
| `climber-jun.png` | Painted figure | 295×520 RGBA | Kept. |
| `climber-kneel.png` | Painted figure | 393×520 RGBA | Kept. Not mixed into the scramble. |

Collision for the wall is numbers in `src/features/climbing/simulation/barranco.ts`, not a tile map. The walkable tops are the three platform rectangles. Artwork can move visually without changing those rectangles, and a rectangle can be solid without its own drawing.
