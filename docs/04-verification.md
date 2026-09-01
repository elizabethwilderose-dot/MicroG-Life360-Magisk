# 4. Verification

`./scripts/verify.sh` runs all of these and prints PASS/FAIL. Below are the manual
equivalents and what correct output looks like, so you can interpret a partial failure.

Coordinates in this document are redacted. `verify.sh` is written never to print yours.

## Check 1 — Module is mounted

```bash
adb shell su -c "ls -l /system/priv-app/GmsCore/"
```

Expected — an APK of roughly 100 MB:

```
-rw-r--r-- 1 root root 108051947 GmsCore.apk
```

Nothing listed means the module did not mount. Confirm it is enabled:
`adb shell su -c "ls /data/adb/modules/microg_system/"` and that no `disable` file exists.

## Check 2 — microG is recognised as a system app

```bash
adb shell dumpsys package com.google.android.gms | grep -E "pkgFlags|codePath"
```

Expected:

```
codePath=/data/app/~~.../com.google.android.gms-...
pkgFlags=[ SYSTEM HAS_CODE ALLOW_CLEAR_USER_DATA UPDATED_SYSTEM_APP ALLOW_BACKUP ]
codePath=/system/priv-app/GmsCore
```

Two `codePath` entries is correct and expected. `/system/priv-app/GmsCore` grants
privileged status; the `/data/app` copy supplies the running code as an *update to a
system app*. `SYSTEM` and `UPDATED_SYSTEM_APP` in `pkgFlags` are the flags that matter.

This is the same arrangement stock Play Services uses on a normal phone.

## Check 3 — The privileged permission is granted

The single most important check:

```bash
adb shell dumpsys package com.google.android.gms | grep INSTALL_LOCATION_PROVIDER
```

Expected:

```
android.permission.INSTALL_LOCATION_PROVIDER: granted=true
```

Listed without `granted=true` means the whitelist was not accepted — the permission is
requested but denied. Regenerate it with `scripts/gen-privapp-permissions.sh`, rebuild,
reinstall.

## Check 4 — The network provider is registered

The one that proves the fix:

```bash
adb shell dumpsys location | grep "provider:"
```

Expected — four providers, including `network`:

```
passive provider:
network provider:
fused provider:
gps provider:
```

Before the fix, `network provider` is absent entirely.

For more detail:

```bash
adb shell dumpsys location | grep -A4 "network provider:"
```

Healthy output shows system services consuming it:

```
network provider:
  service: ProviderRequest[@+1d0h0m0s0ms, WorkSource{1000 android}]
  listeners:
    1000/android[twilight]/... Request[@+1d0h0m0s0ms BALANCED, ...]
    1000/android[GnssService]/... Request[PASSIVE, ...]
```

## Check 5 — An actual location fix arrives

```bash
adb shell dumpsys location | grep -A1 "network provider:" | grep "last location"
```

Expected:

```
last location=Location[network <REDACTED> hAcc=23.0 et=... alt=106.0 ...]
```

`last location=null` here is the one failure that is often just timing. The provider
must be *asked* before it answers. Open a location-using app, wait 30–60 s, retry.
See [05-troubleshooting.md](05-troubleshooting.md).

## Check 6 — Nothing was broken

The system install should be invisible to microG's existing state. Confirm:

```bash
# Google account still present
adb shell dumpsys account | grep -c "type=com.google"

# Device check-in preserved — compare before/after if you recorded it
adb shell su -c "grep androidId /data/data/com.google.android.gms/shared_prefs/checkin.xml"

# Signature spoofing still requested
adb shell dumpsys package com.google.android.gms | grep FAKE_PACKAGE_SIGNATURE
```

An unchanged `androidId` means push registrations and account tokens survived. In
testing all three were preserved. The most reliable functional test remains microG's
own **Self-Check** screen: all boxes should still be ticked.

## Full expected result

| Check | Before | After |
|---|---|---|
| `/system/priv-app/GmsCore/GmsCore.apk` | absent | present |
| `pkgFlags` | ordinary app | `SYSTEM … UPDATED_SYSTEM_APP` |
| `INSTALL_LOCATION_PROVIDER` | requested, not granted | `granted=true` |
| `network provider` | absent | present, with listeners |
| network `last location` | `null` | fix, ~23 m accuracy |
