package hmgapi.hook;

/** compile-only stand-in */
public abstract class MethodHook {
    protected void beforeHookedMethod(Param param) throws Throwable {
    }

    protected void afterHookedMethod(Param param) throws Throwable {
    }

    public static final class Param {
        public final java.lang.reflect.Member method = null;
        public final Object thisObject = null;
        public final Object[] args = null;

        public Object getResult() {
            throw new UnsupportedOperationException();
        }

        public void setResult(Object result) {
            throw new UnsupportedOperationException();
        }
    }
}
