import de22ev.waa.ScreenHold;

/** Host test of the screen-hold decisions (hook/src/de22ev/waa/ScreenHold.java). */
public final class ScreenHoldTest {
    static int failed;
    static final int PROJECTED = 1, NATIVE = 2;

    static void check(boolean c, String what) {
        System.out.println((c ? "PASS " : "FAIL ") + what);
        if (!c) failed++;
    }

    public static void main(String[] args) {
        ScreenHold h = new ScreenHold();
        Object s1 = new Object();
        check(!h.hold(s1, PROJECTED, PROJECTED, "Wireless", "auto", true), "H1 screen=auto: stock takeover");
        check(!h.hold(s1, NATIVE, PROJECTED, "Wireless", "button", true), "H2 a native request: stock");
        check(!h.hold(s1, PROJECTED, PROJECTED, "USB", "button", true), "H3 wired: stock takeover");
        check(!h.hold(s1, PROJECTED, PROJECTED, "Wireless", "button", false), "H4 mod disabled: stock");
        check(!h.blockStart("Wireless", "button", true), "nothing held yet: startMainActivity runs");
        check(h.hold(s1, PROJECTED, PROJECTED, "Wireless", "button", true), "H5 wireless, not entered: hold");
        check(h.held() == s1, "the held session is remembered");
        check(h.blockStart("Wireless", "button", true), "H10 while holding: startMainActivity skipped");
        check(h.hold(s1, PROJECTED, PROJECTED, "Wireless", "button", true), "a repeated request is held too");
        h.focusMode(s1, NATIVE, PROJECTED);
        check(h.hold(s1, PROJECTED, PROJECTED, "Wireless", "button", true), "native focus doesn't count as entering");
        h.activity(true); // the owner pressed the Android Auto tile
        h.focusMode(s1, PROJECTED, PROJECTED);
        check(!h.hold(s1, PROJECTED, PROJECTED, "Wireless", "button", true), "H6 after entering AA: stock");
        check(!h.blockStart("Wireless", "button", true), "H11 entered: startMainActivity runs");
        h.activity(false); // Home
        check(!h.hold(s1, PROJECTED, PROJECTED, "Wireless", "button", true), "entered once this session: stock from then on");
        Object s2 = new Object();
        check(h.hold(s2, PROJECTED, PROJECTED, "Wireless", "button", true), "H7 a new session: held again");
        check(h.held() == s2, "the new session is the held one");
        check(!h.blockStart("", "button", true), "H11 the held session was cleared (no mode): startMainActivity runs");
        check(!h.blockStart(null, "button", true), "H11 no mode at all: startMainActivity runs");
        check(!h.blockStart("Wireless", "auto", true), "H9 switched to auto: startMainActivity runs");
        check(!h.hold(s2, PROJECTED, PROJECTED, "Wireless", "auto", true), "H9 switched to auto: the next request takes over");
        Object s3 = new Object();
        h.activity(true); // AA already on screen (the tile was pressed before the phone asked)
        check(!h.hold(s3, PROJECTED, PROJECTED, "Wireless", "button", true), "H8 AA already on screen: stock");
        h.activity(false);
        check(!h.hold(s3, PROJECTED, PROJECTED, null, "button", true), "unknown session mode: stock");
        check(!h.hold(null, PROJECTED, PROJECTED, "Wireless", "button", true), "no session object: stock");
        // a failed native answer releases the hold: the sink goes on as stock, its startMainActivity too
        ScreenHold f = new ScreenHold();
        Object s4 = new Object();
        check(f.hold(s4, PROJECTED, PROJECTED, "Wireless", "button", true), "held before the answer");
        f.release(s4);
        check(f.held() == null && !f.blockStart("Wireless", "button", true), "released: nothing held, startMainActivity runs");
        // a request from another session (a wired one after a held wireless one) ends the old hold
        ScreenHold w = new ScreenHold();
        Object wl = new Object(), usb = new Object();
        check(w.hold(wl, PROJECTED, PROJECTED, "Wireless", "button", true), "wireless held");
        check(!w.hold(usb, PROJECTED, PROJECTED, "USB", "button", true), "the wired session's request: stock");
        check(w.held() == null && !w.blockStart("Wireless", "button", true), "the old wireless hold no longer blocks the wired session");
        System.out.println(failed == 0 ? "hold: all checks passed" : "hold: " + failed + " check(s) failed");
        System.exit(failed == 0 ? 0 : 1);
    }
}
