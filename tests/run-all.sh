#!/bin/bash
# All host tests: WaaAp (Java), the waad daemon (mock Android) and the USB kit (mock hmgapid).
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
RC=0
for t in java daemon kit; do
    echo "== $t"
    bash "$HERE/$t/run.sh" || RC=1
done
[ "$RC" = 0 ] && echo "ALL TESTS PASSED" || echo "SOME TESTS FAILED"
exit $RC
