# Development guide

This guide defines the repository-wide setup and verification path. Feature
quickstarts under `specs/` preserve detailed or historical evidence; use the
commands here for current development.

Run commands from the repository root unless a section says otherwise.

## Requirements

- Godot 4.6.2 stable. The project uses Forward+ and `project.godot` declares
  Godot 4.6 features.
- Git.
- Node.js and npm only when working on `tools/data_editor/`.

The game itself has no Node.js, MCP, account, or hosted-service dependency.

## Select the Godot executable

On a POSIX shell, this detects the common command names and the standard macOS
application path:

```sh
if command -v godot >/dev/null 2>&1; then
  GODOT_BIN=godot
elif command -v godot4 >/dev/null 2>&1; then
  GODOT_BIN=godot4
elif [ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
  GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
else
  echo "Godot 4.6.2 was not found; set GODOT_BIN to its executable path."
  exit 1
fi

"$GODOT_BIN" --version
```

The reported version must be 4.6.2 stable. On Windows, set `GODOT_BIN` to the
full path of `Godot_v4.6.2-stable_win64.exe` and invoke it from PowerShell
with `& $env:GODOT_BIN`.

## Import and run

Open `project.godot` in the editor and wait for the first import to complete
before pressing **Play Project**. The repository is asset-heavy, so a clean
first import can take noticeably longer than later starts.

The equivalent import smoke check is:

```sh
"$GODOT_BIN" --headless --editor --quit --path .
```

That check must finish without missing-script, missing-autoload, or missing
plugin errors. The configured main scene is `scenes/main.tscn`.

Local gameplay saves use `user://map_slot1.res` and
`user://map_slot2.res`. Slot 1 loading falls back to the legacy
`user://map.res` only when the current Slot 1 file does not exist. These are
machine-local user files, never repository fixtures.

## Verification

The canonical repository verification wrapper is:

```sh
./scripts/verify.sh
```

It detects Godot, imports the project, smoke-starts the main scene, runs the
full GUT suite, and runs the model ground-contact audit when Python is
available. Include the optional data-editor install, test, and build gates with:

```sh
./scripts/verify.sh --with-data-editor
```

Use the individual commands below to reproduce or isolate each stage.

### Full Godot test suite

GUT is vendored under `addons/gut/`. The recursive suite includes unit,
integration, and contract tests under `test/`:

```sh
"$GODOT_BIN" --headless --path . \
  -s res://addons/gut/gut_cmdln.gd \
  -gdir=res://test -ginclude_subdirs -gexit
```

### Data editor

Install the lockfile-pinned dependencies, run its tests, and build the
production bundle:

```sh
npm ci --prefix tools/data_editor
npm test --prefix tools/data_editor
npm run build --prefix tools/data_editor
```

Regenerate the editor's manifest after changing building, character, patron, or
event data:

```sh
"$GODOT_BIN" --headless --path . \
  -s res://addons/data_editor_tools/export_manifest_headless.gd
```

See [the data editor guide](../tools/data_editor/README.md) for the interactive
authoring workflow.

### Building catalogue screenshots

The deterministic capture scene renders front and isometric catalogue views:

```sh
"$GODOT_BIN" --path . \
  --scene res://tools/building_capture/building_capture.tscn
```

It writes two 1024×1024 PNGs per standalone building plus a manifest under the
ignored `artifacts/building_screenshots/` directory. See
[the capture-rig guide](../tools/building_capture/README.md) for details; those
review outputs are not runtime dependencies and should not be staged.

### Patch hygiene

```sh
git diff --check
```

Review `git status --short` as well. Generated caches, dependency folders,
source archives, credentials, and local automation configuration must not be
staged accidentally.

## Clean-clone readiness policy

A change is ready for `main` only when a fresh checkout can import and play
without relying on the contributor's existing `.godot/` cache or files outside
the repository.

- Every runtime `res://` script, scene, resource, model, texture, font, and
  data reference must resolve to a tracked file.
- Tracked `project.godot` settings must not enable ignored or machine-local
  autoloads and editor plugins.
- Setup commands and tracked configuration must use repository-relative paths,
  not a contributor's absolute home-directory path.
- No optional editor or automation service may be required for **Play Project**.
- Source archives and large generation workspaces stay out of the runtime tree;
  commit only the approved runtime derivatives and the notices required to
  redistribute them.
- Validate from a clean checkout or archive when changing startup,
  dependencies, ignore rules, or asset paths. A warm local editor can hide
  missing tracked inputs.

## Optional local MCP tooling

Godot MCP tooling is an owner/developer convenience, not part of the game. The
addon, local server package, connection file, and credentials are intentionally
ignored and may be unavailable to contributors.

Keep that boundary strict:

- do not add MCP autoloads or its editor plugin to tracked `project.godot`;
- do not make runtime code import or call the local MCP addon;
- do not present `server/`, `.mcp.json`, API keys, or local ports as normal
  setup requirements; and
- mark MCP-only screenshots or playtest steps as optional evidence.

Project-owned deterministic playtest code lives in tracked Godot scripts and
tests. It must remain usable without the optional MCP transport.

## Repository map

| Path | Purpose |
| --- | --- |
| `scenes/`, `scripts/` | Main scene, shared state, core commands, and plugin loading |
| `plugins/` | Dependency-injected gameplay and presentation systems |
| `data/` | JSON-authored buildings, characters, patrons, events, and balance |
| `models/`, `sprites/`, `themes/`, `fonts/` | Runtime assets |
| `test/`, `addons/gut/` | Automated Godot tests and the vendored test runner |
| `tools/data_editor/` | Optional React/Vite content editor |
| `tools/building_capture/` | Deterministic catalogue screenshot scene; output is ignored |
| `addons/data_editor_tools/` | Godot manifest exporter for the data editor |
| `specs/` | Feature requirements, plans, task lists, and validation evidence |
| `art/` | Source, review, manifest, and selected runtime-art handoff material |

## Data and generated files

The JSON files under `data/` are authored source. The tracked
`data/events/_manifest.json` is a generated index used by the browser editor;
regenerate and review it whenever its source data changes.

`.godot/`, `node_modules/`, local `artifacts/`, MCP configuration, API keys,
and downloaded source archives are workstation state. They must not become
implicit build inputs. If a runtime derivative cannot be reproduced from
tracked sources, document that limitation and its provenance rather than
claiming the pipeline is reproducible.

Before distributing a build or copying assets elsewhere, read
[the third-party notices](../THIRD_PARTY_NOTICES.md).
