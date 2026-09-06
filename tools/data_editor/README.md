# City Builder data editor

The data editor is an optional React/Vite authoring tool for the JSON content in
`data/`. It edits and validates characters, patrons, events, and buildings;
the Godot game remains the runtime authority.

Node.js is not required to play City Builder. Use this tool only when authoring
content.

## Setup and run

From the repository root:

```sh
npm ci --prefix tools/data_editor
npm run dev --prefix tools/data_editor
```

Open the local URL printed by Vite. `npm ci` installs the exact versions in
`package-lock.json`; do not commit `node_modules/` or `dist/`.

## Export the manifest first

The editor reads `data/events/_manifest.json`, a flattened index of the
repository's character, patron, building, event, and flag data. Refresh it
before starting an authoring session.

In the Godot editor, choose:

> **Project → Tools → Export Data Editor Manifest**

Or run the same exporter headlessly from the repository root:

```sh
"$GODOT_BIN" --headless --path . \
  -s res://addons/data_editor_tools/export_manifest_headless.gd
```

Set `GODOT_BIN` to the Godot 4.6.2 executable as described in
[the development guide](../../docs/DEVELOPMENT.md). The exporter scans
`data/characters/`, `data/patrons/`, `data/buildings/`, and
`data/events/`, then rewrites `data/events/_manifest.json`.

## Connect to the repository

The start screen offers two modes.

### Direct-write mode

Chrome and Edge support the File System Access API used by this mode.

1. Click **Pick folder…**.
2. Select the repository root—the directory containing `project.godot`.
3. Grant read/write access.
4. Edit an entry, use the validation panel, and click **Save to JSON**.

Changes are written directly to the corresponding file under `data/`. The
browser stores the directory handle in IndexedDB and asks for permission again
when needed. **Reload Manifest** rereads the generated index and overlays fresh
character, patron, and building JSON from disk.

### Upload/download mode

Firefox, Safari, and other browsers can use the fallback mode:

1. Upload `data/events/_manifest.json`.
2. Edit and validate an entry.
3. Click **Save to JSON**.
4. Move the downloaded JSON file to the entry's existing `_path` from the
   manifest, replacing the intended source file.

This mode cannot read arbitrary models or JSON files from the repository and
cannot save directly to disk. Take particular care with nested event paths and
building pool sidecars.

## Source-of-truth and save workflow

The individual JSON documents under `data/` are the authored source of truth.
The manifest is a generated working index. Direct-write saves also patch the
manifest so the open editor stays internally consistent, but the Godot exporter
still owns a complete rebuild.

After an editing session:

1. Re-run the Godot manifest exporter.
2. Review every changed JSON file and `data/events/_manifest.json`.
3. Run the editor tests and production build.
4. Run the Godot tests affected by the content.
5. Confirm `git diff --check` passes.

The browser editor does not commit changes and does not replace code review.

## Test and build

From the repository root:

```sh
npm test --prefix tools/data_editor
npm run build --prefix tools/data_editor
```

For interactive test development:

```sh
npm run test:watch --prefix tools/data_editor
```

To inspect the built application locally:

```sh
npm run preview --prefix tools/data_editor
```

## Building UI metadata

The radial build menu is data-driven. Add these fields to each standalone
building JSON, or to the pool sidecar under
`data/buildings/<category>/_pools/`:

```json
{
  "ui_group": "nature",
  "ui_order": 20,
  "ui_icon": "building_duck_pond"
}
```

`ui_group` must be one of `roads`, `homes`, `commerce`, `industry`,
`nature`, `civic`, or `landmarks`. `ui_order` is an integer used with
the stable entry ID as the deterministic tie-breaker. `ui_icon` names a PNG
in `sprites/ui/build-menu/entries/` without its extension.

Pool sidecar metadata takes precedence for the single pooled menu entry;
individual members retain their own metadata for catalogue inspection.
Invalid or missing values fall back to `landmarks`, order `1000`, and
`missing-artwork`, and emit a catalogue warning.

Do not encode affordability or unlock rules in UI metadata. Economy, Demand,
and UniqueRegistry remain the authorities; Palette publishes their current
reason-bearing decision to PlayerUI.

Building files also own their model path, footprint, transforms, and simulation
profiles. Keep IDs and cross-references stable unless a coordinated migration
updates all dependent content and tests.
