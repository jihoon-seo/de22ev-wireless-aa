#!/system/bin/sh
# waad: keeps the wireless projection AP ready for wireless Android Auto (HMG-API service, root).
#
# At boot (and at ACC ON without a reboot):
#   1. skip if client Wi-Fi is on, or the user's hotspot (AP mode != 2) is up
#   2. make the hotspot pair equal to this car's own projection pair (ConnectivitySSID/PSK,
#      what the AA sink sends the phone; the AP is built from the hotspot pair),
#      restarting the AP if it changed
#   3. turn the projection AP on
# It never restarts the AA sink: after a cold boot the phone joins when its Bluetooth
# reconnects (e.g. toggled off/on), which is the behaviour the owner chose.
# At ACC OFF it only makes sure the AP is off; the stock firmware turns it off too.
export PATH=/system/bin:/system/xbin
MOD=${HMGAPI_MOD_DIR:-/data/hmgapi/mods/de22ev-wireless-aa}
DATA=${HMGAPI_DATA:-/data/hmgapi/run/de22ev-wireless-aa/waad}
JAR=$MOD/waaap.jar
LOCK=$DATA/cycle.lock
ACCOFF=$DATA/acc-off
BACKUP=$DATA/credentials.bak
OLD_BACKUP=/data/nemesis/waa-ap-test/credentials.bak
BOOT=$(cat /proc/sys/kernel/random/boot_id)

waa() { CLASSPATH=$JAR /system/bin/app_process /system/bin WaaAp "$@" 2>&1; }
say() { echo "$(date '+%m-%d %H:%M:%S') $*"; }

acc_off() { [ "$(cat "$ACCOFF" 2>/dev/null)" = "$BOOT" ]; }
ap_up() {
    case "$(waa status)" in *getWifiApEnabledState=13*getWifiApMode=2*) return 0 ;; esac
    return 1
}
# wait_ap up|down
wait_ap() {
    T=0
    while [ "$T" -lt 24 ]; do
        if [ "$1" = up ]; then ap_up && return 0
        else case "$(waa status)" in *getWifiApEnabledState=11*) return 0 ;; esac
        fi
        sleep 2
        T=$((T+2))
    done
    return 1
}

cycle_body() {
    acc_off && { say "ACC off, nothing to do"; return; }
    T=0
    until case "$(waa status)" in *result=ok*) true ;; *) false ;; esac; do
        [ "$T" -ge 60 ] && { say "Wi-Fi service not answering, giving up this cycle"; return; }
        sleep 2
        T=$((T+2))
    done
    acc_off && return
    if [ "$(settings get global wifi_on 2>/dev/null)" = 1 ]; then
        say "SKIP_STA: client Wi-Fi is on"
        return
    fi
    S=$(waa status)
    case "$S" in
        *getWifiApEnabledState=13*)
            case "$S" in *getWifiApMode=2*) ;; *) say "SKIP_HOTSPOT: the user's hotspot is on"; return ;; esac ;;
    esac
    if [ ! -f "$BACKUP" ]; then
        if [ -f "$OLD_BACKUP" ]; then cp "$OLD_BACKUP" "$BACKUP"; else waa backup "$BACKUP" > /dev/null; fi
        say "credential backup: $BACKUP"
    fi
    ADOPTED=
    case "$S" in
        *cfg.ssid_equal=true*cfg.psk_equal=true*) ;;
        *)
            say "credentials differ, adopting the projection pair: $(waa adopt | grep adopt=)"
            ADOPTED=1
            ;;
    esac
    if ap_up; then
        if [ -n "$ADOPTED" ]; then
            say "restarting the AP for the new credentials"
            waa off > /dev/null
            wait_ap down
            waa on > /dev/null
            wait_ap up || { say "AP_FAILED after restart"; return; }
        fi
    else
        say "AP on"
        waa on > /dev/null
        wait_ap up || { say "AP_FAILED"; return; }
    fi
    case "$(waa status)" in
        *hostapd.ssid_eq_connectivity=true*hostapd.psk_eq_connectivity=true*) ;;
        *) say "WARNING: hostapd does not run the projection credentials" ;;
    esac
    say "AP ready"
}
# One cycle at a time, also across a waad restart (a cycle left running keeps its lock).
run_cycle() {
    if [ -d "$LOCK" ]; then
        OWNER=$(cat "$LOCK/pid" 2>/dev/null)
        if [ -n "$OWNER" ] && [ -d "/proc/$OWNER" ]; then
            say "a cycle is already running"
            return
        fi
        rm -f "$LOCK/pid"
        rmdir "$LOCK" 2>/dev/null
    fi
    mkdir "$LOCK" 2>/dev/null || { say "a cycle is already running"; return; }
    sh -c 'echo $PPID' > "$LOCK/pid"
    cycle_body
    rm -f "$LOCK/pid"
    rmdir "$LOCK"
}

mkdir -p "$DATA"
say "waad start (boot $BOOT)"
run_cycle &

# ACC changes without a reboot, from WifiService's own log line:
#   WIFI Received ACTION_ACC_STATUS_CHANGED:<prev>-><cur> [OFF(255),ACCON(0),LOGINCON(1),ADM(2),SYSTEMREADY(5),ACC_OFF_DELAY_MODE(6)]
# (seen on the car: 2->6 at engine off; 2 is the normal running state)
# Lines already in the buffer are skipped until our own marker comes through.
MARK="waad-live-$$"
LIVE=
/system/bin/log -t waad "$MARK"
logcat -v brief -s WifiService:D waad:I 2>/dev/null | while read -r LINE; do
    if [ -z "$LIVE" ]; then
        case "$LINE" in *"$MARK"*) LIVE=1 ;; esac
        continue
    fi
    case "$LINE" in
        *ACTION_ACC_STATUS_CHANGED:*"->255 "*|*ACTION_ACC_STATUS_CHANGED:*"->6 "*)
            if ! acc_off; then
                echo "$BOOT" > "$ACCOFF"
                say "ACC off: ${LINE#*CHANGED:}"
                ( sleep 8; ap_up && { say "AP still on after ACC off, turning it off"; waa off > /dev/null; } ) &
            fi
            ;;
        *ACTION_ACC_STATUS_CHANGED:*"->0 "*|*ACTION_ACC_STATUS_CHANGED:*"->1 "*|*ACTION_ACC_STATUS_CHANGED:*"->2 "*|*ACTION_ACC_STATUS_CHANGED:*"->5 "*)
            if acc_off; then
                rm -f "$ACCOFF"
                say "ACC on: ${LINE#*CHANGED:}"
                run_cycle &
            fi
            ;;
    esac
done
say "logcat ended, exiting for a restart"
exit 1
