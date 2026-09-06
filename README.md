<p align="center"><img src="icon.png" alt="City Builder project icon" width="192"/></p>

# City Builder

City Builder is an actively developed 3D city-building prototype for Godot
4.6.2. It began as Kenney's Starter Kit City Builder and now includes a
data-driven building catalogue, a radial construction interface, connected-town
simulation, progression, characters, dialogue, traffic, and deterministic
playtest tooling.

The playable opening starts on an empty map. Place the Town Hall, connect roads,
and follow Ambrose's guidance to establish the first homes, workplaces, shops,
and amenities.

## Quick start

### Requirements

- [Godot 4.6.2 stable](https://godotengine.org/download/archive/4.6.2-stable/)
  with the Forward+ renderer.
- Git, if you are cloning the repository.

No Node.js service, MCP server, account, or API key is required to play the
game.

### Run the game

1. Clone the repository and check out `main`.

   ```sh
   git clone https://github.com/thoxey/City-Builder.git
   cd City-Builder
   git switch main
   ```

2. Open `project.godot` in Godot 4.6.2.
3. Let the first asset import finish. The repository contains many 3D and UI
   assets, so the first import can take a while.
4. Click **Play Project**. `scenes/main.tscn` is already configured as the
   main scene.

On a fresh map, the game immediately enters the required Town Hall placement
step. Place it on valid ground to begin the opening tutorial.

## Current features

- Grid-based construction, road painting, repeat placement, rotation, and
  demolition.
- A JSON-driven building catalogue and radial build menu with live
  affordability, unlock, demand, and prerequisite reasons.
- Town Hall-rooted roads and buildable-area rules.
- Economy, demand, tier, character, patron, landmark, and land-donation
  progression.
- Community quality, housing, work, commerce, resident schedules, pedestrians,
  and pooled vehicle traffic.
- Live placement consequence previews and contextual player guidance.
- Dialogue, inbox, newspaper, notification, and opening-tutorial presentation.
- Deterministic simulation/playtest interfaces and a broad GUT regression suite.

## Controls

| Input | Action |
| --- | --- |
| <kbd>W</kbd> <kbd>A</kbd> <kbd>S</kbd> <kbd>D</kbd> | Move the camera |
| <kbd>F</kbd> | Centre the camera |
| Hold middle mouse button | Rotate the camera |
| Scroll wheel | Zoom |
| <kbd>B</kbd> or right mouse button | Open the build menu, go back, or cancel the current build context |
| Mouse, arrow keys, <kbd>Q</kbd>/<kbd>E</kbd>, or left stick | Navigate radial categories and items |
| <kbd>Enter</kbd> or gamepad confirm | Confirm the focused radial choice |
| <kbd>Esc</kbd> or gamepad cancel | Go back, close, or cancel the active tool |
| Left mouse button | Place the selected building or road |
| <kbd>Delete</kbd> | Demolish a building |
| <kbd>Z</kbd> | Rotate the building being placed |
| <kbd>1</kbd> | Save Slot 1 |
| <kbd>2</kbd> | Load Slot 1 |
| <kbd>3</kbd> | Save Slot 2 |
| <kbd>4</kbd> | Load Slot 2 |

The two slots are stored as `user://map_slot1.res` and
`user://map_slot2.res`. Loading Slot 1 also recognises the earlier
`user://map.res` file when no Slot 1 save exists.

## Content authoring

Buildings are defined under `data/buildings/`. A definition owns its stable
ID, model path, footprint, transforms, simulation profiles, and build-menu
metadata. Pool sidecars live in each category's `_pools/` directory.

- [Data editor](tools/data_editor/README.md): edit and validate buildings,
  characters, patrons, and events in the optional browser-based authoring tool.
- [Quest dialogue authoring](docs/quest-dialogue-authoring.md): event shape,
  expressions, choices, effects, and recovery rules.
- [Development guide](docs/DEVELOPMENT.md): repository layout and the complete
  verification commands.
- [Project status](docs/PROJECT_STATUS.md): implemented, partially verified,
  paused, and planned workstreams.

## Prototype status

This is a playable development prototype, not a finished release. The opening
tutorial mechanics and automated checks are implemented, but its visible
`AMBROSE PLACEHOLDER` lines deliberately identify copy that still needs a
final writing and play-feel pass. Several normal-renderer and human-playtest
gates remain open.

The first land quest and expanded townsperson cast are paused at a collaborative
creative checkpoint. The desktop save/release lifecycle and emotive world
reactions are planned rather than complete. See the
[project status](docs/PROJECT_STATUS.md) for the exact workstream breakdown.

## License and third-party material

The software license is in [LICENSE.md](LICENSE.md). Asset and dependency terms
are not uniform; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) before
redistributing the project or reusing its assets.
