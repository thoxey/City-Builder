# Semantic input map

`build_menu` is B / gamepad Y. `radial_next` and `radial_previous` are E/Q;
standard `ui_*` actions provide keyboard and gamepad confirm, cancel, and
directional navigation, while `radial_left/right/up/down` reads the left stick
with a 0.55 dead zone. Build remains the primary mouse action only after a
Palette choice enters placement.

Builder resolves exactly one owner in this order: modal, radial, inspection,
demolition, placement, world. A radial confirmation blocks placement for the
remainder of that process frame, preventing the same click from selecting and
placing.
