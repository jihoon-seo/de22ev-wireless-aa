package android.os;
public class ServiceManager {
    public static IBinder getService(String n) { return ("wifi".equals(n) || "bluetooth_manager".equals(n)) ? new IBinder() {} : null; }
}
