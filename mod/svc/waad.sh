#!/system/bin/sh
# waad: keeps the wireless projection AP ready for wireless Android Auto (HMG-API service, root).
#
# At boot (and at ACC ON without a reboot):
#   1. skip if client Wi-Fi is on, or the user's hotspot (AP mode != 2) is up
#   2. make the hotspot pair equal to this car's own projection pair (ConnectivitySSID/PSK,
#      what the AA sink sends the phone; the AP is built from the hotspot pair),
#      restarting the AP if it changed
#   3. turn the projection AP on
#   4. if the AA sink negotiated with the phone ([Ready] 1) but no session followed within 20 s,
#      restart the sink so it negotiates again (at most twice). At boot the sink sends the phone's
#      Ready before PhoneProjection's wireless service is up, which drops that handshake; the phone
#      then sits on the car's Wi-Fi and Bluetooth retrying until its Bluetooth is toggled.
#      The state comes from the sink's own log lines (tag AAProjection), per sink pid:
#        "send requestWLDeviceReadyStatusUpdate:  [Ready] 1"   a handshake
#        "<< setGpmStatus: N"   (Wireless or USB) N >= 4 a session starting or running (6)
#      Never while a session (wireless or wired) runs.
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
GPM=com.google.android.projection.sink
AAREADY=$DATA/aa-ready
AAGPM=$DATA/aa-gpm
AGAIN=$DATA/cycle.again
KICKS=2

waa() { CLASSPATH=$JAR /system/bin/app_process /system/bin WaaAp "$@" 2>&1; }
say() { echo "$(date '+%m-%d %H:%M:%S') $*"; }

acc_off() { [ "$(cat "$ACCOFF" 2>/dev/null)" = "$BOOT" ]; }

proc_pid() {
    ps 2>/dev/null | while read -r U P REST; do
        case "$REST" in *" $1") echo "$P"; break ;; esac
    done
}
# ready_now / session_now: for the sink running now (files hold "boot pid [status]"); own variable
# names: sh has no locals and kick_phase counts in N
ready_now() {
    [ -f "$AAREADY" ] || return 1
    read -r RB RP < "$AAREADY" || return 1
    [ "$RB" = "$BOOT" ] && [ -n "$RP" ] && [ "$RP" = "$(proc_pid $GPM)" ]
}
session_now() {
    [ -f "$AAGPM" ] || return 1
    read -r SB SP SN < "$AAGPM" || return 1
    [ "$SB" = "$BOOT" ] && [ -n "$SP" ] && [ "$SP" = "$(proc_pid $GPM)" ] && [ "${SN:-0}" -ge 4 ]
}
# wait_session SECONDS
wait_session() {
    T=0
    while [ "$T" -lt "$1" ]; do
        session_now && return 0
        acc_off && return 1
        sleep 2
        T=$((T+2))
    done
    return 1
}
restart_gpm() {
    P=$(proc_pid $GPM)
    [ -n "$P" ] && /system/bin/kill "$P"
    T=0
    while [ "$(proc_pid $GPM)" = "$P" ] || [ -z "$(proc_pid $GPM)" ]; do
        [ "$T" -ge 10 ] && break
        sleep 1
        T=$((T+1))
    done
    if [ -z "$(proc_pid $GPM)" ]; then
        say "AA sink did not respawn, starting its service"
        /system/bin/am startservice -n "$GPM/com.google.android.projection.service.GalReceiverService" > /dev/null 2>&1
    fi
}
# after the AP is ready: restart the sink when its handshake was lost
kick_phase() {
    N=0
    while :; do
        if wait_session 20; then
            if [ "$N" -gt 0 ]; then say "CONNECTED after K2 #$N"; else say "AA session running"; fi
            return
        fi
        acc_off && return
        if ! ready_now; then
            if [ "$N" -gt 0 ]; then say "no new handshake after K2 #$N, stopping"
            else say "no handshake seen: nothing to restart (the phone negotiates when it connects)"; fi
            return
        fi
        [ "$N" -ge "$KICKS" ] && { say "GAVE_UP after $KICKS restarts"; return; }
        session_now && { say "AA session running"; return; }   # a last look: never kill a session
        N=$((N+1))
        say "K2 #$N: restarting the AA sink (handshake seen, no session)"
        restart_gpm
        if wait_session 40; then
            say "CONNECTED after K2 #$N"
            return
        fi
    done
}
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
    kick_phase
}
# One cycle at a time, also across a waad restart (a cycle left running keeps its lock).
run_cycle() {
    if [ -d "$LOCK" ]; then
        OWNER=$(cat "$LOCK/pid" 2>/dev/null)
        if [ -n "$OWNER" ] && [ -d "/proc/$OWNER" ]; then
            say "a cycle is already running, another one follows it"
            touch "$AGAIN"
            return
        fi
        rm -f "$LOCK/pid"
        rmdir "$LOCK" 2>/dev/null
    fi
    mkdir "$LOCK" 2>/dev/null || { say "a cycle is already running, another one follows it"; touch "$AGAIN"; return; }
    sh -c 'echo $PPID' > "$LOCK/pid"
    rm -f "$AGAIN"
    cycle_body
    # an ACC on while this cycle ran (it may have stopped for an ACC off in between): run again
    while [ -f "$AGAIN" ]; do
        rm -f "$AGAIN"
        acc_off || cycle_body
    done
    rm -f "$LOCK/pid"
    rmdir "$LOCK"
}

mkdir -p "$DATA"
say "waad start (boot $BOOT)"
run_cycle &

# ACC changes without a reboot, from WifiService's own log line:
#   WIFI Received ACTION_ACC_STATUS_CHANGED:<prev>-><cur> [OFF(255),ACCON(0),LOGINCON(1),ADM(2),SYSTEMREADY(5),ACC_OFF_DELAY_MODE(6)]
# (seen on the car: 2->6 at engine off; 2 is the normal running state)
# ACC lines already in the buffer are skipped until our own marker comes through; the AA sink's
# lines count from the start (the buffer is this boot's).
MARK="waad-live-$$"
LIVE=
/system/bin/log -t waad "$MARK"
logcat -v brief -s WifiService:D waad:I AAProjection:D 2>/dev/null | while read -r LINE; do
    case "$LINE" in
        *AAProjection\(*"requestWLDeviceReadyStatusUpdate:"*"[Ready] 1"*)
            LP=${LINE#*AAProjection\(}; LP=${LP%%\)*}
            acc_off || echo "$BOOT $((LP + 0))" > "$AAREADY"   # not while the engine is off
            continue ;;
        *AAProjection\(*"<< setGpmStatus: "*)
            LP=${LINE#*AAProjection\(}; LP=${LP%%\)*}; LN=${LINE##*setGpmStatus: }; LN=${LN%%[!0-9]*}
            [ -n "$LN" ] && ! acc_off && echo "$BOOT $((LP + 0)) $LN" > "$AAGPM"
            continue ;;
        *AAProjection\(*) continue ;;
    esac
    if [ -z "$LIVE" ]; then
        case "$LINE" in *"$MARK"*) LIVE=1 ;; esac
        continue
    fi
    case "$LINE" in
        *ACTION_ACC_STATUS_CHANGED:*"->255 "*|*ACTION_ACC_STATUS_CHANGED:*"->6 "*)
            if ! acc_off; then
                echo "$BOOT" > "$ACCOFF"
                rm -f "$AAREADY" "$AAGPM"   # a handshake from before doesn't count after ACC on
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
