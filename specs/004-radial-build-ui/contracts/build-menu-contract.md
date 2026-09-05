# Contract: Build Menu Projection and Input Ownership

## Palette projection

`Palette.get_build_menu_model() -> Dictionary`

The returned value conforms to `BuildMenuModel` and:

1. includes every player-facing standalone or pooled entry exactly once;
2. preserves stable authored ordering with stable-ID tie-breaks;
3. reports availability from canonical Economy, Demand, and UniqueRegistry
   decisions rather than duplicating their rules;
4. returns player-facing reasons without exposing internal IDs;
5. returns detached arrays/dictionaries that callers cannot use to mutate
   Palette, catalog, or gameplay state;
6. changes revision only when visible menu truth changes.

## Selection command

`Palette.request_select_entry(entry_id: String) -> Dictionary`

Result fields are `accepted`, `entry_id`, `structure_index`, and `reason`.
Palette revalidates availability at command time. On acceptance it updates the
canonical selection and emits the existing palette change notification. On
rejection it retains selection and performs no gameplay mutation.

## Builder mode contract

Builder exposes mutually exclusive `world`, `radial`, `placement`, `demolition`,
`inspection`, and `modal` input modes through a narrow controller/API.

- Radial consumes pointer/keyboard/gamepad navigation and never places/removes.
- Placement uses existing validation, preview, spend, and placement paths.
- Inspection consumes its selection click as specified by Community UI.
- Dialogue and overbuild confirmation outrank every other mode.
- One physical input event cannot confirm a wedge and place a building in the
  same frame.

## Development plugin contract

- Release activation rejects `QuestDebug`, `RoadDebug`, and `Playtest`.
- Ordinary debug activation rejects `QuestDebug` UI and leaves `RoadDebug`
  disabled unless an explicit development flag is present.
- Developer state mutation is available only through existing test/playtest
  contracts; it never shares player controls.

## Accessibility contract

- Every wedge has a visible label and accessible description.
- Focus, unavailable, selected, previous/next, back, and close each have a
  distinct non-color cue.
- Keyboard/gamepad focus order matches visual clockwise order.
- Escape/cancel backs one level; focus returns to the invoking Build button when
  closed.
- Focused content remains readable at the supported text scale without clipping
  or overlapping another wedge.

## Performance contract

- Catalog-to-menu projection happens on relevant events, never `_process`.
- Warm open/navigation performs no catalog filesystem scan.
- Controls and textures are reused between openings.
- A warm open or focus move meets the 2 ms development-machine target.

