# xposed-gmsver — Google Play Services version-code spoof

> **This is not the location fix.** It solves a different, unrelated problem and is
> included because it works and someone may need it. If you are here for
> "Life360 shows no location", go back to the [main README](../../README.md).

## What it does

Some apps refuse to run on microG with:

```
W GooglePlayServicesUtil: Google Play services out of date for <package>.
                          Requires 254730000 but found 252432032
```

This is a hard client-side version gate. The app reads the installed
`com.google.android.gms` package's version code through `PackageManager` and compares
it against a minimum compiled into its bundled Google SDK. microG's version code trails
what recent apps demand, so the check fails even though microG implements everything
the app actually uses.

This Xposed module hooks `PackageManager.getPackageInfo()` **inside the target app's
process only** and rewrites the version code reported for `com.google.android.gms`.
microG itself is never modified, and its own process is explicitly excluded so its
self-checks and updater keep seeing the real version.

## Why not just repackage microG?

Because editing the APK's version code breaks its signature, which breaks signature
spoofing and orphans your account and device check-in. Hooking at read time changes what
one app sees and nothing else.

## Honest status

Built and verified working: the warning count in `logcat` went from constant to zero.

It did **not** fix the problem it was built for — the "unable to connect" symptom
reproduced with zero version-gate warnings, which proved the gate was not the cause.
See [docs/07-dead-ends.md](../../docs/07-dead-ends.md).

So: a working tool for a real problem, kept for anyone hitting a genuine version gate.

## Requirements

- Root (Magisk) with Zygisk enabled
- [Vector](https://github.com/JingMatrix/Vector) — the maintained LSPosed fork, which
  supports Android 8.1–17. The original LSPosed is archived and will not work on
  Android 15.
- To build: JDK 17+, Android SDK build-tools and a platform `android.jar`.
  No Gradle, no Android Studio.

## Build

```bash
# Expects an SDK at $HOME/android-sdk with build-tools/35.0.0 and platforms/android-35
./build.sh
# -> build/gmsver.apk
```

A throwaway signing key is generated on first run if `key.jks` is absent. That key is
deliberately not distributed; build and sign your own.

## Install

```bash
adb install build/gmsver.apk
```

Then in the **Vector** manager: enable the module, scope it to **only the app you need
it for**, and force-stop that app. Do not scope it to Google Play Services or the
Play Store — those are excluded in code, but there is no reason to point it at them.

## Configure

The version code is a constant in [`src/dev/gmsver/Module.java`](src/dev/gmsver/Module.java):

```java
private static final int FAKE_VERSION_CODE = 254730000;
```

If an app demands more, raise it to at least the number in its `logcat` warning and
rebuild. Prefer the smallest value that satisfies the check — overshooting advertises
capabilities microG may not implement.

## Verify

```bash
# should print 0 once the module is active and the app restarted
adb logcat -d | grep -c "Google Play services out of date"

# module's own log line
adb logcat -d | grep "gms-version-spoof"
```

Expected:

```
[gms-version-spoof] active in <target.package>
[gms-version-spoof] rewrote com.google.android.gms versionCode -> 254730000
```

## Layout

```
AndroidManifest.xml     Xposed module metadata (xposedmodule, minversion)
assets/xposed_init      Entry-point class name
res/values/arrays.xml   Default scope hint
src/dev/gmsver/         The hook
stub/de/robv/...        Compile-only Xposed API stubs — deliberately NOT dexed
                        into the APK, or they would shadow the real framework
build.sh                Gradle-free build: javac -> d8 -> aapt2 -> zipalign -> apksigner
```
