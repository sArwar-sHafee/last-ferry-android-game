#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
# Keep the automated pilot's logbook separate from the desktop player's.
check_run="$(mktemp -d "$FERRY_WORK/check.XXXXXXXX")"
export XDG_DATA_HOME="$check_run/data"
mkdir -p "$XDG_DATA_HOME"
godot --headless --path "$ROOT/game" --import > "$check_run/import.log" 2>&1
if grep -E 'SCRIPT ERROR|Failed to load script' "$check_run/import.log"; then exit 1; fi
godot --headless --path "$ROOT/game" --script "$ROOT/tests/voyage.gd" 2>&1 | tee "$check_run/campaign.log"
if grep -E 'SCRIPT ERROR|^ERROR:' "$check_run/campaign.log"; then exit 1; fi
