# 7. Dead ends — what did not work, and why

Most of the time spent on this problem went into approaches that turned out to be
wrong. They are documented here because a wrong theory that *sounds* right is what
actually costs people evenings, and because several of them are the top-voted answers
you will find elsewhere.

---

## Dead end 1 — "It must be Play Integrity"

**The theory.** The device has an unlocked bootloader and a custom ROM, so Google's
Play Integrity attestation fails, so Life360 refuses to work.

**Why it was believable.** It is the standard explanation for apps misbehaving on
custom ROMs, and it is genuinely true for banking and fintech apps.

**What was done.** Rooted with Magisk, installed the PlayIntegrityFix module
(v4.7-1-inject-s), rebooted, retested.

**Result.** No change whatsoever.

**Why it was wrong.** Play Integrity is a *server-side attestation* result. The failure
here was that the operating system had no network location provider at all — a local,
structural problem that no attestation result can cause or fix. The clue was that the
app worked fine in every respect *except* location.

**Worth keeping?** Root itself, yes — the actual fix needs Magisk. The PIF module is
irrelevant to this problem and can be removed.

> **Lesson.** "Custom ROM + app misbehaves" does not imply attestation. Check whether
> the specific subsystem the app needs actually exists before blaming Google.

---

## Dead end 2 — The Google Play Services version gate

**This one was a real bug. It was just not *this* bug.**

`logcat` showed, repeatedly:

```
W GooglePlayServicesUtil: Google Play services out of date for com.life360...
                          Requires 254730000 but found 250932030
```

A hard client-side gate: the app reads the installed `com.google.android.gms` package's
version code via `PackageManager` and compares it against a minimum compiled into its
bundled Google SDK. microG's version code was lower, so the check failed.

**What was tried, in order:**

1. **Updated microG** 0.3.15.250932 → 0.3.16.252432. The reported code rose to
   `252432032` — still below the required `254730000`. No newer microG existed; the
   project simply had not reached that number yet.
2. **Considered repackaging microG** with an inflated version code. Rejected: it breaks
   the APK signature, which breaks signature spoofing and wipes account state. Do not
   do this.
3. **Built a custom Xposed module** ([extras/xposed-gmsver](../extras/xposed-gmsver))
   that hooks `PackageManager.getPackageInfo()` inside one target app's process and
   rewrites the returned version code for `com.google.android.gms` only. This required
   installing [Vector](https://github.com/JingMatrix/Vector), the maintained LSPosed
   fork with Android 15 support.

**Result.** The module worked exactly as designed — the warning count went to zero,
verified in `logcat`.

**And the app still failed.** The "unable to connect" error reproduced with *zero*
version-gate warnings in the log, which proved the gate was not the cause.

**Why it was wrong.** A loud, repeating, genuinely-broken-looking error in `logcat` is
not necessarily related to the symptom you are chasing. It was a real defect worth
fixing, and it may well matter for other GMS-dependent apps — it just was not this one.

**Worth keeping?** Possibly. If an app refuses to run citing an out-of-date Play
Services, the module in `extras/` is a working solution. It is not needed for location.

> **Lesson.** Prove causation before investing. Reproducing the failure *after*
> eliminating the suspected cause takes two minutes and would have saved hours.

---

## Dead end 3 — Installing a UnifiedNlp location backend

**The theory.** microG needs a separate location backend app — the widely-cited
Nominatim Geocoder Backend or Mozilla UnifiedNlp Backend — installed from F-Droid.

**What happened.** Neither could be found in F-Droid. Investigation showed why:

- **microG dropped standalone UnifiedNlp module support at version 0.2.28.** Network
  location is now built directly into GmsCore.
- **Mozilla shut down the Mozilla Location Service**, so that backend is defunct
  regardless.
- **Nominatim is a geocoder** — it turns coordinates into street names. It never
  produced positions in the first place. In current microG it appears as
  *Address resolver → Use Nominatim*, unrelated to obtaining a fix.

**Why it was wrong.** Guides describing this step predate microG 0.2.28. In a modern
build the equivalent settings are already present under **microG Settings → Location**:
*Wi-Fi location → Request from online service* and *Mobile network location → Request
from online service*. Those toggles are the backend now.

**Worth keeping?** Enabling those two toggles: yes, required. Hunting for backend APKs:
no, obsolete.

> **Lesson.** Check the age of a guide against the version you are running. This
> ecosystem restructures faster than its documentation.

---

## Dead end 4 — Granting the permission from Settings, or via `pm grant`

**The theory.** `INSTALL_LOCATION_PROVIDER` is missing, so grant it.

**Why it cannot work.** It is not a runtime permission. Its protection level is
`signature|privileged`, which means it is granted at install time and only to apps that
are either platform-signed or installed in a privileged system directory. It never
appears in Settings, and `pm grant` rejects it. There is no amount of permission-toggling
in the UI that reaches it.

This is exactly why the fix has to change *where the APK lives* rather than what
permissions it has been given.

---

## Dead end 5 — Assuming microG was simply broken

Every visible health indicator was green throughout:

- Self-Check passed, including signature spoofing
- Google account signed in and functional
- Push messaging registered and working
- Location toggles enabled in microG's own settings

It is easy to conclude from this that microG is fine and the problem lies in the app.
Both halves are true in a sense — and neither is useful. microG *was* working correctly
within the limits of an unprivileged app. It just was not, and could not be, registered
as a system location provider.

> **Lesson.** microG's Self-Check verifies signature spoofing. It does not verify that
> microG can act as a location provider. A green Self-Check does not mean location works.

---

## Summary

| Approach | Real problem? | Fixed the location failure? |
|---|---|---|
| Play Integrity Fix module | No | No |
| GMS version-code spoofing | **Yes** | No |
| UnifiedNlp backend apps | No — obsolete | No |
| Granting the permission manually | No — impossible | No |
| **microG as privileged system app** | **Yes** | **Yes** |

The one-line version: **the problem was never Google's checks or microG's health — it
was that an unprivileged app cannot register a location provider, and nothing in the
user interface can change that.**
