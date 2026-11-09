package hmgapi.hook;

import java.lang.reflect.Method;

/** compile-only stand-in (the members HoldEntry uses) */
public final class Hooks {
    public static Class<?> findClass(String name, ClassLoader loader) {
        throw new UnsupportedOperationException();
    }

    public static Method findAndHookMethod(String className, ClassLoader loader, String name, Object... parameterTypesAndHook) {
        throw new UnsupportedOperationException();
    }

    public static Object getObjectField(Object obj, String name) {
        throw new UnsupportedOperationException();
    }

    public static Object callMethod(Object obj, String name, Object... args) {
        throw new UnsupportedOperationException();
    }

    public static int getStaticIntField(Class<?> cls, String name) {
        throw new UnsupportedOperationException();
    }
}
