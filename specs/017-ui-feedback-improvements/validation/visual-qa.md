# Visual QA

Validated on 2026-09-06 with the normal Godot renderer (Metal 4.0, Forward+,
Apple M2 Max). `scripts/capture_ui_feedback_validation.gd` produced seven PNGs
and `screenshots/manifest.json` at exact 1280×720, 1920×1080, and 3840×2160
output sizes.

## Reviewed surfaces

- Ambrose's mixed-case and repeated Opportunity, Beauty, Liveability,
  Livability, and Belonging words keep their authored spelling and each carry
  the matching inline icon. The `Beautystone` substring remains undecorated.
- The long Ambrose line wraps inside its transcript row without clipping or
  broken markup at every supported resolution.
- Homes hover copy separately shows current 18, lifetime 75, and ordered 25,
  75, and 225 lifetime targets, including Postwar Mid-Block at 75.
- The held Demonstration Home shows signed cash, Homes demand, Opportunity,
  Liveability, Beauty, and Belonging rows with icon-plus-text treatment. All
  rows remain inside the dock and clear of the screen edge.
- The animation sample presents alpha 1.00, 0.68, 0.39, 0.15, and 0.00 at
  0.0, 0.8, 1.6, 2.4, and 3.2 seconds respectively, making the steeper opening
  decay and slower final taper inspectable.

## Resolution and high-DPI disposition

The first raw 4K proof exposed physically small fixed-pixel HUD controls. The
runtime was corrected to use the established bounded authored-canvas scale for
Dialogue, StatusBar, and ToolDock: 1× through 1920 wide and 2× at 3840. Status
safe margins are adjusted around that transform, while the dock scales around
its centre-bottom pivot so dashboard insets remain physical. The hover proof
uses the same policy.

The final 3840×2160 captures show text, icons, hover details, and held rows at
the same useful physical proportion as 1920×1080; the 1280×720 compact layout
remains at 1× and unobstructed. No new raster assets were generated: all icons
come from the established game-ready UI families.

Disposition: pass at all three declared resolutions.
