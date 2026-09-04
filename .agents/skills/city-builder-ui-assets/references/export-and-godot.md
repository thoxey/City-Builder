# Export and Godot handoff

## Preserve masters

Keep the cleanest/highest-resolution asset in a `source` or `masters` location.
Generated raster art should normally retain at least 4× the largest expected
display dimension; the established icon masters are 1254×1254. Never enlarge a
small runtime derivative and call it a master.

Masters may be non-power-of-two. Runtime dimensions should follow actual UI and
platform needs; power-of-two is useful for some textures and atlases but is not a
universal requirement for standalone modern 2D UI textures.

## Default size policy

Choose sizes from context rather than forcing every UI object into the icon rule.

| Asset | Typical display target | Recommended retained/export strategy |
|---|---|---|
| compact metric/control icon | 16–24 px | 128 px runtime PNG plus actual-size proofs; retain high-res master |
| standard button/list icon | 24–32 px | 128 or 256 px runtime PNG |
| large menu/category icon | 48–96 px | 256 or 512 px runtime PNG |
| map marker/cursor | 24–64 px | export at largest expected display size or 2×; record pivot/hotspot |
| badge/slot/item art | 48–128 px | 256 or 512 px runtime PNG; test inside host frame |
| portrait/avatar | 128–512 px | 512–1024 px runtime crop plus larger master |
| nine-slice panel/button | variable | preserve border detail at intended UI scale; record margins/minimum size |
| tileable fill | variable area | smallest clean seamless tile, often 64–512 px depending detail frequency |
| full-screen illustration | viewport/aspect dependent | separate safe crops or largest sensible source; do not stretch blindly |

These are defaults, not limits. Record minimum, typical, and maximum display
sizes whenever an asset may appear in several contexts.

## Raster format

- Use PNG RGBA for flat illustrated UI requiring transparency.
- Use sRGB-authored colour for normal UI art; do not treat colour textures as
  linear data.
- Standardise straight versus premultiplied alpha for each runtime path. Do not
  mix an asset's edge treatment with an incompatible blend mode.
- Keep alpha edges clean against both dark and light backgrounds. Avoid baking a
  matte fringe into transparent pixels.
- Strip accidental generation metadata from runtime files, not from archival
  source files when provenance is useful.
- Avoid JPEG for sharp linework, transparency, icons, and panel borders.
- Do not bake text into image assets except intentional logos.

## Godot 4 defaults and exceptions

Godot's default 2D image import—lossless compression and no mipmaps—is a sound
starting point for UI. Filtering and repeat are CanvasItem/material behaviours in
Godot 4, not merely per-file import toggles.

- Use filtering for this antialiased illustrated style when it scales smoothly.
- Disable filtering only for deliberately pixel-exact art.
- Keep mipmaps off for UI displayed near its native size. Consider them only for
  textures that become substantially smaller/oblique or are reused in 3D; verify
  that linework does not become muddy.
- Enable repeat for tileable textures at the CanvasItem/material level and test
  seams in engine.
- Use SVG/DPITexture only for genuinely vector-friendly assets and test against
  Godot's supported SVG subset. Complex hand-inked art is safer as PNG.
- Use `NinePatchRect` or a texture-backed `StyleBoxTexture` for resizable custom
  frames. Record patch/content margins with the asset.
- Store shared colours, icons, font sizes, and StyleBoxes in a Godot `Theme`
  resource rather than duplicating local overrides across controls.
- A focus StyleBox overlays normal/pressed states, so design it as a visible
  outline or translucent accent rather than an opaque replacement.
- For responsive layouts, use Containers and anchors; the artwork should not
  encode a single fixed screen arrangement.

## Memory and packing

Disk compression is not GPU memory. A 128×128 RGBA image is roughly 64 KiB when
decoded; 52 such icons are roughly 3.25 MiB before engine/platform overhead.
Atlases can reduce state changes and file-management overhead, but use them only
when profiling or packaging justifies the added metadata and bleed risk.
Add transparent shape padding and extruded edge pixels before filtered atlas
sampling; 2–4 runtime pixels is a starting point without mipmaps, not a universal
constant. Mipmapped atlases require more separation. Avoid rotation unless the
consumer understands rotated regions, and do not trim nine-slices.

## Verification checklist

- Correct file count, names, and manifest coverage.
- Expected dimensions and RGBA mode.
- Transparent corners where the asset contract requires them.
- No matte fringe on dark or light backgrounds.
- Readable silhouette at minimum actual display size, not only zoomed in.
- Distinguishable hover/press/focus/disabled/selected states.
- No meaning conveyed by colour alone.
- Nine-slice corners retain shape at minimum, wide, and tall sizes.
- Tileables pass a 3×3 repeat proof and in-engine repeat test.
- Atlas regions have correct padding/metadata and no neighbour bleed.
- Portrait/fixed art respects crop-safe and focal regions.

## Sources and further reading

Authoritative:

- [Godot: Importing images](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html)
- [Godot: NinePatchRect](https://docs.godotengine.org/en/stable/classes/class_ninepatchrect.html)
- [Godot: AtlasTexture](https://docs.godotengine.org/en/stable/classes/class_atlastexture.html)
- [Godot: GUI skinning and Theme resources](https://docs.godotengine.org/en/stable/tutorials/ui/gui_skinning.html)
- [Godot: Multiple resolutions](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html)
- [Godot: Containers](https://docs.godotengine.org/en/stable/tutorials/ui/gui_containers.html)
- [Microsoft Xbox Accessibility Guideline 101: Text display](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/101)
- [Microsoft Xbox Accessibility Guideline 102: Contrast](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/102)
- [Microsoft Xbox Accessibility Guideline 113: UI focus](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/113)

Practitioner context—not engine contracts:

- [r/gamedev: How is GUI art made?](https://www.reddit.com/r/gamedev/comments/1hsar9d/how_is_gui_art_made_im_struggling/)
- [r/gamedesign: What UI tools and handoff look like](https://www.reddit.com/r/gamedesign/comments/rw1ogv/what_ui_design_tools_are_mainly_used_in_the/)
- [r/aigamedev: consistency problems with AI sprite sheets](https://www.reddit.com/r/aigamedev/comments/1vb10r9/how_do_you_generate_assets_for_your_game/)

Practitioner advice is useful for failure modes and workflow ideas, but validate
technical settings against current Godot documentation and the actual project.
