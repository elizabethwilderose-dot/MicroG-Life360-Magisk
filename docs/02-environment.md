# 2. Environment

## What this was tested on

One device. Everything below is confirmed; anything else is an educated guess.

| Component | Value |
|---|---|
| Device | Xiaomi Redmi Note 7 (`lavender`), Snapdragon 660 |
| ROM | LineageOS `22.2-20250830-UNOFFICIAL-lavender` |
| Android | 15 |
| SDK level | 35 |
| Build type | `user` |
| Build tags | `release-keys` |
| `ro.control_privapp_permissions` | `enforce` |
| microG GmsCore | 0.3.16.252432 |
| microG Companion | 0.3.16.40226 |
| Magisk | 30.7 (30700) |
| Life360 | 26.31.0 |

Used during diagnosis, **not required** by the fix:

| Component | Version | Purpose |
|---|---|---|
| [Vector](https://github.com/JingMatrix/Vector) | v2.2 (3080) | Maintained LSPosed fork, Android 8.1–17 |
| PlayIntegrityFix | v4.7-1-inject-s | Investigated, irrelevant — see [07-dead-ends.md](07-dead-ends.md) |

## Check your own device

```bash
# ROM and Android version
adb shell getprop ro.build.version.sdk
adb shell getprop ro.lineage.version
adb shell getprop ro.build.product

# Build type — 'userdebug' means a bad whitelist is more likely to block boot
adb shell getprop ro.build.type

# Whitelist enforcement mode
adb shell getprop ro.control_privapp_permissions

# microG version (should return a version, not an error)
adb shell dumpsys package com.google.android.gms | grep versionName | head -1

# Magisk version, and confirmation that adb has root
adb shell su -c "magisk -v"
```

## What the enforcement mode means

`ro.control_privapp_permissions` controls what happens when a privileged app requests a
`signature|privileged` permission that is not in any whitelist:

| Value | Behaviour |
|---|---|
| `log` | Permission is granted; a warning is logged. Lowest risk. |
| `enforce` | Permission is **denied**. On `userdebug` builds a missing entry can also **prevent boot**. |
| unset | Treated as `log` on most builds. |

This project generates the whitelist from your installed APK precisely so that
`enforce` is safe. Do not hand-edit the generated file to remove entries.

## Requirements

- Unlocked bootloader
- Magisk installed and functional
- **microG already installed and working** — signature spoofing green in Self-Check.
  This module makes an already-working microG privileged; it is not a microG installer.
  Get microG from [github.com/microg/GmsCore](https://github.com/microg/GmsCore).
- `adb` on your computer, with working root via `adb shell su`
  (Magisk → Superuser → grant shell)
- Roughly 150 MB free in the Magisk module partition (the APK is ~100 MB)

## Portability notes

The mechanism is generic Android, not device-specific — any ROM where microG is a
normal `/data/app` install and no network location provider exists should behave the
same way. Two things are known to vary:

- **ROMs with built-in microG support** (LineageOS for microG, /e/OS, CalyxOS) already
  ship microG as a system app. This module is unnecessary there and may conflict.
- **Android 11 and earlier** used different privileged-permission plumbing. Untested.

If you try it elsewhere, please file a device report — see [CONTRIBUTING.md](../CONTRIBUTING.md).
