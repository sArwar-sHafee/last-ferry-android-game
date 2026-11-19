#!/usr/bin/env bash
# Linux x86_64. Reuse matching tools, otherwise fetch official archives into the HDD workspace.
set -euo pipefail
source "$(dirname "$0")/env.sh"
mkdir -p "$FERRY_WORK/downloads" "$FERRY_WORK/bin"
fetch() {
    local url="$1" archive="$2" checksum="$3" verifier="$4"
    if ! [[ -f "$archive" ]] || ! echo "$checksum  $archive" | "$verifier" -c --status; then
        curl --fail --location --retry 3 --output "$archive.part" "$url"
        echo "$checksum  $archive.part" | "$verifier" -c -
        mv "$archive.part" "$archive"
    fi
}
release=https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable
if ! command -v godot >/dev/null || [[ "$(godot --version)" != 4.7.2.stable* ]]; then
    archive="$FERRY_WORK/downloads/Godot_v4.7.2-stable_linux.x86_64.zip"
    fetch "$release/${archive##*/}" "$archive" 9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65 sha512sum
    unzip -po "$archive" Godot_v4.7.2-stable_linux.x86_64 > "$FERRY_WORK/bin/godot"
    chmod +x "$FERRY_WORK/bin/godot"
fi
if [[ ! -f "$FERRY_TEMPLATES/android_release.apk" ]]; then
    archive="$FERRY_WORK/downloads/Godot_v4.7.2-stable_export_templates.tpz"
    fetch "$release/${archive##*/}" "$archive" ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079 sha512sum
    mkdir -p "$FERRY_WORK/templates"
    unzip -joq "$archive" 'templates/android*' 'templates/version.txt' -d "$FERRY_WORK/templates"
fi
sdk="$FERRY_WORK/sdk"
google=https://dl.google.com/android/repository
if [[ ! -x "$sdk/build-tools/35.0.1/apksigner" ]]; then
    archive="$FERRY_WORK/downloads/build-tools.zip"
    fetch "$google/build-tools_r35.0.1_linux.zip" "$archive" 5993499f3229a021b89f87088c57242aeefaa62316bf3d69da7de40bfd5350f1 sha256sum
    mkdir -p "$sdk/build-tools"
    unzip -oq "$archive" -d "$sdk/build-tools"
    mv "$sdk/build-tools/android-15" "$sdk/build-tools/35.0.1"
fi
if [[ ! -x "$sdk/platform-tools/adb" ]]; then
    archive="$FERRY_WORK/downloads/platform-tools.zip"
    fetch "$google/platform-tools_r37.0.1-linux.zip" "$archive" 477254aa5f903c15cf51001717bdf347fb6b53e0 sha1sum
    unzip -oq "$archive" -d "$sdk"
fi
echo "Android export tools are ready in $FERRY_WORK."
