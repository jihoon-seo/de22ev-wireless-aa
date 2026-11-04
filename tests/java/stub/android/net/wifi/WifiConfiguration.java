package android.net.wifi;
public class WifiConfiguration {
    public String SSID, preSharedKey, ConnectivitySSID, ConnectivityPSK, BSSID;
    public int apMode = 2, channel = 6, connectivityChannel = 149, channel24GHzBand;
    public boolean is24GHzBand, hiddenSSID;
    public java.util.BitSet allowedKeyManagement = new java.util.BitSet();
}
