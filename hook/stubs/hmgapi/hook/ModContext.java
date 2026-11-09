package hmgapi.hook;

/** compile-only stand-in (the members HoldEntry uses) */
public final class ModContext {
    public boolean enabled() {
        throw new UnsupportedOperationException();
    }

    public String settingString(String key, String fallback) {
        throw new UnsupportedOperationException();
    }

    public void log(String message) {
        throw new UnsupportedOperationException();
    }

    public void error(String message, Throwable t) {
        throw new UnsupportedOperationException();
    }
}
