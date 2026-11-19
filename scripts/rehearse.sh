#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
export XDG_DATA_HOME="$FERRY_WORK/rehearsal-data"
mkdir -p "$XDG_DATA_HOME"
godot --headless --path "$ROOT/game" --script "$ROOT/tests/rehearsal.gd" "$@"
