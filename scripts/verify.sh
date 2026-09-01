#!/usr/bin/env bash
#
# verify.sh
#
# Checks whether microG is correctly installed as a privileged system app and
# whether Android now has a working network location provider.
#
# Privacy: this script deliberately never prints your coordinates. The location
# check reports only whether a fix exists, so its output is safe to paste into
# an issue. Everything else it prints is version and flag information.
#
# Requires: adb, a connected device, and root via 'adb shell su'.

set -uo pipefail

PKG="com.google.android.gms"
PASS=0
FAIL=0

green() { printf '\033[0;32m%s\033[0m' "$1"; }
red()   { printf '\033[0;31m%s\033[0m' "$1"; }

ok()   { green "  PASS"; printf '  %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { red   "  FAIL"; printf '  %s\n' "$1"; FAIL=$((FAIL+1)); }
info() { printf '        %s\n' "$1"; }

command -v adb >/dev/null 2>&1 || { printf 'error: adb not found\n' >&2; exit 1; }

if [ "$(adb devices | grep -c -w "device")" -eq 0 ]; then
  printf 'error: no device connected\n' >&2
  exit 1
fi

printf '\nmicroG privileged-system-app verification\n'
printf -- '-----------------------------------------\n\n'

# --- Environment -------------------------------------------------------------
SDK="$(adb shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r')"
BUILD_TYPE="$(adb shell getprop ro.build.type 2>/dev/null | tr -d '\r')"
ENFORCE="$(adb shell getprop ro.control_privapp_permissions 2>/dev/null | tr -d '\r')"
GMS_VER="$(adb shell dumpsys package "$PKG" 2>/dev/null \
  | grep -m1 "versionName=" | sed 's/.*versionName=//' | tr -d '\r')"

info "SDK ${SDK:-?} / build type ${BUILD_TYPE:-?} / privapp mode ${ENFORCE:-unset}"
info "microG ${GMS_VER:-not installed}"
printf '\n'

# --- 1. Module mounted -------------------------------------------------------
if adb shell su -c "test -f /system/priv-app/GmsCore/GmsCore.apk" 2>/dev/null; then
  ok "module mounted at /system/priv-app/GmsCore/"
else
  bad "GmsCore.apk not found in /system/priv-app — module not mounted"
  info "check: adb shell su -c 'ls /data/adb/modules/microg_system/'"
fi

# --- 2. Recognised as a system app -------------------------------------------
FLAGS="$(adb shell dumpsys package "$PKG" 2>/dev/null | grep -m1 "pkgFlags=" | tr -d '\r')"
if printf '%s' "$FLAGS" | grep -q "SYSTEM"; then
  ok "microG has SYSTEM flag"
  printf '%s' "$FLAGS" | grep -q "UPDATED_SYSTEM_APP" \
    && info "UPDATED_SYSTEM_APP present (data copy is the active update — correct)"
else
  bad "microG is not flagged SYSTEM"
  info "reboot after installing the module, then re-run"
fi

# --- 3. The privileged permission ---------------------------------------------
if adb shell dumpsys package "$PKG" 2>/dev/null \
   | grep -q "INSTALL_LOCATION_PROVIDER: granted=true"; then
  ok "INSTALL_LOCATION_PROVIDER granted"
else
  bad "INSTALL_LOCATION_PROVIDER not granted"
  info "the whitelist was not accepted — see docs/05-troubleshooting.md"
fi

# --- 4. Provider registered ---------------------------------------------------
if adb shell dumpsys location 2>/dev/null | grep -q "network provider:"; then
  ok "network provider registered"
else
  bad "no network provider — this is the fault this module fixes"
fi

# --- 5. An actual fix ---------------------------------------------------------
# Print only presence, never the coordinates.
LOC_LINE="$(adb shell dumpsys location 2>/dev/null \
  | grep -A2 "network provider:" | grep -m1 "last location=" | tr -d '\r')"

if printf '%s' "$LOC_LINE" | grep -q "last location=Location\["; then
  ACC="$(printf '%s' "$LOC_LINE" | grep -o 'hAcc=[0-9.]*' | head -1)"
  ok "network provider has a location fix ${ACC:+(${ACC})}"
elif printf '%s' "$LOC_LINE" | grep -q "last location=null"; then
  bad "network provider registered but no fix yet"
  info "open a location-using app, wait 30-60s, re-run"
  info "also enable microG Settings > Location > Request from online service"
else
  bad "could not read location state"
fi

# --- 6. Existing state preserved ---------------------------------------------
ACCOUNTS="$(adb shell dumpsys account 2>/dev/null | grep -c "type=com.google" || true)"
if [ "${ACCOUNTS:-0}" -gt 0 ]; then
  ok "Google account present (microG state preserved)"
else
  info "no Google account registered — fine if you never added one"
fi

# --- Summary ------------------------------------------------------------------
printf '\n'
printf -- '-----------------------------------------\n'
if [ "$FAIL" -eq 0 ]; then
  green "All $PASS checks passed."; printf '\n\n'
  exit 0
else
  printf '%s passed, ' "$PASS"; red "$FAIL failed"; printf '.\n'
  printf 'See docs/05-troubleshooting.md\n\n'
  exit 1
fi
