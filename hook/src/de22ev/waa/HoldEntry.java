package de22ev.waa;

import hmgapi.hook.Hooks;
import hmgapi.hook.LoadedApp;
import hmgapi.hook.MethodHook;
import hmgapi.hook.ModContext;
import hmgapi.hook.ModEntry;

/**
 * Keeps the car's screen where it is when wireless Android Auto connects (setting screen=button, the
 * default): hooks in the AA sink (com.google.android.projection.sink) on DE22EV.KOR V039 260902.
 *
 * About 0.3 s after the video is set up the phone asks for the screen (video focus "projected"); the sink's
 * GalConnectionSession$5.onVideoFocusRequest then starts its MainActivity. While ScreenHold holds the
 * session, the request is answered "native" (as the sink itself does when it can't show AA, without its
 * wait-and-retry) and the activity is not started; the session stays connected. The stock Android Auto tile
 * starts MainActivity, its surface turns the focus projected, and from then on the session is stock.
 * The sink's own startMainActivity() (after voice recognition, popups, the last source...) is skipped while
 * holding. Any failure leaves the sink's code to run as stock. Names: tests/hold/names.sh.
 */
public final class HoldEntry extends ModEntry {
    static final String SINK = "com.google.android.projection.sink";
    static final String LISTENER = "com.google.android.projection.service.GalConnectionSession$5";
    static final String SERVICE = "com.google.android.projection.service.GalReceiverService";
    static final String ACTIVITY = "com.google.android.projection.sink.ui.MainActivity";
    static final String VIDEO_SINK = "com.google.android.projection.protocol.VideoSink";

    final ScreenHold hold = new ScreenHold();

    @Override
    public void appLoaded(final ModContext mod, LoadedApp app) {
        if (!SINK.equals(app.packageName)) return;
        final ClassLoader cl = app.classLoader;
        try {
            Hooks.findAndHookMethod(LISTENER, cl, "onVideoFocusRequest", int.class, int.class, new MethodHook() {
                @Override
                protected void beforeHookedMethod(Param p) {
                    request(mod, cl, p);
                }
            });
            Hooks.findAndHookMethod(LISTENER, cl, "onVideoFocusModeChange", int.class, int.class, new MethodHook() {
                @Override
                protected void afterHookedMethod(Param p) {
                    try {
                        hold.focusMode(session(p), (Integer) p.args[0], focus(cl, "VIDEO_FOCUS_PROJECTED", 1));
                    } catch (Throwable t) {
                        mod.error("focus change", t);
                    }
                }
            });
            Hooks.findAndHookMethod(SERVICE, cl, "startMainActivity", new MethodHook() {
                @Override
                protected void beforeHookedMethod(Param p) {
                    try {
                        Object s = hold.held();
                        String mode = s == null ? null : (String) Hooks.getObjectField(s, "mSessionMode");
                        if (hold.blockStart(mode, screen(mod), mod.enabled())) {
                            p.setResult(null);
                            mod.log("Android Auto: the sink's own screen switch skipped (screen=button)");
                        }
                    } catch (Throwable t) {
                        mod.error("startMainActivity", t);
                    }
                }
            });
            Hooks.findAndHookMethod(ACTIVITY, cl, "onResume", new MethodHook() {
                @Override
                protected void afterHookedMethod(Param p) {
                    hold.activity(true);
                }
            });
            Hooks.findAndHookMethod(ACTIVITY, cl, "onPause", new MethodHook() {
                @Override
                protected void afterHookedMethod(Param p) {
                    hold.activity(false);
                }
            });
            mod.log("Android Auto screen hold ready in " + app.processName);
        } catch (Throwable t) {
            mod.error("Android Auto screen hold not installed (the sink switches the screen as stock)", t);
        }
    }

    private void request(ModContext mod, ClassLoader cl, MethodHook.Param p) {
        try {
            Object s = session(p);
            String mode = (String) Hooks.getObjectField(s, "mSessionMode");
            int focus = (Integer) p.args[0];
            if (!hold.hold(s, focus, focus(cl, "VIDEO_FOCUS_PROJECTED", 1), mode, screen(mod), mod.enabled())) return;
            try {
                // the sink's own step before it switches: closes its "connecting" dialog
                Hooks.callMethod(Hooks.getObjectField(s, "mService"), "removeDialogInit");
            } catch (Throwable t) {
                mod.error("removeDialogInit", t);
            }
            Hooks.callMethod(s, "setVideoFocus", focus(cl, "VIDEO_FOCUS_NATIVE", 2), -1, true);
            p.setResult(null);
            mod.log("Android Auto connected; the screen stays (screen=button): the Android Auto tile opens it");
        } catch (Throwable t) {
            mod.error("focus request (the sink goes on as stock)", t);
        }
    }

    static Object session(MethodHook.Param p) {
        return Hooks.getObjectField(p.thisObject, "this$0");
    }

    static String screen(ModContext mod) {
        return mod.settingString("screen", "button");
    }

    static int focus(ClassLoader cl, String field, int fallback) {
        try {
            return Hooks.getStaticIntField(Hooks.findClass(VIDEO_SINK, cl), field);
        } catch (Throwable t) {
            return fallback;
        }
    }
}
