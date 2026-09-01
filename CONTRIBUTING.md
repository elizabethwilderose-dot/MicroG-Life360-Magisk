# Contributing

Thanks for looking. A short, honest note first: **I am not an Android developer.**
This repository documents a fix I worked out for my own phone with AI assistance,
and it has been tested on exactly one device. If you know Android internals better
than I do — and that is a low bar — corrections are genuinely welcome.

## The most useful contribution: device reports

The single biggest gap in this project is that it is verified on one device only.
If you try it, please open an issue using the **Device report** template and say so,
whether it worked or not. Include:

- Device and ROM (`ro.build.product`, `ro.lineage.version` or equivalent)
- Android version / SDK level and build type (`ro.build.type`)
- microG and Magisk versions
- Value of `ro.control_privapp_permissions`
- Output of `./scripts/verify.sh`

`verify.sh` is written not to print coordinates. Please still read anything you paste
before posting it.

## Please never include in an issue or PR

Diagnostic output from Android is full of personal data. Before pasting, strip:

- GPS coordinates and place names
- Account names and email addresses
- `androidId`, `securityToken`, device serials, IMEI
- Wi-Fi SSIDs and carrier/subscriber identifiers
- Screenshots containing names, avatars, maps or member lists

If in doubt, replace the value with `REDACTED`. Any PR containing personal data
will be asked for a rewrite before merge.

## Code changes

- Shell scripts must pass `shellcheck` — CI runs it on every push.
- Keep scripts POSIX-ish `bash`, no dependencies beyond `adb` and standard coreutils.
  The whitelist generator deliberately avoids requiring the Android SDK.
- If you change what the module writes into `/system`, update
  [docs/04-verification.md](docs/04-verification.md) and
  [docs/06-rollback.md](docs/06-rollback.md) in the same PR.

## Safety expectations

This module can prevent a device from booting if the permission whitelist is wrong.
Any change touching the whitelist, `module.prop`, or `customize.sh` must state in the
PR description how it was tested and on what device. "Looks right" is not testing.
