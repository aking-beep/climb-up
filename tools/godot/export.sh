#!/bin/sh
# Builds the Godot prototype for the web and for Android.
#
#   GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64 tools/godot/export.sh [web|android|all|android-release|android-aab]
#
# Needs the official Godot 4.7.2 export templates installed (Editor >
# Manage Export Templates, or unzip the .tpz into
# ~/.local/share/godot/export_templates/4.7.2.stable/). Android also needs,
# in Editor Settings > Export > Android: a Java SDK, an Android SDK folder
# with build-tools/<ver>/apksigner, and a debug keystore.
#
# Outputs:
#   build/godot-web/            plain Godot web export (serve over http)
#   build/godot-web-artifact/   the same, packed for hosts that cap file size
#                               and type: engine gzipped and both binaries
#                               renamed to .wasm (the page's head include in
#                               export_presets.cfg maps them back)
#   build/godot-android/climb-up.apk   debug-signed, arm64
#   build/godot-android/climb-up-release.apk   release-signed (android-release)
#   build/godot-android/climb-up.aab   Play upload bundle (android-aab)
#
# Release builds read the upload key from the environment (never from the
# repository; see docs/release/android-signing.md):
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH, GODOT_ANDROID_KEYSTORE_RELEASE_USER,
#   GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
# android-aab installs the Android build template into godot/android/ (from
# the official export templates; not committed) and builds with Gradle,
# which needs network access to dl.google.com and maven.google.com.
set -e
cd "$(dirname "$0")/../.."
GODOT=${GODOT:-godot}
what=${1:-all}

"$GODOT" --headless --path godot --import >/dev/null 2>&1 || true

if [ "$what" = web ] || [ "$what" = all ]; then
  mkdir -p build/godot-web build/godot-web-artifact
  "$GODOT" --headless --path godot --export-release "Web" ../build/godot-web/index.html
  out=build/godot-web-artifact
  gzip -9 -c build/godot-web/index.wasm > $out/engine.gz.wasm
  cp build/godot-web/index.pck $out/game.pck.wasm
  for f in index.html index.js index.audio.worklet.js index.audio.position.worklet.js index.png index.icon.png index.apple-touch-icon.png; do
    cp build/godot-web/$f $out/
  done
  echo "web: build/godot-web (plain) and $out (packed)"
fi

if [ "$what" = android ] || [ "$what" = all ]; then
  mkdir -p build/godot-android
  "$GODOT" --headless --path godot --export-debug "Android" ../build/godot-android/climb-up.apk
  echo "android: build/godot-android/climb-up.apk"
fi

if [ "$what" = android-release ] || [ "$what" = android-aab ]; then
  : "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:?set the release keystore path (docs/release/android-signing.md)}"
  : "${GODOT_ANDROID_KEYSTORE_RELEASE_USER:?set the release key alias}"
  : "${GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD:?set the release key password}"
  mkdir -p build/godot-android
fi

if [ "$what" = android-release ]; then
  "$GODOT" --headless --path godot --export-release "Android" ../build/godot-android/climb-up-release.apk
  echo "android: build/godot-android/climb-up-release.apk (release-signed)"
fi

if [ "$what" = android-aab ]; then
  # Installs the Gradle build template (godot/android/, not committed) on
  # first use, then builds with Gradle.
  "$GODOT" --headless --path godot --install-android-build-template --export-release "Android Play (AAB)" ../build/godot-android/climb-up.aab
  echo "android: build/godot-android/climb-up.aab (Play upload bundle)"
fi
