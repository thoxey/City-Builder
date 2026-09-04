# Game UI asset production research

This reference captures the evidence behind the skill's production rules. Treat
official engine/platform documentation as authoritative for behaviour. Treat
tutorials and community reports as useful workflow evidence and failure-mode
reports, not immutable standards.

## Strong conclusions

- Build a reusable component system, not isolated screen paintings. Separate
  engine text/data from illustrated textures.
- Use nine-slice assets for resizable panels, buttons, windows, tooltips, slots,
  and bars. Record both slice margins and content-safe margins.
- Use seamless tiles or one-axis strips for paper fields, ornamental fills,
  borders, and long dividers; every tile requires a repeated proof.
- Preserve individual high-resolution sources. Build atlases and review sheets
  deterministically with region metadata.
- Small icons require actual-size review and sometimes a simplified optical
  variant; blind downscaling is not always enough.
- UI state sets need normal, hover, pressed, focus, disabled, and selected where
  relevant. Focus is its own visible overlay/state, not a synonym for hover.
- Atlas padding/extrusion and correct alpha handling prevent filtered edge bleed.
- Do not rely on colour alone; test contrast, focus, and symbols on the real game
  background.

## Official engine and tool references

- [Godot UI overview](https://docs.godotengine.org/en/stable/tutorials/ui/index.html)
- [Godot GUI skinning and themes](https://docs.godotengine.org/en/stable/tutorials/ui/gui_skinning.html)
- [Godot image importing](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html)
- [Godot NinePatchRect](https://docs.godotengine.org/en/stable/classes/class_ninepatchrect.html)
- [Godot StyleBoxTexture](https://docs.godotengine.org/en/stable/classes/class_styleboxtexture.html)
- [Godot AtlasTexture](https://docs.godotengine.org/en/stable/classes/class_atlastexture.html)
- [Godot SVG importer](https://docs.godotengine.org/en/stable/classes/class_resourceimportersvg.html)
- [Godot multiple resolutions](https://docs.godotengine.org/en/latest/tutorials/rendering/multiple_resolutions.html)
- [Unity 9-slicing](https://docs.unity.cn/6000.1/Documentation/Manual/sprite/9-slice/9-slicing.html)
- [Android Draw 9-patch](https://developer.android.com/studio/write/draw9patch)
- [Aseprite sprite-sheet export](https://www.aseprite.org/docs/sprite-sheet/)
- [TexturePacker texture settings](https://www.codeandweb.com/texturepacker/documentation/texture-settings)
- [Apple icon guidance](https://developer.apple.com/design/human-interface-guidelines/icons)
- [Apple image scale guidance](https://developer.apple.com/design/human-interface-guidelines/images)
- [Xbox text guidance](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/101)
- [Xbox contrast guidance](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/102)
- [Xbox UI focus guidance](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/113)
- [Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/basic/)

## Tutorials and practitioner discussions

- [Unity Learn: using 9-slicing for scalable sprites](https://learn.unity.com/course/developing-interactive-user-interfaces-toolkit-2019-2/tutorial/using-9-slicing-for-scalable-sprites)
- [r/gamedev: how GUI art is made](https://www.reddit.com/r/gamedev/comments/1hsar9d/how_is_gui_art_made_im_struggling/)
- [r/gamedesign: professional UI handoff and tools](https://www.reddit.com/r/gamedesign/comments/rw1ogv/what_ui_design_tools_are_mainly_used_in_the/)
- [r/gamedev: professional UI construction](https://www.reddit.com/r/gamedev/comments/1bbf4o7/how_are_professional_uis_made/)
- [r/aigamedev: AI sprite-sheet consistency failures](https://www.reddit.com/r/aigamedev/comments/1vb10r9/how_do_you_generate_assets_for_your_game/)
- [r/gamedev: individual files versus sprite sheets](https://www.reddit.com/r/gamedev/comments/1ot72nc)
- [r/gamedev: uneven sprite-sheet maintenance](https://www.reddit.com/r/gamedev/comments/1gpm1pc)
- [r/gamedev: mipmap and atlas-padding explanation](https://www.reddit.com/r/gamedev/comments/18trgnc)
- [r/UnrealEngine: atlas bleeding example](https://www.reddit.com/r/unrealengine/comments/10ics4l)

Recurring practitioner complaints are brittle fixed-resolution panels, missing
interaction states, unclear slice data, packed sheets without metadata, assets
that only look good on a clean artboard, and AI sheets with inconsistent cells.
The skill turns those complaints into explicit handoff and verification rules.
