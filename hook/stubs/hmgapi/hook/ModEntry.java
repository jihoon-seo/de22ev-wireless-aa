package hmgapi.hook;

/** compile-only stand-in for HMG-API's mod entry point */
public abstract class ModEntry {
    public void zygoteInit(ModContext mod) throws Throwable {
    }

    public void appLoaded(ModContext mod, LoadedApp app) throws Throwable {
    }

    public void onSettingsChanged(ModContext mod) throws Throwable {
    }

    public void onEnabled(ModContext mod, boolean enabled) throws Throwable {
    }
}
