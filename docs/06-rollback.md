# 6. Rollback and recovery

**Read this before installing.** Every change is reversible — Magisk overlays `/system`
rather than writing to it, so nothing is permanently modified. Worst realistic case is
a device that will not boot until you disable one module.

## Magisk safe mode — the one to remember

If the device will not boot:

1. Power off completely (hold Power ~10 s if needed).
2. Power on, and when the boot animation starts, **hold Volume Down** until it finishes.
3. Magisk boots with **every module disabled**. The device will start normally.
4. Remove or fix the module, then reboot.

This works without a computer and is the reason this project is low-risk despite
touching privileged permissions.

## Disable the module over adb

If the device boots and adb works:

```bash
adb shell su -c "touch /data/adb/modules/microg_system/disable"
adb reboot
```

Re-enable:

```bash
adb shell su -c "rm /data/adb/modules/microg_system/disable"
adb reboot
```

## Remove it permanently

```bash
adb shell su -c "touch /data/adb/modules/microg_system/remove"
adb reboot
```

Or: Magisk → Modules → **microG System Integration** → delete → reboot.

After removal microG reverts to an ordinary user app in `/data/app`, keeping all its
data — account, check-in, settings. You are back to the pre-install state: working
microG, no network location provider.

## If adb is available but root is not

From a booted device without working `su`, disable modules through the Magisk app UI
(Modules → toggle off → reboot). If the UI is unreachable, use safe mode above.

## If the device is stuck and safe mode does not help

Then the module is not your problem — but for completeness, and assuming you have the
ROM zip and a custom recovery:

```bash
# Boot to recovery, then from a PC:
adb devices                       # should list the device in recovery/sideload
```

Modules live in `/data/adb/modules/`. Recoveries that can mount `/data` can delete the
`microg_system` directory directly, which is a full uninstall.

Reflashing the ROM is a last resort and unnecessary for a module problem.

## Recommended precautions before installing

1. **Note your check-in ID**, so you can confirm afterwards that nothing was reset:

   ```bash
   adb shell su -c "grep androidId /data/data/com.google.android.gms/shared_prefs/checkin.xml"
   ```

2. **Know your Magisk version and keep the installer** available.
3. **Do not install this immediately before you need the phone.** Give yourself the
   ten minutes it might take to roll back.
4. Have USB debugging enabled and the computer already authorised, so adb works without
   needing to tap a prompt on a device that will not boot.
