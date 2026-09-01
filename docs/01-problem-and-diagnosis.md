# 1. Problem and diagnosis

How the fault was found, in the order it was actually found — including the reasoning
that turned out to be wrong. If you only want the fix, go to
[03-install.md](03-install.md).

## The symptom

A de-Googled phone (LineageOS + self-installed microG) running Life360. The app
launched, logged in, drew the map, and listed circle members correctly. But:

- The device's own entry read **"No network or phone off"**.
- Tapping the own-profile card produced **"unable to connect"**.
- Everything else in the app worked.

The natural first assumption is a network or account problem. It was neither.

## Step 1 — Rule out the network

```bash
adb shell settings get global wifi_on        # 0  (Wi-Fi off)
adb shell ping -c 4 -W 3 8.8.8.8             # 0% packet loss over mobile data
```

Mobile data was fine. Note that `svc wifi disable` silently does nothing on modern
Android — Wi-Fi has to be turned off by hand, or you will "prove" connectivity over
the very interface you thought you disabled.

## Step 2 — Look at what the app actually says

The decisive move was reading `logcat` instead of guessing:

```bash
adb logcat -c
adb shell am force-stop com.life360.android.safetymapd
adb shell monkey -p com.life360.android.safetymapd -c android.intent.category.LAUNCHER 1
adb logcat -d | grep -i "life360\|GooglePlayServicesUtil"
```

This surfaced a real problem:

```
W GooglePlayServicesUtil: Google Play services out of date for com.life360...
                          Requires 254730000 but found 250932030
```

A hard client-side version gate: the app compares the installed `com.google.android.gms`
package's version code against a minimum compiled into its bundled Google SDK, and
microG's version code was lower.

This was worth fixing, and it *was* fixed — but **it was not the cause of the location
failure**. See [07-dead-ends.md](07-dead-ends.md). Chasing it cost hours. The lesson:
a real error in the log is not automatically *your* error.

## Step 3 — Ask the system, not the app

The question that actually mattered: does Android have a network location provider at all?

```bash
adb shell dumpsys location
```

```
Location Providers:
    passive provider:
      last location=null
    fused provider:
      last location=null
    gps provider:
      last location=null
```

Three providers. **No `network provider`.** Every one of them `null`.

That reframes everything. This is not a Life360 bug, an account problem, or an
attestation problem. The operating system has no way to determine position without a
GPS lock, so *every* app depending on network location gets nothing — indoors, forever.

## Step 4 — Why microG could not register

microG's GmsCore does implement a network location provider, and it was clearly trying
to act as one. In the GMS process:

```
D nativeloader: Configuring clns-8 for other apk /system/framework/com.android.location.provider.jar
                library_path=/data/app/~~.../com.google.android.gms-.../lib/arm64
```

It loads `com.android.location.provider.jar` — the shared library a network location
provider needs — from a path under **`/data/app`**. That path is the whole problem.

To register a location provider, Android requires:

```
android.permission.INSTALL_LOCATION_PROVIDER
```

whose protection level is **`signature|privileged`**. It can only be held by an app
that is either signed with the platform key or installed in a **privileged system
directory** (`/system/priv-app`, `/product/priv-app`, …).

microG installed from F-Droid lives in `/data/app`. It is an ordinary user app. It can
therefore *never* obtain that permission — not by granting permissions in Settings, not
via `pm grant` (this is not a runtime permission), not by enabling every toggle in
microG's own Location screen.

This is why the failure is so confusing in practice:

- microG Self-Check passes — signature spoofing is a separate mechanism and works fine.
- The Google account is signed in and functional.
- microG's Location settings show Wi-Fi and cell online lookup enabled.
- And none of it matters, because the provider was never registered with the system.

Confirming microG did request the permission but had not been granted it:

```bash
adb shell dumpsys package com.google.android.gms | grep INSTALL_LOCATION_PROVIDER
```

Requested — but no `granted=true`.

## Step 5 — The fix

Make microG a **privileged system app**:

1. Place its APK at `/system/priv-app/GmsCore/GmsCore.apk`
2. Whitelist its privileged permissions in
   `/system/etc/permissions/privapp-permissions-com.google.android.gms.xml`

Both done through a Magisk module, so `/system` is only overlaid, never actually
written, and the change is reversible by disabling one module.

Two details that matter:

**Use the exact APK already on the device.** Same bytes means same signature, so the
existing `/data` install is treated as an *update to a system app* rather than a
different package. Result:

```
pkgFlags=[ SYSTEM HAS_CODE ALLOW_CLEAR_USER_DATA UPDATED_SYSTEM_APP ALLOW_BACKUP ]
```

This is exactly how stock Play Services works on a normal phone, and it means the
Google account, device check-in (`androidId`) and push registrations all survive.

**Generate the whitelist from that APK's real manifest.** With
`ro.control_privapp_permissions=enforce`, a privileged permission missing from the
whitelist is denied — and on `userdebug` builds a missing entry can stop the device
booting. A hardcoded list copied from another build is exactly how that happens.
`scripts/gen-privapp-permissions.sh` reads the permissions the installed build actually
requests, so the list always matches.

## Result

After installing the module and rebooting:

```
network provider:
  last location=Location[network <REDACTED lat,lon> hAcc=23.0 ...]
```

A network provider exists, is being consumed by system services, and returns a fix at
roughly 23 m accuracy — indoors, in the same spot that produced `null` an hour earlier.
Life360's own-device entry changed from "No network or phone off" to a live, updating
position, and "unable to connect" on the profile screen was gone.

Boot took the usual ~20 seconds. No bootloop.

Verification commands and expected output: [04-verification.md](04-verification.md).
