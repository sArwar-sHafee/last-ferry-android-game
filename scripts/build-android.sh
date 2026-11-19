#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/env.sh"
SDK="${FERRY_SDK:-$FERRY_WORK/sdk}"
JDK="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")}"
SIGNER="$SDK/build-tools/35.0.1/apksigner"
[[ -x "$SIGNER" && -x "$SDK/platform-tools/adb" ]] || { echo "Set FERRY_SDK to an Android SDK with platform-tools and build-tools 35.0.1." >&2; exit 1; }
KEY="$ANDROID_USER_HOME/debug.keystore"
if [[ ! -f "$KEY" ]]; then
    "$JDK/bin/keytool" -genkeypair -keystore "$KEY" -storepass android -keypass android -alias androiddebugkey -dname "CN=Android Debug" -keyalg RSA -keysize 2048 -validity 10000 >/dev/null
fi
cat > "$XDG_CONFIG_HOME/godot/editor_settings-4.7.tres" <<SETTINGS
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$SDK"
export/android/java_sdk_path = "$JDK"
export/android/debug_keystore = "$KEY"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
SETTINGS
mkdir -p "$ROOT/dist"
godot --headless --path "$ROOT/game" --import
# The sideload build uses optimized release templates. Users can supply their own signing key.
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-$KEY}"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="${GODOT_ANDROID_KEYSTORE_RELEASE_USER:-androiddebugkey}"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:-android}"
godot --headless --path "$ROOT/game" --export-release Android "$ROOT/dist/the-last-ferry.apk"
"$SIGNER" verify --verbose "$ROOT/dist/the-last-ferry.apk"
"$SDK/build-tools/35.0.1/zipalign" -c -P 16 4 "$ROOT/dist/the-last-ferry.apk"
(cd "$ROOT/dist" && sha256sum the-last-ferry.apk > the-last-ferry.apk.sha256)
