#!/system/bin/sh
USB=${0%/*}
[ "$USB" != "$0" ] || USB=$PWD
exec /system/bin/sh "$USB/WAA_AA_MOD/run.sh" "$USB"
