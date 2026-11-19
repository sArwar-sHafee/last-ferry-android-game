#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
export XDG_DATA_HOME="$FERRY_WORK/preview-data" FERRY_PREVIEWS="$FERRY_WORK/previews"
mkdir -p "$XDG_DATA_HOME" "$FERRY_PREVIEWS"
godot --path "$ROOT/game" --resolution 960x540 --audio-driver Dummy --script "$ROOT/tests/preview.gd" "$@"
