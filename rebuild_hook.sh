#!/usr/bin/env bash
# Rebuild hook.js from hook.ts using the vendored node_modules.
set -e
cd "$(dirname "$0")"
node ./node_modules/frida-compile/dist/cli.js hook.ts -o hook.js -T none
echo "built hook.js ($(wc -c < hook.js) bytes)"
