#!/bin/bash
# Host test of mod/svc/waad.sh: runs the daemon with mock Android commands (tests/daemon/bin)
# for each scenario and checks what it logged and which WaaAp calls it made.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
DAEMON="$HERE/../../mod/svc/waad.sh"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
FAILED=0

# scenario NAME FLAGS EXPECT_LOG FORBID_LOG EXPECT_CALLS FORBID_CALLS
#   flags: apon sta differ hotspot accoff_on acc255 accpersist oldbackup
#   EXPECT_* / FORBID_*: '|'-separated substrings ('' = none)
scenario() {
    local name=$1 flags=$2 want=$3 forbid=$4 wantc=$5 forbidc=$6 M="$WORK/$1" f ok=1
    mkdir -p "$M/bin" "$M/data" "$M/oldkit"
    cp "$HERE"/bin/* "$M/bin/"; chmod +x "$M/bin/"*
    echo "11111111-2222-3333-4444-555555555555" > "$M/boot_id"
    : > "$M/calls"
    for f in $flags; do touch "$M/$f"; done
    [ -f "$M/apon" ] && echo E > "$M/hostapd"
    [ -f "$M/sta" ] && echo 1 > "$M/settings.wifi_on"
    [ -f "$M/differ" ] && echo D > "$M/cfg"
    [ -f "$M/hotspot" ] && echo 0 > "$M/apmode"
    [ -f "$M/accoff_on" ] && printf '2->6\n6->2\n' > "$M/acc_events"
    [ -f "$M/acc255" ] && printf '0->255\n255->0\n' > "$M/acc_events"
    [ -f "$M/accpersist" ] && cat "$M/boot_id" > "$M/data/acc-off"
    [ -f "$M/oldbackup" ] && echo ORIGINAL > "$M/oldkit/credentials.bak"
    sed -e "s#^export PATH=.*#export PATH=$M/bin:\$PATH#" \
        -e "s#/system/bin/app_process#$M/bin/app_process#g" \
        -e "s#/system/bin/log#$M/bin/log#g" \
        -e "s#/proc/sys/kernel/random/boot_id#$M/boot_id#" \
        -e "s#/data/nemesis/waa-ap-test#$M/oldkit#" "$DAEMON" > "$M/waad.sh"
    MOCK=$M HMGAPI_MOD_DIR=$M/moddir HMGAPI_DATA=$M/data timeout 120 bash "$M/waad.sh" > "$M/out.log" 2>&1
    check() {   # check KIND FILE LIST MUST(1)/MUSTNOT(0)
        local IFS='|' s
        for s in $3; do
            [ -z "$s" ] && continue
            if grep -qF -- "$s" "$2"; then [ "$4" = 1 ] || { echo "  unexpected $1: $s"; ok=0; }
            else [ "$4" = 0 ] || { echo "  missing $1: $s"; ok=0; }; fi
        done
    }
    check log "$M/out.log" "$want" 1
    check log "$M/out.log" "$forbid" 0
    check call "$M/calls" "$wantc" 1
    check call "$M/calls" "$forbidc" 0
    if [ "$ok" = 1 ]; then echo "PASS $name"; else echo "FAIL $name"; sed 's/^/    | /' "$M/out.log"; FAILED=$((FAILED+1)); fi
}

scenario boot_ap_off      ""                "AP on|AP ready"                                  "ACC off" "waa on"                 "waa off|waa adopt"
scenario boot_ap_on       "apon"            "AP ready"                                        "AP on"   ""                       "waa on|waa off|waa adopt"
scenario client_wifi_on   "sta"             "SKIP_STA"                                        "AP ready" ""                      "waa on|waa off|waa adopt|waa backup"
scenario user_hotspot_on  "apon hotspot"    "SKIP_HOTSPOT"                                    "AP ready" ""                      "waa on|waa off|waa adopt|waa backup"
scenario adopt_restart    "apon differ"     "adopt=done|restarting the AP|AP ready"           ""        "waa adopt|waa off|waa on" ""
scenario stale_acc_line   ""                "AP ready"                                        "ACC off" "waa on"                 "waa off"
scenario acc_off_on_car   "apon accoff_on"  "ACC off: 2->6|turning it off|ACC on: 6->2|AP on|AP ready" "" "waa off|waa on"        ""
scenario acc_255_0        "apon acc255"     "ACC off: 0->255|ACC on: 255->0|AP ready"         ""        "waa off|waa on"         ""
scenario acc_off_restart  "accpersist"      "ACC off, nothing to do"                          "AP on"   ""                       "waa on|waa off|waa adopt"
scenario old_backup_kept  "oldbackup"       "credential backup|AP ready"                      ""        "waa on"                 "waa backup"
scenario new_backup       ""                "credential backup"                               ""        "waa backup"             ""
scenario no_sink_restart  "apon"            "AP ready"                                        "K2|restarting the AA sink" "" "kill"

[ "$FAILED" = 0 ] && echo "daemon: all scenarios passed" || { echo "daemon: $FAILED scenario(s) failed"; exit 1; }
