# Verification Results

Date: 2026-09-04  
Godot: 4.6.2.stable.official.71f334935  
GUT: 9.3.0  
Node test runner: Vitest 4.1.2

## TypeScript server

From `server/`:

```bash
npm run build
npm test
```

Result: TypeScript compiled successfully. Vitest passed 8 test files and 28
tests; 2 opt-in live-connection tests were skipped in the normal offline run.

## Godot

From the repository root, with Godot allowed to write its normal `user://`
catalog fixtures:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless \
  --path . \
  --log-file /tmp/city-builder-gut.log \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit \
  -ginclude_subdirs \
  -gexit
```

Result: 20 scripts, 177 tests, 177 passing, 539 assertions. GUT reported no
failed, pending, or risky tests.

The suite still reports pre-existing orphan/resource cleanup warnings and
intentional warnings/errors from negative-path tests (for example malformed
catalog entries). These do not represent failed assertions. A fresh live debug
launch loaded all 30 runtime plugins, including the debug-only Playtest plugin,
with `active=true` and a discovered Builder.
