#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERIFY_TMP_ROOT="${TMPDIR:-/tmp}/starter-kit-city-builder-verify"

find_godot() {
  if [[ -n "${GODOT_BIN:-}" ]]; then
    printf '%s\n' "$GODOT_BIN"
    return
  fi
  if command -v godot >/dev/null 2>&1; then
    command -v godot
    return
  fi
  if command -v godot4 >/dev/null 2>&1; then
    command -v godot4
    return
  fi
  if [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
    printf '%s\n' "/Applications/Godot.app/Contents/MacOS/Godot"
    return
  fi
  printf '%s\n' "Godot 4.6.2 was not found. Set GODOT_BIN to the editor executable." >&2
  exit 1
}

GODOT_EXECUTABLE="$(find_godot)"
mkdir -p "$VERIFY_TMP_ROOT"

printf 'Using %s\n' "$GODOT_EXECUTABLE"
"$GODOT_EXECUTABLE" --version

printf '\nImporting project assets and scripts...\n'
"$GODOT_EXECUTABLE" \
  --headless --editor --quit \
  --path "$REPO_ROOT" \
  --log-file "$VERIFY_TMP_ROOT/import.log"

printf '\nStarting the main scene...\n'
"$GODOT_EXECUTABLE" \
  --headless \
  --path "$REPO_ROOT" \
  --quit-after 120 \
  --log-file "$VERIFY_TMP_ROOT/smoke.log"

printf '\nRunning the GUT suite...\n'
"$GODOT_EXECUTABLE" \
  --headless \
  --path "$REPO_ROOT" \
  --log-file "$VERIFY_TMP_ROOT/gut.log" \
  -s addons/gut/gut_cmdln.gd \
  -gdir=res://test \
  -ginclude_subdirs \
  -gexit

if command -v python3 >/dev/null 2>&1; then
  printf '\nChecking the ground-contact audit...\n'
  python3 "$REPO_ROOT/tools/model_ground_contact/verify_audit.py" --root "$REPO_ROOT"
fi

if [[ "${1:-}" == "--with-data-editor" ]]; then
  if ! command -v npm >/dev/null 2>&1; then
    printf '%s\n' "npm is required for --with-data-editor." >&2
    exit 1
  fi
  printf '\nInstalling and checking the optional data editor...\n'
  npm --prefix "$REPO_ROOT/tools/data_editor" ci
  npm --prefix "$REPO_ROOT/tools/data_editor" test -- --run
  npm --prefix "$REPO_ROOT/tools/data_editor" run build
fi

printf '\nVerification passed. Logs: %s\n' "$VERIFY_TMP_ROOT"
