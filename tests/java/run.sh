#!/bin/bash
# Host test of src/WaaAp.java against stand-ins for the hidden Android APIs (tests/java/stub).
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
JAVA_BIN=${JAVA_HOME:+$JAVA_HOME/bin/}
OUT=$(mktemp -d); trap 'rm -rf "$OUT"' EXIT
native() { if command -v cygpath > /dev/null; then cygpath -w "$1"; else echo "$1"; fi; }
SRCS=$(cd "$HERE" && find stub test -name '*.java')
(cd "$HERE" && "${JAVA_BIN}javac" -nowarn -encoding UTF-8 -d "$(native "$OUT/classes")" $SRCS "$(native "$HERE/../../src/WaaAp.java")")
"${JAVA_BIN}java" -Dwaa.hostapd="$(native "$OUT/hostapd.conf")" -cp "$(native "$OUT/classes")" WaaApTest
