#!/bin/bash
# The names HoldEntry hooks and calls in the AA sink exist on the car's firmware (tests/hold/sink-names.txt,
# from the car's HKMC_GPM odex), and HoldEntry really uses them; the HMG-API calls exist in its hook API
# (when HMGAPI_SRC points at an HMG-API checkout).
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
SRC="$HERE/../../hook/src/de22ev/waa/HoldEntry.java"
LIST="$HERE/sink-names.txt"
FAILED=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1: $2"; FAILED=$((FAILED+1)); }
[ -f "$SRC" ] || { echo "FAIL HoldEntry.java missing"; exit 1; }

# class (as HoldEntry names it) | member name in HoldEntry | member as in the firmware list
while IFS='|' read -r CLS NAME MEMBER; do
    [ -z "$CLS" ] && continue
    DESC="L$(echo "$CLS" | tr . /);"
    grep -qF "\"$NAME\"" "$SRC" || fail "$NAME" "HoldEntry doesn't use \"$NAME\""
    grep -qF "$DESC :: $MEMBER" "$LIST" && pass "$CLS $MEMBER on the car" || fail "$CLS $MEMBER" "not in the firmware's list"
done <<'EOF'
com.google.android.projection.service.GalConnectionSession$5|onVideoFocusRequest|M onVideoFocusRequest(II)V
com.google.android.projection.service.GalConnectionSession$5|onVideoFocusModeChange|M onVideoFocusModeChange(II)V
com.google.android.projection.service.GalConnectionSession$5|this$0|F this$0:Lcom/google/android/projection/service/GalConnectionSession;
com.google.android.projection.service.GalConnectionSession|mSessionMode|F mSessionMode:Ljava/lang/String;
com.google.android.projection.service.GalConnectionSession|mService|F mService:Lcom/google/android/projection/service/GalReceiverService;
com.google.android.projection.service.GalConnectionSession|setVideoFocus|M setVideoFocus(IIZ)V
com.google.android.projection.service.GalReceiverService|removeDialogInit|M removeDialogInit()V
com.google.android.projection.service.GalReceiverService|startMainActivity|M startMainActivity()V
com.google.android.projection.sink.ui.MainActivity|onResume|M onResume()V
com.google.android.projection.sink.ui.MainActivity|onPause|M onPause()V
com.google.android.projection.protocol.VideoSink|VIDEO_FOCUS_NATIVE|F VIDEO_FOCUS_NATIVE:I
com.google.android.projection.protocol.VideoSink|VIDEO_FOCUS_PROJECTED|F VIDEO_FOCUS_PROJECTED:I
EOF
for C in com.google.android.projection.service.GalConnectionSession\$5 com.google.android.projection.service.GalReceiverService \
        com.google.android.projection.sink.ui.MainActivity com.google.android.projection.protocol.VideoSink; do
    grep -qF "\"$C\"" "$SRC" || fail "$C" "HoldEntry doesn't name the class"
done

if [ -n "${HMGAPI_SRC:-}" ]; then
    API="$HMGAPI_SRC/core/runtime/java/hmgapi/hook"
    for m in "Hooks.java:public static Method findAndHookMethod(String className, ClassLoader loader, String name" \
             "Hooks.java:public static Object getObjectField(Object obj, String name)" \
             "Hooks.java:public static Object callMethod(Object obj, String name, Object... args)" \
             "Hooks.java:public static int getStaticIntField(Class<?> cls, String name)" \
             "Hooks.java:public static Class<?> findClass(String name, ClassLoader loader)" \
             "ModContext.java:public String settingString(String key, String fallback)" \
             "ModContext.java:public boolean enabled()" \
             "ModContext.java:public void log(String message)" \
             "ModEntry.java:public void appLoaded(ModContext mod, LoadedApp app)"; do
        grep -qF "${m#*:}" "$API/${m%%:*}" && pass "HMG-API ${m#*:}" || fail "HMG-API" "${m#*:} not in ${m%%:*}"
    done
else
    echo "SKIP HMG-API API check: set HMGAPI_SRC"
fi
[ "$FAILED" = 0 ] && echo "names: all checks passed" || { echo "names: $FAILED check(s) failed"; exit 1; }
