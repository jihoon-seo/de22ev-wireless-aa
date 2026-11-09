#!/bin/bash
# The built package through HMG-API's own engine on the desktop (HMGAPI_HOST=1 on a fake root):
# signature + author uuid accepted, mod.json (service, hooks) parsed with no errors, the hook jar and
# settings installed, the screen setting's default published. (Hooks themselves need the car's hook map.)
# Needs HMGAPI_SRC = an HMG-API checkout (core/runtime/java/hmgapi/engine) and dist/ from build.sh.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
if [ -z "${HMGAPI_SRC:-}" ]; then echo "SKIP engine: HMGAPI_SRC not set"; exit 0; fi
ZIP=$(ls "$ROOT"/dist/de22ev-wireless-aa-*.zip 2>/dev/null | grep -v USB | head -1)
[ -n "$ZIP" ] || { echo "FAIL engine: no dist/de22ev-wireless-aa-<version>.zip (run build.sh)"; exit 1; }
JAVA_BIN=${JAVA_HOME:+$JAVA_HOME/bin/}
native() { if command -v cygpath > /dev/null; then cygpath -w "$1"; else echo "$1"; fi; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/cp" "$T/root/data/hmgapi/mods" "$T/root/data/hmgapi/settings"
mapfile -t S < <(find "$HMGAPI_SRC/core/runtime/java/hmgapi/engine" -name '*.java' | while IFS= read -r f; do native "$f"; done)
"${JAVA_BIN}javac" --release 8 -Xlint:-options -nowarn -encoding UTF-8 -d "$(native "$T/cp")" "${S[@]}" 2>/dev/null \
    || { echo "FAIL engine: HMG-API engine does not compile"; exit 1; }
UUID=$(tr -d '\r\n' < "$ROOT/keys/uuid.txt")
ID=de22ev-wireless-aa
FAILED=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1: $2"; FAILED=$((FAILED+1)); }
printf "ro.build.product=DE22EV.KOR.0000.V039.001.260902\nro.mobis.onebindir=de22ev_kr\nro.board.platform=tcc897x\nro.build.version.release=4.4.2\n" > "$T/root/props.txt"
PROPS="ro.build.product=DE22EV.KOR.0000.V039.001.260902 ro.mobis.onebindir=de22ev_kr ro.board.platform=tcc897x ro.build.version.release=4.4.2"
eng() { out=$(HMGAPI_ROOT="$(native "$T/root")" HMGAPI_HOST=1 HMGAPI_TEST_ANY_CAR=1 HMGAPI_PROPS="$PROPS" "${JAVA_BIN}java" -cp "$(native "$T/cp")" hmgapi.engine.Engine "$@" 2>&1); rc=$?; }

eng install "$(native "$ZIP")" --uuid "$UUID"
[ $rc = 0 ] && pass "install accepted (signature, uuid)" || fail "install" "rc=$rc $out"
echo "$out" | grep -qi "error\|problem" && fail "install output has errors" "$out" || pass "install: no errors"
M="$T/root/data/hmgapi/mods/$ID"
for f in mod.json settings.json hooks.jar waaap.jar svc/waad.sh; do
    [ -f "$M/$f" ] && pass "installed $f" || fail "installed $f" "missing"
done
eng status
echo "$out" | grep -qi "problem" && fail "status reports a problem" "$out" || pass "status: no problems"
"${PYTHON:-python}" -I -c "
import json,sys
m=json.load(open(sys.argv[1],encoding='utf-8'))['mods']['$ID']
assert m['settings']['screen']=='button', m['settings']
" "$(native "$T/root/data/hmgapi/public/state.json")" && pass "state: screen=button by default" || fail "state.json" "see above"
[ "$FAILED" = 0 ] && echo "engine: all checks passed" || { echo "engine: $FAILED check(s) failed"; exit 1; }
