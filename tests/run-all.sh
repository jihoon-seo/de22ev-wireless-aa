#!/bin/bash
# All host tests: WaaAp (Java), the waad daemon (mock Android), the screen-hold decisions and the USB
# kit (mock hmgapid).
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
RC=0
for t in java daemon hold kit; do
    echo "== $t"
    bash "$HERE/$t/run.sh" || RC=1
done
[ "$RC" = 0 ] && echo "ALL TESTS PASSED" || echo "SOME TESTS FAILED"
exit $RC
