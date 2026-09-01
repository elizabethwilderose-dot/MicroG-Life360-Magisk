# 3. Installation

**Read [06-rollback.md](06-rollback.md) first.** This module can prevent your device
from booting if the permission whitelist is wrong. Recovery is easy, but know how
before you need it.

## Before you start

Confirm all four:

```bash
adb devices                                   # device listed, not 'unauthorized'
adb shell su -c "magisk -v"                   # Magisk version prints
adb shell dumpsys package com.google.android.gms | grep versionName | head -1
adb shell getprop ro.control_privapp_permissions
```

microG must already be installed and working. If Self-Check does not show signature
spoofing as OK, fix that first — this module will not help.

## Step 1 — Generate the permission whitelist

```bash
chmod +x scripts/*.sh          # only needed once, after cloning
./scripts/gen-privapp-permissions.sh
```

Reads the permissions your installed microG build actually requests and writes:

```
module/system/etc/permissions/privapp-permissions-com.google.android.gms.xml
```

Expected output ends with something like `wrote 61 permissions`. If it reports a
suspiciously small number (under ~30), stop — the query failed and installing the
result is unsafe.

## Step 2 — Build the module

```bash
./scripts/build-module.sh
```

This locates the microG APK on your device, pulls it, assembles the module tree, and
produces `dist/microg_system.zip`. Expect ~100 MB and a minute or two over USB.

The APK is copied byte-for-byte from your device so the signature stays identical.
This is what preserves your Google account and check-in ID.

## Step 3 — Install and reboot

Push the zip to the phone and install it through the Magisk app:

```bash
adb push dist/microg_system.zip /sdcard/Download/
```

On the phone: **Magisk → Modules → Install from storage** → select
`microg_system.zip` → **Reboot**.

Or entirely over adb:

```bash
adb shell su -c "magisk --install-module /sdcard/Download/microg_system.zip"
adb reboot
```

First boot after installation is normal speed (~20 s in testing). If the device does
not boot within about two minutes, go to [06-rollback.md](06-rollback.md).

## Step 4 — Verify

```bash
./scripts/verify.sh
```

All checks should read PASS. If the location check is the only failure, that is often
just timing — see below.

Manual equivalents and expected output: [04-verification.md](04-verification.md).

## Step 5 — Give it a location request

Registering the provider does not by itself produce a fix; something has to ask for
one. Open any app that requests location, or:

```bash
adb shell am force-stop <your.app.package>
adb shell monkey -p <your.app.package> -c android.intent.category.LAUNCHER 1
```

Wait 30–60 seconds, then re-run `./scripts/verify.sh`. The first network fix can take
a minute, particularly if Wi-Fi scanning is off.

Also confirm microG's own online lookup is enabled — **microG Settings → Location**:

- Wi-Fi location → **Request from online service**: on
- Mobile network location → **Request from online service**: on

Without these, microG has a registered provider but no source to answer with.

## Uninstalling

Magisk → Modules → remove **microG System Integration** → reboot. microG returns to
being a normal user app, keeping its data. Nothing on `/system` was ever modified.
