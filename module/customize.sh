#!/system/bin/sh
# customize.sh — runs inside Magisk during module installation.
#
# Validates that this module is safe to install on THIS device before letting
# Magisk commit it. Refusing to install is always better than a device that
# will not boot.

SKIPUNZIP=0

ui_print " "
ui_print "  microG System Integration"
ui_print "  github.com/elizabethwilderose-dot/MicroG-Life360-Magisk"
ui_print " "

# --- Check 1: microG must already be installed -------------------------------
# This module makes an existing microG privileged. It is not a microG installer.
GMS_PATH="$(pm path com.google.android.gms 2>/dev/null | head -1 | sed 's/package://')"

if [ -z "$GMS_PATH" ]; then
  ui_print "  ! com.google.android.gms is not installed."
  ui_print "  ! Install microG first, confirm Self-Check passes,"
  ui_print "  ! then install this module."
  abort   "  ! Aborting."
fi

ui_print "  - Found com.google.android.gms"

# --- Check 2: the bundled APK must match the installed one -------------------
# Identical bytes mean an identical signature, which is what keeps the existing
# /data install recognised as an update to this system app. A mismatch would
# orphan the account, check-in ID and push registrations.
BUNDLED="$MODPATH/system/priv-app/GmsCore/GmsCore.apk"

if [ ! -f "$BUNDLED" ]; then
  abort "  ! Module is missing GmsCore.apk — rebuild with scripts/build-module.sh"
fi

if command -v sha256sum >/dev/null 2>&1; then
  SUM_INSTALLED="$(sha256sum "$GMS_PATH" 2>/dev/null | awk '{print $1}')"
  SUM_BUNDLED="$(sha256sum "$BUNDLED" 2>/dev/null | awk '{print $1}')"

  if [ -n "$SUM_INSTALLED" ] && [ "$SUM_INSTALLED" != "$SUM_BUNDLED" ]; then
    ui_print "  ! The bundled APK differs from the installed microG."
    ui_print "  ! Installing it would break signature matching and can"
    ui_print "  ! sign you out / reset the device check-in."
    ui_print "  !"
    ui_print "  ! Rebuild against this device:  ./scripts/build-module.sh"
    abort   "  ! Aborting."
  fi
  ui_print "  - APK matches the installed microG"
fi

# --- Check 3: the permission whitelist must be present and plausible ---------
WHITELIST="$MODPATH/system/etc/permissions/privapp-permissions-com.google.android.gms.xml"

if [ ! -f "$WHITELIST" ]; then
  ui_print "  ! Permission whitelist is missing."
  ui_print "  ! Under ro.control_privapp_permissions=enforce this can stop"
  ui_print "  ! the device from booting."
  abort   "  ! Run scripts/gen-privapp-permissions.sh and rebuild."
fi

if ! grep -q "INSTALL_LOCATION_PROVIDER" "$WHITELIST"; then
  ui_print "  ! Whitelist does not contain INSTALL_LOCATION_PROVIDER,"
  ui_print "  ! which is the entire point of this module."
  abort   "  ! Regenerate it and rebuild."
fi

PERM_COUNT="$(grep -c "<permission name=" "$WHITELIST" 2>/dev/null || echo 0)"
ui_print "  - Whitelist present ($PERM_COUNT permissions)"

if [ "$PERM_COUNT" -lt 20 ]; then
  ui_print "  ! Only $PERM_COUNT permissions — the generator likely failed."
  abort   "  ! Regenerate it rather than installing this."
fi

# --- Permissions -------------------------------------------------------------
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/system/priv-app/GmsCore/GmsCore.apk" 0 0 0644
set_perm "$WHITELIST" 0 0 0644

ui_print " "
ui_print "  Installed. Reboot to apply."
ui_print " "
ui_print "  After rebooting, verify with:  ./scripts/verify.sh"
ui_print "  If the device does not boot: hold Volume Down during"
ui_print "  boot for Magisk safe mode. See docs/06-rollback.md"
ui_print " "
