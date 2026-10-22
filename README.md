# Tesl Reborn — Android port

Android build of the Tesl Reborn client (The Elder Scrolls: Legends community server), based on decompiling the official 2.17.0 client and injecting a Frida gadget-based hook (`hook.ts`).

This document describes how to produce the **single, installable APK** that contains everything the client needs: the patched game, the original streaming assets (the OBB) and the rebuilt asset bundles.

## What you get

The final artefact (`tesl-reborn-all.apk`) is a single ~2.2 GB APK. After installing it, the hook restores, on the first run:

1. The original OBB to `/sdcard/Android/obb/com.bethsoft.theelderscrollslegends/main.11009.com.bethsoft.theelderscrollslegends.obb`.
2. The rebuilt Unity cache for the 204 bundles (manifests + audio) to the app's private `UnityCache/Shared`.

After the first run the game is fully offline: card art, voices and translations all load from local files.

## Prerequisites

- Linux x86_64.
- Python 3 (tested with 3.11+) with `lief` and `frida-compile`'s Node deps.
- Java JDK (for `uber-apk-signer` and `zipalign`).
- Android SDK build-tools (`zipalign`).
- `frida-compile` (Node.js) and the frida-gadget for Android arm64 (17.24.3).
- A Pixel-class device recommended. The Android port is built for `arm64-v8a` only.
- Tool paths expected (override via env vars/args is possible):
  - `/tmp/opencode/buildtools/android-14/zipalign`
  - `/tmp/opencode/apkbuild/uber-apk-signer.jar`
  - `/tmp/opencode/apkbuild/gadget.so`
- A working Android base APK of the game (`base.apk`, IL2CPP / arm64) placed (and renamed) at `android/base.apk`.
- The original XAPK/ApkPure package containing the OBB (`The+Elder+Scrolls_+Legends_2.17.0_APKPure.xapk`).
- The Windows build of the game in `TESL/` (or a symlink to it), used to recover the missing bundles. Symlink it from `/hdd/.../tesl-linux/TESL`.

## Build chain

The build has three independent pieces that are combined afterwards:

### 1. The patched APK (with the hook)

```bash
cd /path/to/tesl_re/android
# 1.1 Compile the hook
cd /tmp/opencode/hookbuild
cp /path/to/tesl_re/android/hook.ts .
npx frida-compile hook.ts -o hook.js
cp hook.js /path/to/tesl_re/android/hook.js
cd /path/to/tesl_re/android

# 1.2 Inject the gadget + hook into base.apk (uses lief)
export PATH=/tmp/opencode/buildtools/android-14:$PATH
cd /tmp/opencode/apkbuild
cp /path/to/tesl_re/android/hook.js .
python3 build_apk.py base.apk tesl-reborn-new.apk
# result: /tmp/opencode/apkbuild/tesl-reborn-new.apk
cp tesl-reborn-new.apk /path/to/tesl_re/android/tesl-reborn.apk
```

### 2. The rebuilt Unity cache (audio, manifests, card data)

Bundles missing since the CDN died are recovered from the Windows build. The serialized-file's `target_platform` field is patched from Windows (5) to Android (13) using UnityPy; `restore_cache.py` does all of this and packs the files as `cache/Shared`.

```bash
cd /path/to/tesl_re
python3 android/restore_cache.py
# writes android/cache/Shared/<bundleName>/<hash>/__data + __info
#   --push  also adb-pushes the cache to the device
```

Verification: ~204 bundles (~310 MB), 0 failures, `target_platform` rewritten to 13.

### 3. The single APK

Combines step 1 (the patched APK) and step 2 (the OBB + rebuilt cache) into one installable file.

```bash
cd /path/to/tesl_re/android
python3 build_single_apk.py \
    --apk tesl-reborn.apk \
    --obb main.11009.com.bethsoft.theelderscrollslegends.obb \
    --cache cache/Shared \
    --output tesl-reborn-all.apk
```

Useful flags:

- `--no-obb`  — do not embed the OBB (the APK becomes ~407 MB; install the OBB separately)
- `--no-cache` — do not embed the rebuilt cache
- `--work`     — alternate scratch directory (defaults to `work-single`)

Constraints:

- The APK is ~2.2 GB, which exceeds the 2 GB cap of the standard `zipalign` and of many installers.  To keep the native libraries correctly aligned, `build_single_apk.py` uses **`build_single_apk.append_to_apk`**, which **copies the original APK verbatim and only appends** the payload entries, keeping all existing file offsets (native `.so` alignment) untouched and avoids any alignment step. The result is re-signed with `--skipZipAlign` (uber-apk-signer).
- Use the **XAPK** route if the device's installer refuses files over 2 GB (see `build_xapk.py`).

## Building the XAPK (alternative)

```bash
cd /path/to/tesl_re/android
python3 build_xapk.py
# -> tesl-reborn.xapk (APKPure-like: patched APK + OBB + icon + manifest)
```

## Build loop on a device

```bash
adb install -r tesl-reborn-new.apk
adb shell am force-stop com.bethsoft.theelderscrollslegends
adb shell monkey -p com.bethsoft.theelderscrollslegends -c android.intent.category.LAUNCHER 1
# wait ~60 s, then inspect:
adb logcat -d -s tesl-hook:I  | tail -40
adb logcat -d -s Unity:E      | tail -20
adb shell screencap -p /sdcard/x.png ; adb pull /sdcard/x.png /tmp
```

## Key gotchas

- `android/` is often a symlink to a real directory (`/home/adria/Baixades/tesl-reborn-android`). Never pass an absolute path through `os.path.dirname` deep in `restore_cache.py`; run it from the real repository root instead.
- The `Cache_SetExpirationDelay` delay argument lives in `x2` (the second register), **not** `x1`. Writing to `x1` corrupts the cache handle and causes a SIGSEGV.
- Bundles are capped at `12960000` seconds of expiration (`Cache expiration may not be higher then 12960000`).
- The restored cache's `__info` files use the format `-1\n<epoch>\n1\n__data\n`.
- `f.save(packer="original")` (UnityPy) is essential to keep the serialized `target_platform` patch (5 → 13) without re-encoding the bundle payload.
- Add the hook's `log("...")` build marker and bump it whenever `hook.ts` changes.

## Source files

- `android/hook.ts`  — the Frida / IL2CPP hook (compiled with `frida-compile`).
- `android/build_apk.py`   — injects gadget + hook into `base.apk`.
- `android/build_single_apk.py` — appends obb + cache to the patched APK (above).
- `android/build_xapk.py`  — APKPure-like XAPK.
- `android/restore_cache.py` — recovers bundles from the Windows build and patches the platform.
- `decompiled/Assembly-CSharp/` — decompiled game reference.