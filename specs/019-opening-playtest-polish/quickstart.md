# Quickstart: Opening Playtest Polish

## 1. Focused unit and integration verification

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --log-file /tmp/city-builder-opening-polish-gut.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit/opening_tutorial,res://test/unit/dashboard,res://test/unit/placement_consequences,res://test/unit/palette,res://test/unit/player_ui,res://test/unit/demand,res://test/integration/opening_tutorial,res://test/integration/player_ui \
  -ginclude_subdirs -gexit
```

## 2. Building-data editor and manifest verification

```bash
npm --prefix tools/data_editor test
```

Regenerate and validate the ordinary event/building manifest using the repository's
existing exporter before release evidence is recorded.

## 3. Deterministic and balance verification

Run the existing automated opening balance scenario with the same declared seed before
and after implementation. Record:

- rooted-road lesson completion hour and road count;
- first-home and first-shop hours;
- Postwar Terrace availability at lifetime Homes 39 and 40;
- Pub availability at lifetime Shops 14 and 15;
- concrete seeded `grass` pool variants; and
- final semantic trace/state hashes.

Expected intentional differences are limited to the new road count, the two unlock
boundaries, and the removal of plain grass from pool results.

## 4. Save/load compatibility

Load fixtures containing:

- a historical completed four-road receipt;
- an incomplete tutorial with 9 rooted roads;
- an incomplete tutorial with 10 rooted roads; and
- an upgraded incomplete adjacency lesson with multiple existing homes but only the
  historical anchor baseline; and
- an already placed plain `grass` building.

Verify monotonic receipts, new-game threshold behavior, exact load-time baseline
migration for every eligible existing home, stable grass identity, and normal
inspection/demolition.

## 5. Visual playthrough

At 1280×720 and 1920×1080:

1. Hold a building over an unchanged valid location and verify the location panel hides.
2. Move it to a changed, invalid, replacement, and uncertain location and verify only the
   relevant rows appear.
3. Play from Town Hall through ten rooted roads, nature, homes, work, and one rooted shop.
4. Confirm the adjacency instruction says “another home,” the shop ends the tutorial,
   the first-quest handoff becomes primary, and no `0/100 fulfilled` line reads as an
   opening tutorial objective.
5. Repeatedly place from the Grass pool and confirm only the two planted variants appear.
