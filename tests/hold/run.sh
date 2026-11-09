#!/bin/bash
# Host test of the screen-hold decisions (hook/src/de22ev/waa/ScreenHold.java, plain Java).
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
JAVA_BIN=${JAVA_HOME:+$JAVA_HOME/bin/}
OUT=$(mktemp -d); trap 'rm -rf "$OUT"' EXIT
native() { if command -v cygpath > /dev/null; then cygpath -w "$1"; else echo "$1"; fi; }
"${JAVA_BIN}javac" --release 8 -Xlint:-options -nowarn -encoding UTF-8 -d "$(native "$OUT")" \
    "$(native "$HERE/../../hook/src/de22ev/waa/ScreenHold.java")" "$(native "$HERE/ScreenHoldTest.java")"
"${JAVA_BIN}java" -cp "$(native "$OUT")" ScreenHoldTest
