#!/usr/bin/env bash
# Source from any directory. Keep Godot imports, logs, tool homes and scratch on this drive.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export FERRY_WORK="${FERRY_WORK:-$ROOT/.work}"
export TMPDIR="$FERRY_WORK/tmp" XDG_DATA_HOME="$FERRY_WORK/data" XDG_CONFIG_HOME="$FERRY_WORK/config" XDG_CACHE_HOME="$FERRY_WORK/cache"
export ANDROID_USER_HOME="$FERRY_WORK/android-user" GRADLE_USER_HOME="$FERRY_WORK/gradle"
mkdir -p "$TMPDIR" "$XDG_DATA_HOME/godot/export_templates" "$XDG_CONFIG_HOME/godot" "$XDG_CACHE_HOME" "$ANDROID_USER_HOME"
export PATH="$FERRY_WORK/bin:$PATH"
if [[ -f "$FERRY_WORK/templates/android_release.apk" ]]; then
    FERRY_TEMPLATES="${FERRY_TEMPLATES:-$FERRY_WORK/templates}"
else
    FERRY_TEMPLATES="${FERRY_TEMPLATES:-$HOME/.local/share/godot/export_templates/4.7.2.stable}"
fi
if [[ -d "$FERRY_TEMPLATES" && ! -e "$XDG_DATA_HOME/godot/export_templates/4.7.2.stable" ]]; then
    ln -s "$FERRY_TEMPLATES" "$XDG_DATA_HOME/godot/export_templates/4.7.2.stable"
fi
