package android.net.wifi;
public interface IWifiManager {
    int getWifiEnabledState(); int getWifiApEnabledState(); int getWifiApMode();
    boolean getPersistedWifiApEnabled(); boolean getEnableWIFIAPMode(); String getApSSID();
    WifiConfiguration getWifiApConfiguration();
    void setWifiApConfiguration(WifiConfiguration c);
    void setWifiApEnabledForConnectivity(WifiConfiguration c, boolean on);
    abstract class Stub {
        public static WifiConfiguration stored;
        public static String log = "";
        public static IWifiManager asInterface(android.os.IBinder b) { return new P(); }
        // Like the real Stub.Proxy: not public, so reflection must go through the interface.
        private static class P implements IWifiManager {
            public int getWifiEnabledState() { return 1; }
            public int getWifiApEnabledState() { return 13; }
            public int getWifiApMode() { return 2; }
            public boolean getPersistedWifiApEnabled() { return true; }
            public boolean getEnableWIFIAPMode() { throw new SecurityException("x"); }
            public String getApSSID() { return stored.ConnectivitySSID; }
            public WifiConfiguration getWifiApConfiguration() { return copy(stored); }
            public void setWifiApConfiguration(WifiConfiguration c) { stored = copy(c); log += "set;"; }
            public void setWifiApEnabledForConnectivity(WifiConfiguration c, boolean on) { log += "ap=" + on + ";"; }
        }
        static WifiConfiguration copy(WifiConfiguration a) {
            WifiConfiguration b = new WifiConfiguration();
            b.SSID = a.SSID; b.preSharedKey = a.preSharedKey;
            b.ConnectivitySSID = a.ConnectivitySSID; b.ConnectivityPSK = a.ConnectivityPSK;
            return b;
        }
    }
}
