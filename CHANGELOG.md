# Changelog

All notable changes to this project are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-09-01

First public release.

### Added

- Magisk module (`module/`) that installs microG GmsCore into `/system/priv-app`
  with a `privapp-permissions` whitelist, enabling it to register as Android's
  network location provider.
- `scripts/gen-privapp-permissions.sh` — generates the whitelist from the manifest
  of the microG build actually installed on the device, rather than a hardcoded list.
- `scripts/build-module.sh` — assembles a flashable module zip using the microG APK
  pulled from the connected device, preserving its signature.
- `scripts/verify.sh` — PASS/FAIL verification of privileged status, permission grant,
  provider registration and location fix. Never prints coordinates.
- Documentation set covering diagnosis, environment, install, verification,
  troubleshooting, rollback, and approaches that did not work.
- `extras/xposed-gmsver` — optional Xposed module that spoofs the reported Google
  Play Services version code for a single target app. Solves a real but separate
  problem; not required for the location fix.

### Verified on

Xiaomi Redmi Note 7 (`lavender`), LineageOS 22.2-20250830-UNOFFICIAL,
Android 15 (SDK 35, `user`/`release-keys`), microG 0.3.16.252432, Magisk 30.7,
`ro.control_privapp_permissions=enforce`.

[1.0.0]: https://github.com/elizabethwilderose-dot/MicroG-Life360-Magisk/releases/tag/v1.0.0
