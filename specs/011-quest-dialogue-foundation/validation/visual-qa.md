# Visual QA

Validated on 2026-09-06 with the normal Godot renderer (Metal 4.0, Forward+, Apple M2
Max). `scripts/capture_dialogue_validation.gd` produced 21 deterministic PNGs and the
capture manifest in `validation/screenshots/`: seven states at each of 1280×720,
1920×1080, and 3840×2160.

Reviewed states: player active, NPC active, narration, choices, three-way counterpart
swap, long transcript/manual scrollback, and missing-art fallback.

- Ambrose remains fixed left and the current/recent NPC remains fixed right.
- Both portrait hosts sit outside the parchment with approximately 5% overlap and do
  not intersect transcript content.
- Active speakers retain a non-colour emphasis; inactive portraits are muted.
- Narration is centred and unboxed, and three-person scenes replace the right portrait
  before the next NPC row.
- Transcript rows, scrollbar, return-to-latest control, choice buttons, hint, and footer
  padding remain inside the frame at all three sizes.
- Choices are visible only after the final beat and no Continue, Finish, or Close button
  is constructed.
- The deliberate missing-art portrait and engine-rendered participant name remain
  readable.

Disposition: pass. The expression masters and derivatives are intentionally replaceable
provisional art; semantic quest data does not depend on sprite-sheet coordinates.
