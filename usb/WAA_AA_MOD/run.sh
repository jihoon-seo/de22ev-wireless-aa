#!/system/bin/sh
# USB kit for the HMG-API mod de22ev-wireless-aa (wireless Android Auto at engine start).
#   MODE.txt=install    install/update the signed mod and enable it (service waad starts now)
#   MODE.txt=status     copy waad's log and the current AP/credential state to USB
#   MODE.txt=uninstall  disable and remove the mod, put the original credentials back, AP off
export PATH=/system/bin:/system/xbin:/data/nemesis/bin
umask 077
USB=$1
KIT="$USB/WAA_AA_MOD"
[ -d "$KIT" ] || exit 1
OUT="$USB/WAA_AA_MOD_$(date +%Y%m%d_%H%M%S)_$$"
mkdir "$OUT" || exit 1
exec > "$OUT/run.log" 2>&1
echo RUNNING > "$OUT/STATUS.txt"
echo "$OUT" > "$USB/WAA_AA_MOD_LAST.txt"
trap 'sync' EXIT
fail() { echo "STOPPED: $*"; echo "STOPPED: $*" > "$OUT/STATUS.txt"; exit 1; }
done_status() { echo "$1"; echo "$1" > "$OUT/STATUS.txt"; }

ID=de22ev-wireless-aa
UUID=3c503596-94a4-8f10-901e-d6da35861d6a
ZIP=de22ev-wireless-aa-1.0.2.zip
PRODUCT=DE22EV.KOR.0000.V039.001.260902
H=/system/bin/hmgapid
LOCAL=/data/nemesis/waa-aa-mod
SVC_LOG=/data/hmgapi/logs/$ID/waad.log
RUN_DIR=/data/hmgapi/run/$ID/waad

EUID_=
while read -r LABEL REAL EFFECTIVE REST; do
    if [ "$LABEL" = Uid: ]; then EUID_=$EFFECTIVE; break; fi
done < /proc/self/status
[ "$EUID_" = 0 ] || fail NEMESIS_ROOT_REQUIRED
[ "$(getprop sys.boot_completed)" = 1 ] || fail ANDROID_NOT_READY
[ "$(getprop ro.build.product)" = "$PRODUCT" ] || fail "NOT_THIS_CAR $(getprop ro.build.product)"
[ -x "$H" ] || fail HMGAPI_NOT_INSTALLED

mkdir -p "$LOCAL" || fail INTERNAL_DIRECTORY
cp "$KIT/waaap.jar" "$LOCAL/waaap.jar" || fail COPY_JAR
chmod 644 "$LOCAL/waaap.jar"
waa() { CLASSPATH="$LOCAL/waaap.jar" /system/bin/app_process /system/bin WaaAp "$@" 2>&1; }

MODE=install
[ -f "$KIT/MODE.txt" ] && read -r MODE < "$KIT/MODE.txt"
case "$MODE" in
    status*) MODE=status ;;
    uninstall*) MODE=uninstall ;;
    *) MODE=install ;;
esac
echo "mode=$MODE"
{ getprop ro.build.product; getprop ro.build.version.incremental; "$H" version 2>&1; date; } > "$OUT/VEHICLE.txt"

dump_state() {
    waa status > "$OUT/$1-status.txt"
    for K in wifi_on wifi_ap_on; do echo "global.$K=$(settings get global $K 2>/dev/null)"; done >> "$OUT/$1-status.txt"
    cat /data/hmgapi/state/services.status > "$OUT/$1-services.txt" 2>&1
    "$H" engine status > "$OUT/$1-engine.txt" 2>&1
}
svc_running() {
    while read -r M N STATE PID REST; do
        [ "$M" = "$ID" ] && [ "$N" = waad ] && [ "$STATE" = running ] && return 0
    done < /data/hmgapi/state/services.status
    return 1
}

if [ "$MODE" = status ]; then
    dump_state now
    for F in "$SVC_LOG.1" "$SVC_LOG"; do [ -f "$F" ] && cp "$F" "$OUT/"; done
    if svc_running; then done_status STATUS_WRITTEN_WAAD_RUNNING; else done_status STATUS_WRITTEN_WAAD_NOT_RUNNING; fi
    exit 0
fi

if [ "$MODE" = uninstall ]; then
    dump_state before
    "$H" disable "$ID" > "$OUT/disable.txt" 2>&1
    sleep 6
    BACKUP=
    for F in "$RUN_DIR/credentials.bak" /data/nemesis/waa-ap-test/credentials.bak; do
        [ -f "$F" ] && { BACKUP=$F; break; }
    done
    [ -n "$BACKUP" ] && cp "$BACKUP" "$LOCAL/credentials.bak.uninstall"
    for F in "$SVC_LOG.1" "$SVC_LOG"; do [ -f "$F" ] && cp "$F" "$OUT/"; done
    "$H" engine remove "$ID" > "$OUT/remove.txt" 2>&1
    waa off > "$OUT/ap-off.txt"
    sleep 3
    if [ -n "$BACKUP" ]; then
        waa restore "$LOCAL/credentials.bak.uninstall" > "$OUT/restore.txt"
    else
        echo "no credential backup found; credentials left as they are" > "$OUT/restore.txt"
    fi
    settings put global wifi_ap_on 0
    dump_state after
    done_status UNINSTALLED
    exit 0
fi

# install
[ -f "$KIT/$ZIP" ] || fail "NO_PACKAGE $ZIP"
cp "$KIT/$ZIP" "$LOCAL/$ZIP" || fail COPY_PACKAGE
dump_state before
"$H" engine install "$LOCAL/$ZIP" --uuid "$UUID" > "$OUT/install.txt" 2>&1 || fail "INSTALL_FAILED (see install.txt)"
"$H" enable "$ID" > "$OUT/enable.txt" 2>&1 || fail "ENABLE_FAILED (see enable.txt)"
# an update to an enabled mod keeps the old waad running: restart it on the new files
"$H" service-restart "$ID" waad >> "$OUT/enable.txt" 2>&1
WAIT=0
while ! svc_running && [ "$WAIT" -lt 30 ]; do sleep 1; WAIT=$((WAIT+1)); done
sleep 3
dump_state after
for F in "$SVC_LOG"; do [ -f "$F" ] && cp "$F" "$OUT/"; done
if svc_running; then
    done_status INSTALLED_WAAD_RUNNING
else
    done_status INSTALLED_BUT_WAAD_NOT_RUNNING
fi
exit 0
