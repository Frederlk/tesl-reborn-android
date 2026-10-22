#!/usr/bin/env python3
"""Inject frida-gadget + the TESL hook script into the Android APK (arm64-v8a only)."""
import json, os, shutil, subprocess, sys, zipfile, lief

SRC      = sys.argv[1] if len(sys.argv) > 1 else "base.apk"
OUT_NAME = sys.argv[2] if len(sys.argv) > 2 else "tesl-reborn.apk"
GADGET   = "gadget.so"            # frida-gadget-17.24.3-android-arm64.so (decompressed)
HOOK_JS  = "hook.js"              # output of frida-compile
ABI      = "lib/arm64-v8a"
WORK     = "work"

lief.logging.disable()
shutil.rmtree(WORK, ignore_errors=True); os.makedirs(WORK)

# 1) make libmain.so load the gadget (adds DT_NEEDED libgadget.so)
with zipfile.ZipFile(SRC) as z:
    z.extract(f"{ABI}/libmain.so", WORK)
libmain = os.path.join(WORK, ABI, "libmain.so")
elf = lief.parse(libmain)
elf.add_library("libgadget.so")
elf.write(libmain)
print("DT_NEEDED now:", [getattr(l, "name", l) for l in lief.parse(libmain).libraries])

# 2) gadget config: run our script, never wait for a debugger
cfg = {"interaction": {"type": "script", "path": "libhook.js.so", "on_change": "ignore"}}
open(os.path.join(WORK, "libgadget.config.so"), "w").write(json.dumps(cfg))

# 3) repack: drop old signature, replace libmain, add gadget + config + script
unsigned = os.path.join(WORK, "unsigned.apk")
extra = {
    f"{ABI}/libmain.so":          libmain,
    f"{ABI}/libgadget.so":        GADGET,
    f"{ABI}/libgadget.config.so": os.path.join(WORK, "libgadget.config.so"),
    f"{ABI}/libhook.js.so":       HOOK_JS,
    "classes.dex":                "patched_classes.dex",   # JNIBridge patched for Android 16 default-method crash
}
with zipfile.ZipFile(SRC) as zin, zipfile.ZipFile(unsigned, "w", zipfile.ZIP_DEFLATED) as zout:
    for item in zin.infolist():
        n = item.filename
        if n.startswith("META-INF/") and (n.endswith((".SF", ".RSA", ".DSA", ".EC", ".MF"))):
            continue                       # old signature
        if n in extra:
            continue                       # replaced below
        zout.writestr(item, zin.read(n), compress_type=item.compress_type)
    for name, path in extra.items():
        zout.write(path, name, compress_type=zipfile.ZIP_DEFLATED)

# 4) align + sign (debug key, generated on first run)
aligned = os.path.join(WORK, "aligned.apk")
subprocess.check_call(["zipalign", "-f", "-p", "4", unsigned, aligned])
subprocess.check_call(["java", "-jar", "uber-apk-signer.jar", "-a", aligned,
                       "--allowResign", "--out", WORK])
signed = [f for f in os.listdir(WORK) if f.endswith("-aligned-debugSigned.apk")][0]
shutil.move(os.path.join(WORK, signed), OUT_NAME)
print("built", OUT_NAME, os.path.getsize(OUT_NAME) // 1024 // 1024, "MB")
