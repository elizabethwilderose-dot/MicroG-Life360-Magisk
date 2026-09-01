# MicroG-Life360-Magisk

**Fix "no location" in Life360 (and other Google-dependent apps) on a de-Googled Android phone running microG.**

A Magisk module that installs microG's GmsCore as a **privileged system app**, so it can register as Android's **network location provider**. Without this, microG cannot supply Wi-Fi/cell-based location, and apps that depend on it silently report no position at all.

---

## Disclaimer

**I am not a developer.** This project exists because I de-Googled my own phone, Life360 stopped reporting my location, and I wanted to understand and fix it properly rather than give up or reinstall Google Play Services.

The whole thing — diagnosis, the module, the scripts, this documentation — was built in a single working session with [Claude Code](https://claude.com/claude-code) (Claude Opus 5) driving `adb` against my own device, with me reading along and making the calls.

What that means for you:

- It was tested on **exactly one device**, listed under [Tested environment](#tested-environment).
- It modifies your system partition (systemlessly, via Magisk) and **can prevent your phone from booting if the permission whitelist is wrong**. Read [docs/06-rollback.md](docs/06-rollback.md) *before* you install.
- I can't offer support for devices I don't have. Issues and PRs from people who actually know Android internals are very welcome.

Use at your own risk. There is no warranty. See [LICENSE](LICENSE).

---

## Symptoms this fixes

If several of these match, this repo is probably relevant to you:

- Life360 shows you as **"No network or phone off"**, or your own profile says **"unable to connect"**, while the app otherwise loads fine.
- Location works **outdoors with a GPS lock**, but indoors you get nothing at all.
- `adb shell dumpsys location` lists only `passive`, `fused` and `gps` providers — **there is no `network provider`** — and every one reports `last location=null`.
- You are on a custom ROM (LineageOS, /e/OS, CalyxOS-like setups, GrapheneOS-adjacent builds) **without built-in microG support**, and installed microG yourself from the microG F-Droid repo.
- microG's own Self-Check passes (signature spoofing is fine) and you *are* signed into a Google account, yet location still never arrives.

---

## Root cause

microG's GmsCore ships a network location provider. To actually register it, Android requires the permission:

```
android.permission.INSTALL_LOCATION_PROVIDER
```

That permission has protection level `signature|privileged`. A normal app installed into `/data/app` — which is what you get installing microG from F-Droid — **can never hold it**, no matter what permissions you grant in Settings.

So microG runs, answers Google Play Services API calls, keeps your account signed in, and looks completely healthy in Self-Check — while being structurally incapable of providing network location. Android has no network location provider at all, and anything that needs one gets `null` forever.

The fix is to make microG a **privileged system app**: place its APK in `/system/priv-app/` and whitelist its privileged permissions in `/system/etc/permissions/`. Magisk does this systemlessly, so `/system` is never really modified and the change is trivially reversible.

Full write-up with the actual diagnostic output: **[docs/01-problem-and-diagnosis.md](docs/01-problem-and-diagnosis.md)**

---

## Quick start

**Prerequisites:** unlocked bootloader, Magisk installed and working, microG already installed and working (signature spoofing green in Self-Check), `adb` on your computer, and root available to `adb shell su`.

```bash
git clone https://github.com/elizabethwilderose-dot/MicroG-Life360-Magisk.git
cd MicroG-Life360-Magisk
chmod +x scripts/*.sh

# 1. Generate the permission whitelist from YOUR installed microG build
./scripts/gen-privapp-permissions.sh

# 2. Build the module zip using YOUR microG APK (nothing is downloaded)
./scripts/build-module.sh

# 3. Install dist/microg_system.zip in Magisk -> Modules -> Install from storage
#    Then reboot.

# 4. Verify
./scripts/verify.sh
```

`verify.sh` prints a PASS/FAIL checklist and deliberately **never prints your coordinates** — only whether a fix exists.

Step-by-step with expected output: **[docs/03-install.md](docs/03-install.md)**

---

## Why the APK is not in this repo

`scripts/build-module.sh` pulls the microG APK **off your own device** and builds the module around it. The APK is never committed here, for three reasons:

1. **Signature match.** Reusing the exact APK already installed means the package signature is unchanged, so your Google account, device check-in (`androidId`) and push registrations all survive. A re-signed or mismatched APK would wipe them.
2. **Version match.** You get a whitelist generated from *your* build's real manifest, not a stale list copied from someone else's.
3. It is ~100 MB, and redistribution is microG's call, not mine.

Get microG itself from the official project — **[github.com/microg/GmsCore](https://github.com/microg/GmsCore)** (releases: [github.com/microg/GmsCore/releases](https://github.com/microg/GmsCore/releases), F-Droid repo: `https://microg.org/fdroid/repo`). This repo is an unaffiliated third-party integration aid; all credit for microG belongs to the microG project.

---

## Tested environment

Tested on exactly one device. Other devices/ROMs are plausible but unverified.

| Component | Version |
|---|---|
| Device | Xiaomi Redmi Note 7 (`lavender`) |
| ROM | LineageOS 22.2-20250830-UNOFFICIAL |
| Android | 15 (SDK 35), build type `user`, `release-keys` |
| microG GmsCore | 0.3.16.252432 |
| Magisk | 30.7 (30700) |
| `ro.control_privapp_permissions` | `enforce` |
| Life360 | 26.31.0 |

Optional components used during diagnosis but **not required** by the fix: [Vector](https://github.com/JingMatrix/Vector) v2.2 (maintained LSPosed fork) and a custom Xposed module — see [extras/](extras/) and [docs/07-dead-ends.md](docs/07-dead-ends.md).

---

## Result

Before and after, on the same device, indoors, in the same spot:

| Check | Before | After |
|---|---|---|
| `network provider` in `dumpsys location` | absent | **present** |
| `INSTALL_LOCATION_PROVIDER` | not granted | **granted=true** |
| Network `last location` | `null` | **fix at ~23 m accuracy** |
| microG `pkgFlags` | normal app | **`SYSTEM … UPDATED_SYSTEM_APP`** |
| Life360 own-device status | "No network or phone off" | **live location, updating** |

Google account, check-in ID and push registrations were all preserved across the change.

---

## Repository map

```
docs/         Problem, environment, install, verification, troubleshooting,
              rollback, and an honest list of things that did NOT work
module/       Magisk module skeleton (module.prop, customize.sh, whitelist)
scripts/      Whitelist generator, module builder, verifier
extras/       Optional Xposed module that spoofs the GMS version code
              (solved a different, real problem — not this one)
```

---

## Read this before installing

Under `ro.control_privapp_permissions=enforce`, a privileged app requesting a permission that is **not** in its whitelist gets that permission denied — and on `userdebug` builds it can **prevent the system from booting**. This is why the whitelist is generated from your own APK's manifest rather than hardcoded.

Recovery is straightforward and covered in [docs/06-rollback.md](docs/06-rollback.md): hold **Volume Down** during boot for Magisk safe mode (disables all modules), or disable the module over adb.

---

## Contributing

Device reports are genuinely the most useful contribution — especially confirmations or failures on other ROMs and Android versions. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE). Not affiliated with microG, Magisk, LineageOS, Google, or Life360. All trademarks belong to their respective owners.
