#!/bin/bash
# Host test of the USB kit (usb/WAA_AA_MOD/run.sh) with a mock hmgapid, WaaAp and settings.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
KIT_SRC="$HERE/../../usb"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
FAILED=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1: $2"; FAILED=$((FAILED+1)); }

setup() {   # setup PRODUCT
    M="$WORK/$RANDOM"; mkdir -p "$M/bin" "$M/usb" "$M/hmgapi/state" "$M/hmgapi/logs/de22ev-wireless-aa" \
        "$M/hmgapi/run/de22ev-wireless-aa/waad" "$M/nemesis"
    cp -r "$KIT_SRC"/* "$M/usb/"
    ZIP=$(sed -n 's/^ZIP=//p' "$M/usb/WAA_AA_MOD/run.sh")
    echo zip > "$M/usb/WAA_AA_MOD/$ZIP"; echo jar > "$M/usb/WAA_AA_MOD/waaap.jar"
    printf 'Name: sh\nUid:\t0\t0\t0\t0\n' > "$M/procstatus"
    cat > "$M/bin/getprop" <<EOF
#!/bin/bash
case "\$1" in sys.boot_completed) echo 1 ;; ro.build.product) echo $1 ;; *) echo x ;; esac
EOF
    cat > "$M/bin/hmgapid" <<'EOF'
#!/bin/bash
echo "hmgapid $*" >> "$MOCK/calls"
S=$MOCK/hmgapi/state/services.status
case "$1" in
    version) echo "hmgapid 1.0.0-beta.5" ;;
    engine) [ "$2" = install ] && echo "installed de22ev-wireless-aa (author key $5)"
            [ "$2" = remove ] && rm -f "$S" ;;
    enable) echo "de22ev-wireless-aa waad running 4242 0" > "$S" ;;
    disable) echo "de22ev-wireless-aa waad stopped 0 0" > "$S" ;;
    service-restart) echo "de22ev-wireless-aa waad running 4343 0" > "$S" ;;
esac
exit 0
EOF
    printf '#!/bin/bash\necho "waa $3 $4" >> "$MOCK/calls"; echo result=ok\n' > "$M/bin/app_process"
    printf '#!/bin/bash\necho "settings $*" >> "$MOCK/calls"; echo 0\n' > "$M/bin/settings"
    printf '#!/bin/bash\nexit 0\n' > "$M/bin/sleep"
    chmod +x "$M/bin/"*
    sed -i -e "s#/system/bin/app_process#$M/bin/app_process#g" -e "s#/system/bin/hmgapid#$M/bin/hmgapid#g" \
        -e "s#/data/hmgapi#$M/hmgapi#g" -e "s#/data/nemesis#$M/nemesis#g" -e "s#/proc/self/status#$M/procstatus#g" \
        -e "s#^export PATH=.*#export PATH=$M/bin:\$PATH#" "$M/usb/WAA_AA_MOD/run.sh"
    : > "$M/calls"
}
run_kit() {   # run_kit MODE -> sets STATUS
    echo "$1" > "$M/usb/WAA_AA_MOD/MODE.txt"
    MOCK=$M bash "$M/usb/WAA_AA_MOD/run.sh" "$M/usb"
    STATUS=$(cat "$(cat "$M/usb/WAA_AA_MOD_LAST.txt")/STATUS.txt")
}
order() {   # order PATTERN...: the calls appear in this order
    local n=0 p line
    for p in "$@"; do
        line=$(grep -nF -- "$p" "$M/calls" | head -1 | cut -d: -f1)
        [ -n "$line" ] && [ "$line" -gt "$n" ] || return 1
        n=$line
    done
}

setup DE22EV.KOR.0000.V039.001.260902
run_kit install
if [ "$STATUS" = INSTALLED_WAAD_RUNNING ] && grep -q "engine install .* --uuid 3c503596-94a4-8f10-901e-d6da35861d6a" "$M/calls" && order "hmgapid engine install" "hmgapid enable de22ev-wireless-aa" "hmgapid service-restart de22ev-wireless-aa waad"; then
    pass "install: install, enable, then service-restart"
else fail "install" "status=$STATUS calls=$(tr '\n' ';' < "$M/calls")"; fi
grep -q "de22ev-wireless-aa-1.0.2.zip" "$M/calls" && pass "install: ships the 1.0.2 package" || fail "install version" "$(grep 'engine install' "$M/calls")"

run_kit status
[ "$STATUS" = STATUS_WRITTEN_WAAD_RUNNING ] && pass "status: daemon running" || fail "status" "$STATUS"

echo ORIG > "$M/hmgapi/run/de22ev-wireless-aa/waad/credentials.bak"; : > "$M/calls"
run_kit uninstall
if [ "$STATUS" = UNINSTALLED ] && order "hmgapid disable de22ev-wireless-aa" "hmgapid engine remove de22ev-wireless-aa" "waa off" "waa restore" "settings put global wifi_ap_on 0"; then
    pass "uninstall: disable, remove, AP off, restore credentials, wifi_ap_on=0"
else fail "uninstall" "status=$STATUS calls=$(tr '\n' ';' < "$M/calls")"; fi

setup CN7.KOR.0000.V039.001.260902
run_kit install
case "$STATUS" in "STOPPED: NOT_THIS_CAR"*) pass "other car refused" ;; *) fail "other car" "$STATUS" ;; esac
grep -q "engine install" "$M/calls" && fail "other car" "it installed" || pass "other car: nothing installed"

[ "$FAILED" = 0 ] && echo "kit: all checks passed" || { echo "kit: $FAILED check(s) failed"; exit 1; }
