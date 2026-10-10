# Audio

No sound files are in the game yet, and nothing waits on them. Haptics already
mark the beats below (`buzz()` in `src/features/climbing/ui/ChallengeView.tsx`)
and are skipped on devices without them.

| Cue | When it would play | Haptic now | Sound |
| --- | --- | --- | --- |
| Footsteps | walking on rock and scree | – | Missing |
| Scramble | grabbing a face, each hand move | – | Missing |
| Wind warning | gust warning on the exposed step | selection | Missing |
| Gust | the gust itself | – (camera kick) | Missing |
| Slip | a foot comes off; back to the cairn | warning | Missing |
| Cairn | reaching a checkpoint | light impact | Missing |
| Marco | reaching him; helping him up | selection; light impact | Missing |
| Top out | completing the wall | success | Missing |
| Camp | returning to the tents | – | Missing |

When sound arrives: use `expo-audio` (pinned for SDK 57 in
`bundledNativeModules.json`), respect the device's silent switch, give music
and effects separate volume settings, and add every file to
[asset-manifest.md](asset-manifest.md) with its license.
