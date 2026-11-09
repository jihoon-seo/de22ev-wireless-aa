package de22ev.waa;

import java.lang.ref.WeakReference;
import java.util.Map;
import java.util.WeakHashMap;

/**
 * Whether the AA sink may take the car's screen. Plain Java (host-tested in tests/hold); HoldEntry feeds it
 * from hooks in the sink.
 *
 * With screen=button a wireless session's first projection request is held: the sink answers "native"
 * and the car stays where it is, until the owner enters AA (the stock Android Auto tile; the session's video
 * focus turns projected). From then on that session behaves as stock. Wired sessions, screen=auto and a
 * disabled mod are always stock. A session object is new for every connection (the sink's
 * GalConnectionManager makes one per connection), so a reconnection is held again.
 */
public final class ScreenHold {
    private final Map<Object, Boolean> entered = new WeakHashMap<Object, Boolean>();
    private WeakReference<Object> held = new WeakReference<Object>(null);
    private boolean activityUp;

    /** a projection request of session (focus); true: answer native and don't take the screen */
    public synchronized boolean hold(Object session, int focus, int projected, String mode, String screen, boolean enabled) {
        if (session != null && held.get() != session) held = new WeakReference<Object>(null); // another session now
        if (session == null || focus != projected || !enabled || !"button".equals(screen)) return false;
        if (!"Wireless".equals(mode) || activityUp || entered.containsKey(session)) return false;
        held = new WeakReference<Object>(session);
        return true;
    }

    /** the session's video focus changed; projected means the owner entered AA */
    public synchronized void focusMode(Object session, int mode, int projected) {
        if (session != null && mode == projected) entered.put(session, Boolean.TRUE);
    }

    /** the sink's MainActivity resumed (true) or paused (false) */
    public synchronized void activity(boolean resumed) {
        activityUp = resumed;
    }

    /** the native answer failed: the sink goes on as stock for this session */
    public synchronized void release(Object session) {
        if (held.get() == session) held = new WeakReference<Object>(null);
    }

    /** the session held last (null: none, or gone) */
    public synchronized Object held() {
        return held.get();
    }

    /**
     * whether the sink's own startMainActivity() must be skipped: the held session still runs (heldMode:
     * its session mode now; empty once the sink cleared it) and the owner hasn't entered it
     */
    public synchronized boolean blockStart(String heldMode, String screen, boolean enabled) {
        Object s = held.get();
        if (s == null || !enabled || !"button".equals(screen) || !"Wireless".equals(heldMode)) return false;
        return !entered.containsKey(s);
    }
}
