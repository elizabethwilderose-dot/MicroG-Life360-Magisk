# 5. Troubleshooting

Ordered roughly by how often each came up.

## Device will not boot

Go straight to [06-rollback.md](06-rollback.md). Hold **Volume Down** during boot for
Magisk safe mode, which disables every module. Then regenerate the whitelist rather
than reinstalling the same zip — a wrong whitelist is the likeliest cause.

## `network provider` present, but `last location` stays `null`

Almost always one of three things.

**1. Nothing has asked for a location.** Providers are lazy; they answer requests, they
do not poll. Open an app that uses location, wait 30–60 s, re-check.

**2. microG's online lookup is off.** In **microG Settings → Location**, enable:

- Wi-Fi location → *Request from online service*
- Mobile network location → *Request from online service*

Without a source, a registered provider has nothing to answer with. *Remember from GPS*
is a local cache, not a source — it cannot produce a first fix.

**3. Wi-Fi scanning is disabled.** Wi-Fi-based positioning needs scan results.
**Settings → Location → Location services → Wi-Fi scanning: on** (this works even with
Wi-Fi itself off). Cell-only fixes are far less accurate and sometimes unavailable.

## `INSTALL_LOCATION_PROVIDER` requested but not `granted=true`

The whitelist was not accepted. In order of likelihood:

1. The XML never landed. Check
   `adb shell su -c "ls /system/etc/permissions/ | grep gms"`.
2. Malformed XML — the parser fails silently and drops the whole file. Re-run
   `scripts/gen-privapp-permissions.sh`; do not hand-edit.
3. Wrong package attribute. It must be exactly `com.google.android.gms`.
4. Your ROM already ships a conflicting whitelist for that package. Look for another
   file in `/system/etc/permissions/` or `/vendor/etc/permissions/` naming
   `com.google.android.gms`, and merge rather than duplicate.

## Module installs but never mounts

```bash
adb shell su -c "ls -la /data/adb/modules/microg_system/"
```

- A file named `disable` present → module disabled; delete it and reboot.
- A file named `remove` present → queued for removal; delete it and reboot.
- Directory missing entirely → installation failed; re-install and read Magisk's log.
- Also confirm free space: `adb shell df -h /data`. The APK is ~100 MB.

## microG stopped working after installation

Should not happen when the APK is byte-identical, but if microG misbehaves:

1. Check the APK really matches:
   `adb shell su -c "sha256sum /system/priv-app/GmsCore/GmsCore.apk"` versus the
   `/data/app` copy. They must be identical.
2. Open microG **Self-Check**. If signature spoofing is now failing, the mismatch is
   the cause — rebuild with `scripts/build-module.sh` rather than a downloaded APK.
3. If your account was signed out, check-in was lost. Restoring it means signing in
   again; the account itself is not damaged.

## Life360 specifically still shows "No network or phone off"

- Give it time. The app pushes location on its own schedule; up to a few minutes.
- Force-stop and reopen it so it re-reads location state.
- Confirm the OS has a fix first (Check 5 in [04-verification.md](04-verification.md)).
  If Android has no fix, no app can have one — that is an OS problem, not an app problem.
- Confirm Life360 holds background location permission and is exempt from battery
  optimisation.
- If Android *has* a fix and Life360 still does not, the remaining suspect is the GMS
  version gate — a genuinely separate issue, documented in [07-dead-ends.md](07-dead-ends.md).

## `adb shell su` prompts or fails

Magisk asks for approval the first time the shell requests root, and the prompt appears
**on the phone**. Unlock the screen, run the command again, tap **Grant**. To avoid
repeats: Magisk → Superuser → shell → Grant, or set shell access to remember.

## Where to look when nothing above fits

```bash
# Boot-time permission complaints
adb logcat -d | grep -i "privapp\|not in privapp-permissions whitelist"

# Location subsystem
adb logcat -d | grep -i "LocationManager\|NetworkLocation"

# Magisk module mounting
adb shell su -c "cat /cache/magisk.log" 2>/dev/null | tail -50
```

Anything you paste into an issue: strip coordinates, account names and device IDs first.
