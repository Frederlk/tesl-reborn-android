# Tesl Reborn — Android port

Android reimplementation of the Tesl Reborn client, based on injecting a Frida gadget-based hook (`hook.ts`).

This document describes how to produce the **single, installable XAPK** that contains everything the client needs: the patched game, the original streaming assets (the OBB) and the rebuilt asset bundles.

## What you get

The final artefact (`tesl-reborn.xapk`) is a single ~2.2 GB package. On first
launch the hook restores the rebuilt Unity cache for the ~204 missing bundles
(manifests + audio, 408 entries / ~310 MB) from the APK's own payload into the
app's `UnityCache/Shared`, so no `adb push` of bundle files is required after
install.

After that first run the game is fully offline: card art, voices and
translations all load from local files (plus the original streaming assets
that ship inside the OBB).

Important layout note: Unity's cache only finds bundles that live under
`…/UnityCache/Shared/<bundle>/<hash>/`. Putting them one level higher
(`…/UnityCache/<bundle>/<hash>/`) silently fails, in which case the game
falls back to the dead CDN. Both `restore_cache.py --push` and the payload
restore use the `Shared` level.

## Prerequisites

- Linux x86_64 (tested there; other platforms should work but untested).
- Python 3 (3.11+ recommended) with `lief` and `UnityPy` installed
  (`pip install lief UnityPy`).
- Java JDK (for `zipalign` and `uber-apk-signer.jar`).
- Android SDK build-tools 14 (`android-14-buildtools` or PATH) that
  provides `zipalign`.
- Node.js + `frida-compile` ("`cd android && npm install`") and a Frida
  gadget for Android arm64 v8a (17.24.3 for the 4.x hook layout).
- The minimum Android version is 10 (Android 14 was the test target).
- Base artefacts:
  - `base.apk`: a working arm64 / IL2CPP Android base APK of the
    game (renamed to `base.apk`).
  - `main.11009.com.bethsoft.theelderscrollslegends.obb`: the original OBB,
    extracted from the original XAPK (also shipped in the build output as
    `main.11009…obb`). Place it at `main.11009.com.bethsoft.theelderscrollslegends.obb`.
  - `versions.json`: the bundle inventory. The simplest way to
    obtain it is to extract `assets/versions.json` from the OBB above.
  - An original XAPK package (e.g. the APKPure one for version code 11009)
    to harvest `icon.png` + `manifest.json` for the new XAPK.
  - A Windows build of The Elder Scrolls: Legends, to recover the bundles
    missing from the OBB (tested against Steam).


## Prerequisites

- Linux x86_64 (it should be buildable on other platforms but I can't test it)
- Python 3 (tested with 3.11+) with `lief` and `frida-compile`'s Node deps.
- Java JDK (for `uber-apk-signer` and `zipalign`).
- Android SDK build-tools (`zipalign`).
- `frida-compile` (Node.js) and the frida-gadget for Android arm64 (17.24.3).
- The Android port is built for `arm64-v8a` only. It works on a Pixel 8 Pro but does not on an Ulefone Armor 9 (Android 10).
- A working Android base APK of the game (`base.apk`, IL2CPP / arm64) placed (and renamed) at `base.apk`.
- The original XAPK package containing the OBB (e.g. `The+Elder+Scrolls_+Legends_2.17.0_APKPure.xapk` from https://d.apkpure.com/b/XAPK/com.bethsoft.theelderscrollslegends?versionCode=11009 ), and its contents extracted as `base.apk` and `main.11009.com.bethsoft.theelderscrollslegends.obb`
- The Windows build of the game (only tested against the Steam version, but it should work with the Bethesda launcher version as well)

## Build chain

### 1. Compile the hook

```bash
node node_modules/.bin/frida-compile hook.ts -o hook.js
# rebuild_hook.sh does the same thing with the vendored node_modules.
```

### 2. Inject the gadget + hook into base.apk

```bash
python3 build_apk.py base.apk tesl-reborn-patched.apk
# -> tesl-reborn-patched.apk (hook + gadget, native libs kept aligned)
```

### 3. Rebuild the Unity cache (audio, manifests, card data)

Bundles missing since the CDN died are recovered from the Windows build.
`restore_cache.py` patches the serialized-file's `target_platform` field from
Windows (5) to Android (13) using UnityPy and writes `cache/Shared/…` (~204
bundles, ~310 MB) plus `__info` files.

```bash
python3 restore_cache.py --assets "/path/to/windows/game/dir/The Elder Scrolls Legends_Data"
#   --push  also adb-pushes cache/Shared to UnityCache/Shared on the device
```

If `--assets` is not passed the Windows build can usually be auto-located by
the script (limited; explicit path is the safe option).

Verification: ~204 bundles, 0 failures, `target_platform` rewritten to 13.
The `__info` format is `-1\n<epoch>\n1\n__data\n`.

### 4. Bake the cache + versions.json into one APK

This produces an APK that, on its first launch, restores the cache, writes
`versions.json` and only needs the OBB itself to be supplied by the installer.

```bash
# build_single_apk.py reads OBB + versions.json (from the OBB) + cache/Shared
python3 build_single_apk.py --no-obb --apk tesl-reborn-patched.apk \
    --output tesl-reborn-noobb.apk
# -> tesl-reborn-noobb.apk (~409 MB, 408 payload entries)
```

`--no-obb` is required here: the OBB is shipped inside the XAPK instead (next
step). Building with OBB baked in is possible but that makes each install carry
~1.8 GB of duplicate data; the noobb form is what the XAPK uses.

`--no-cache` / `--no-versions` exist for special builds but should not be used
for a release: they reintroduce the missing "asset map" (playmat / card art)
failures that the per-file restore exists to avoid.

### 5. Build the final XAPK

```bash
python3 build_xapk.py --apk tesl-reborn-noobb.apk --output tesl-reborn.xapk
# -> tesl-reborn.xapk (~2.2 GB: 408 MB APK + 1.8 GB OBB + icon + manifest)
```

The script reads `icon.png` and `manifest.json` from the original XAPK
(`--xapk`, defaults to `The+Elder+Scrolls_+Legends_2.17.0_APKPure.xapk`).
`build_xapk.py` validates the archive with `testzip()` before finishing.

## Build loop on a device

Useful for debugging. This requires manually pushing cache files (`python restore_cache.py --push`) and `versions.json` or installing a patched xapk first (and not uninstalling it, as that would remove all the files)

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

- The `Cache_SetExpirationDelay` delay argument lives in `x2` (the second register), **not** `x1`. Writing to `x1` corrupts the cache handle and causes a SIGSEGV.
- Bundles are capped at `12960000` seconds of expiration (`Cache expiration may not be higher then 12960000`).
- The restored cache's `__info` files use the format `-1\n<epoch>\n1\n__data\n`.
- `f.save(packer="original")` (UnityPy) is essential to keep the serialized `target_platform` patch (5 → 13) without re-encoding the bundle payload.
# Tesl Reborn — Android port

Android reimplementation of the Tesl Reborn client, based on injecting a Frida gadget-based hook (`hook.ts`).

This document describes how to produce the **single, installable XAPK** that contains everything the client needs: the patched game, the original streaming assets (the OBB) and the rebuilt asset bundles.

## What you get

The final artefact (`tesl-reborn.xapk`) is a single ~2.2 GB package. On first
launch the hook restores the rebuilt Unity cache for the ~204 missing bundles
(manifests + audio, 408 entries / ~310 MB) from the APK's own payload into the
app's `UnityCache/Shared`, so no `adb push` of bundle files is required after
install.

After that first run the game is fully offline: card art, voices and
translations all load from local files (plus the original streaming assets
that ship inside the OBB).

Important layout note: Unity's cache only finds bundles that live under
`…/UnityCache/Shared/<bundle>/<hash>/`. Putting them one level higher
(`…/UnityCache/<bundle>/<hash>/`) silently fails, in which case the game
falls back to the dead CDN. Both `restore_cache.py --push` and the payload
restore use the `Shared` level.

## Prerequisites

- Linux x86_64 (tested there; other platforms should work but untested).
- Python 3 (3.11+ recommended) with `lief` and `UnityPy` installed
  (`pip install lief UnityPy`).
- Java JDK (for `zipalign` and `uber-apk-signer.jar`).
- Android SDK build-tools 14 (`android-14-buildtools` or PATH) that
  provides `zipalign`.
- Node.js + `frida-compile` ("`cd android && npm install`") and a Frida
  gadget for Android arm64 v8a (17.24.3 for the 4.x hook layout).
- The minimum Android version is 10 (Android 14 was the test target).
- Base artefacts:
  - `base.apk`: a working arm64 / IL2CPP Android base APK of the
    game (renamed to `base.apk`).
  - `main.11009.com.bethsoft.theelderscrollslegends.obb`: the original OBB,
    extracted from the original XAPK (also shipped in the build output as
    `main.11009…obb`). Place it at `main.11009…obb`.
  - `versions.json`: the bundle inventory. The simplest way to
    obtain it is to extract `assets/versions.json` from the OBB above.
  - An original XAPK package (e.g. the APKPure one for version code 11009)
    to harvest `icon.png` + `manifest.json` for the new XAPK.
  - A Windows build of The Elder Scrolls: Legends, to recover the bundles
    missing from the OBB (tested against Steam).


## Prerequisites

- Linux x86_64 (it should be buildable on other platforms but I can't test it)
- Python 3 (tested with 3.11+) with `lief` and `frida-compile`'s Node deps.
- Java JDK (for `uber-apk-signer` and `zipalign`).
- Android SDK build-tools (`zipalign`).
- `frida-compile` (Node.js) and the frida-gadget for Android arm64 (17.24.3).
- The Android port is built for `arm64-v8a` only. It works on a Pixel 8 Pro but does not on an Ulefone Armor 9 (Android 10).
- A working Android base APK of the game (`base.apk`, IL2CPP / arm64) placed (and renamed) at `base.apk`.
- The original XAPK package containing the OBB (e.g. `The+Elder+Scrolls_+Legends_2.17.0_APKPure.xapk` from https://d.apkpure.com/b/XAPK/com.bethsoft.theelderscrollslegends?versionCode=11009 ), and its contents extracted as `base.apk` and `main.11009.com.bethsoft.theelderscrollslegends.obb`
- The Windows build of the game (only tested against the Steam version, but it should work with the Bethesda launcher version as well)

## Build chain

All steps run from the `` directory. They must be done in order.

### 1. Compile the hook

```bash
node node_modules/.bin/frida-compile hook.ts -o hook.js
# rebuild_hook.sh does the same thing with the vendored node_modules.
```

### 2. Inject the gadget + hook into base.apk

```bash
python3 build_apk.py base.apk tesl-reborn-patched.apk
# -> tesl-reborn-patched.apk (hook + gadget, native libs kept aligned)
```

### 3. Rebuild the Unity cache (audio, manifests, card data)

Bundles missing since the CDN died are recovered from the Windows build.
`restore_cache.py` patches the serialized-file's `target_platform` field from
Windows (5) to Android (13) using UnityPy and writes `cache/Shared/…` (~204
bundles, ~310 MB) plus `__info` files.

```bash
python3 restore_cache.py --assets "/path/to/windows/game/dir/The Elder Scrolls Legends_Data"
#   --push  also adb-pushes cache/Shared to UnityCache/Shared on the device
```

If `--assets` is not passed the Windows build can usually be auto-located by
the script (limited; explicit path is the safe option).

Verification: ~204 bundles, 0 failures, `target_platform` rewritten to 13.
The `__info` format is `-1\n<epoch>\n1\n__data\n`.

### 4. Bake the cache + versions.json into one APK

This produces an APK that, on its first launch, restores the cache, writes
`versions.json` and only needs the OBB itself to be supplied by the installer.

```bash
# build_single_apk.py reads OBB + versions.json (from the OBB) + cache/Shared
python3 build_single_apk.py --no-obb --apk tesl-reborn-patched.apk \
    --output tesl-reborn-noobb.apk
# -> tesl-reborn-noobb.apk (~409 MB, 408 payload entries)
```

`--no-obb` is required here: the OBB is shipped inside the XAPK instead (next
step). Building with OBB baked in is possible but that makes each install carry
~1.8 GB of duplicate data; the noobb form is what the XAPK uses.

`--no-cache` / `--no-versions` exist for special builds but should not be used
for a release: they reintroduce the missing "asset map" (playmat / card art)
failures that the per-file restore exists to avoid.

### 5. Build the final XAPK

```bash
python3 build_xapk.py --apk tesl-reborn-noobb.apk --output tesl-reborn.xapk
# -> tesl-reborn.xapk (~2.2 GB: 408 MB APK + 1.8 GB OBB + icon + manifest)
```

The script reads `icon.png` and `manifest.json` from the original XAPK
(`--xapk`, defaults to `The+Elder+Scrolls_+Legends_2.17.0_APKPure.xapk`).
`build_xapk.py` validates the archive with `testzip()` before finishing.

## Build loop on a device

Useful for debugging. This requires manually pushing cache files (`python restore_cache.py --push`) and `versions.json` or installing a patched xapk first (and not uninstalling it, as that would remove all the files)

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

- The `Cache_SetExpirationDelay` delay argument lives in `x2` (the second register), **not** `x1`. Writing to `x1` corrupts the cache handle and causes a SIGSEGV.
- Bundles are capped at `12960000` seconds of expiration (`Cache expiration may not be higher then 12960000`).
- The restored cache's `__info` files use the format `-1\n<epoch>\n1\n__data\n`.
- `f.save(packer="original")` (UnityPy) is essential to keep the serialized `target_platform` patch (5 → 13) without re-encoding the bundle payload.
- Add the hook's `log("...")` build marker and bump it whenever `hook.ts` changes.
- `apkPath()` must discover the package via `/proc/self/maps`, never
  `Application.streamingAssetsPath`: once an OBB is installed that method
  returns the OBB path and the per-file payload restore silently breaks.
- Pushed cache files belong under `…/UnityCache/Shared`. One level up means
  Unity never resolves them and the game re-downloads them from the dead CDN.

## Source files

- `hook.ts`  — the Frida / IL2CPP hook (compiled with `frida-compile`).
- `build_apk.py`   — injects gadget + hook into `base.apk`.
- `build_single_apk.py` — appends obb and/or cache to the patched APK (above).
- `build_xapk.py`  — APKPure-like XAPK.
- `restore_cache.py` — recovers bundles from the Windows build and patches the platform.
- `decompiled/Assembly-CSharp/` — decompiled game reference.

