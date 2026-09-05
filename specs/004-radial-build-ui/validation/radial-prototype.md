# Radial prototype

Implemented a seven-category, maximum-eight-wedge annular control. Polar hit
testing ignores the 58 px centre dead zone and points beyond the 154 px outer
radius. Wedge zero starts at 12 o'clock and order proceeds clockwise. Groups of
9 or 20 entries page deterministically with Previous/Next consuming wedge
slots. The origin clamps by a 258 px content radius at 1280×720; the detail card
flips sides near the right edge. `test_radial_build_menu.gd` covers geometry,
dead zone, ordering, all page sizes, and safe-area extrema.
