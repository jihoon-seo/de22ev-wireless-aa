package android.bluetooth;
public interface IBluetoothManager {
    boolean disable(boolean persist); boolean enable(); boolean isEnabled(); String getConnectedHfpAddr();
    abstract class Stub {
        public static boolean on = true; public static String log = ""; public static String hfp = "00:11:22:33:44:55";
        public static IBluetoothManager asInterface(android.os.IBinder b) { return new P(); }
        private static class P implements IBluetoothManager {
            public boolean disable(boolean persist) { on = false; log += "disable(" + persist + ");"; return true; }
            public boolean enable() { on = true; log += "enable;"; return true; }
            public boolean isEnabled() { return on; }
            public String getConnectedHfpAddr() { return hfp; }
        }
    }
}
