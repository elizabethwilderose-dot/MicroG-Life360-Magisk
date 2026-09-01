#!/usr/bin/env bash
#
# build-module.sh
#
# Builds the flashable Magisk module zip using the microG APK pulled from the
# connected device.
#
# The APK is copied byte-for-byte from your own device rather than downloaded.
# Identical bytes mean an identical signature, so the existing /data install is
# recognised as an update to the new system app — which is what preserves your
# Google account, device check-in (androidId) and push registrations.
#
# Requires: adb, a connected device, microG installed, and either 'zip' or python3.

set -euo pipefail

PKG="com.google.android.gms"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build"
DIST_DIR="${REPO_ROOT}/dist"
OUT_ZIP="${DIST_DIR}/microg_system.zip"
WHITELIST="${REPO_ROOT}/module/system/etc/permissions/privapp-permissions-${PKG}.xml"

die() { printf 'error: %s\n' "$1" >&2; exit 1; }

command -v adb >/dev/null 2>&1 || die "adb not found in PATH"

if [ "$(adb devices | grep -c -w "device")" -eq 0 ]; then
  die "no device connected (check 'adb devices')"
fi

if [ ! -f "$WHITELIST" ]; then
  die "whitelist missing — run ./scripts/gen-privapp-permissions.sh first"
fi

if ! grep -q "INSTALL_LOCATION_PROVIDER" "$WHITELIST"; then
  die "whitelist does not contain INSTALL_LOCATION_PROVIDER — regenerate it"
fi

APK_PATH="$(adb shell pm path "$PKG" 2>/dev/null | head -1 | sed 's/package://' | tr -d '\r')"
[ -n "$APK_PATH" ] || die "$PKG is not installed on the device"

printf 'microG APK on device:\n  %s\n' "$APK_PATH"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/system/priv-app/GmsCore"
mkdir -p "$BUILD_DIR/system/etc/permissions"
mkdir -p "$DIST_DIR"

printf 'Pulling APK (~100 MB, this takes a moment)...\n'
adb pull "$APK_PATH" "$BUILD_DIR/system/priv-app/GmsCore/GmsCore.apk" >/dev/null \
  || die "failed to pull the APK"

APK_SIZE="$(wc -c < "$BUILD_DIR/system/priv-app/GmsCore/GmsCore.apk" | tr -d ' ')"
[ "$APK_SIZE" -gt 1000000 ] || die "pulled APK is only ${APK_SIZE} bytes — that is wrong"
printf 'Pulled %s bytes\n' "$APK_SIZE"

cp "$WHITELIST" "$BUILD_DIR/system/etc/permissions/"
cp "${REPO_ROOT}/module/module.prop" "$BUILD_DIR/"
cp "${REPO_ROOT}/module/customize.sh" "$BUILD_DIR/"

printf 'Packaging...\n'
rm -f "$OUT_ZIP"

if command -v zip >/dev/null 2>&1; then
  ( cd "$BUILD_DIR" && zip -qr "$OUT_ZIP" . )
elif command -v python3 >/dev/null 2>&1; then
  python3 - "$BUILD_DIR" "$OUT_ZIP" <<'PY'
import os, sys, zipfile
src, out = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk(src):
        for f in files:
            full = os.path.join(root, f)
            z.write(full, os.path.relpath(full, src))
PY
else
  die "need either 'zip' or python3 to package the module"
fi

[ -f "$OUT_ZIP" ] || die "packaging failed"

printf '\nBuilt: %s (%s bytes)\n' "$OUT_ZIP" "$(wc -c < "$OUT_ZIP" | tr -d ' ')"
cat <<EOF

Next steps:
  1. adb push "$OUT_ZIP" /sdcard/Download/
  2. Magisk -> Modules -> Install from storage -> microg_system.zip
  3. Reboot
  4. ./scripts/verify.sh

If the device does not boot: hold Volume Down during boot for Magisk
safe mode. See docs/06-rollback.md
EOF
