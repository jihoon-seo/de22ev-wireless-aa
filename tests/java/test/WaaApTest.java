import android.net.wifi.IWifiManager;
import android.net.wifi.WifiConfiguration;
import java.io.*;
import java.nio.file.*;

public class WaaApTest {
    static int failed = 0;
    static void check(String name, boolean ok) { System.out.println((ok ? "PASS " : "FAIL ") + name); if (!ok) failed++; }
    static String run(String... a) throws Exception {
        ByteArrayOutputStream bo = new ByteArrayOutputStream();
        PrintStream old = System.out; System.setOut(new PrintStream(bo, true, "UTF-8"));
        try { WaaAp.main(a); } finally { System.setOut(old); }
        return bo.toString("UTF-8");
    }
    static void reset() {
        WifiConfiguration c = new WifiConfiguration();
        c.SSID = "MyHotspot"; c.preSharedKey = "hotspotSECRET1";
        c.ConnectivitySSID = "AA_TEST1"; c.ConnectivityPSK = "wirelessSECRET2";
        IWifiManager.Stub.stored = c; IWifiManager.Stub.log = "";
    }
    public static void main(String[] x) throws Exception {
        String hostapd = System.getProperty("waa.hostapd");
        Files.write(Paths.get(hostapd), "interface=wlan0\nssid=AA_BROADCAST\nwpa_passphrase=hostapdSECRET3\nchannel=149\n".getBytes("UTF-8"));
        reset();
        String s = run("status");
        check("status ok", s.contains("result=ok"));
        check("status hides PSKs", !s.contains("SECRET"));
        check("status reports lengths", s.contains("cfg.preSharedKey.len=14") && s.contains("hostapd.wpa_passphrase.len=14"));
        check("status mismatch flags", s.contains("cfg.ssid_equal=false") && s.contains("hostapd.ssid_eq_connectivity=false"));
        check("status survives failing call", s.contains("api.getEnableWIFIAPMode=ERR SecurityException"));

        File bak = new File(hostapd + ".bak"); bak.delete();
        check("backup written", run("backup", bak.getPath()).contains("backup=written"));
        String s2 = run("sync");
        WifiConfiguration st = IWifiManager.Stub.stored;
        check("sync done", s2.contains("sync=done") && !s2.contains("SECRET"));
        check("sync aligns all four", "AA_BROADCAST".equals(st.SSID) && "AA_BROADCAST".equals(st.ConnectivitySSID)
            && "hostapdSECRET3".equals(st.preSharedKey) && "hostapdSECRET3".equals(st.ConnectivityPSK));
        check("sync idempotent", run("sync").contains("sync=already_equal"));
        check("status equal after sync", run("status").contains("hostapd.psk_eq_connectivity=true"));
        check("backup kept on rerun", run("backup", bak.getPath()).contains("backup=kept"));
        String r = run("restore", bak.getPath());
        st = IWifiManager.Stub.stored;
        check("restore done", r.contains("restore=done"));
        check("restore original values", "MyHotspot".equals(st.SSID) && "hotspotSECRET1".equals(st.preSharedKey)
            && "AA_TEST1".equals(st.ConnectivitySSID) && "wirelessSECRET2".equals(st.ConnectivityPSK));

        IWifiManager.Stub.log = "";
        run("on"); run("off");
        check("on/off call connectivity AP", IWifiManager.Stub.log.equals("ap=true;ap=false;"));

        // IEEE 802.11i-2004 H.4 test vector.
        check("wpa_psk vector", WaaAp.wpaPsk("password", "IEEE")
            .equals("f42c6fc52df0ebef9ebb4b90b38a5f902e83fe1b135a70e23aed762e9710a12e"));

        // Car case (2026-11-04): hostapd runs the hotspot pair and stores the derived wpa_psk;
        // the AA sink sends the Connectivity pair.
        reset();
        Files.write(Paths.get(hostapd), ("interface=wlan0\nssid=MyHotspot\nwpa=2\nwpa_psk="
            + WaaAp.wpaPsk("hotspotSECRET1", "MyHotspot") + "\n").getBytes("UTF-8"));
        String c1 = run("status");
        check("car: psk hidden", !c1.contains("SECRET") && !c1.contains(WaaAp.wpaPsk("hotspotSECRET1", "MyHotspot")));
        check("car: hostapd uses hotspot pair", c1.contains("hostapd.psk_eq_hotspot=true")
            && c1.contains("hostapd.psk_eq_connectivity=false") && c1.contains("hostapd.ssid_eq_hotspot=true"));
        String c2 = run("sync");
        st = IWifiManager.Stub.stored;
        check("car: sync copies hotspot pair to connectivity", c2.contains("sync=done")
            && "MyHotspot".equals(st.ConnectivitySSID) && "hotspotSECRET1".equals(st.ConnectivityPSK));
        check("car: hotspot pair untouched", "MyHotspot".equals(st.SSID) && "hotspotSECRET1".equals(st.preSharedKey)
            && c2.contains("sync.changed=ConnectivitySSID") && c2.contains("sync.changed=ConnectivityPSK")
            && !c2.contains("sync.changed=SSID") && !c2.contains("sync.changed=preSharedKey"));
        check("car: status equal after sync", run("status").contains("hostapd.psk_eq_connectivity=true"));

        reset();
        Files.write(Paths.get(hostapd), ("ssid=MyHotspot\nwpa_psk=" + WaaAp.wpaPsk("other", "MyHotspot") + "\n").getBytes("UTF-8"));
        String c3 = run("sync");
        check("car: unknown key skips", c3.contains("sync=skip hostapd key matches neither") && IWifiManager.Stub.log.isEmpty());

        // Preferred direction: hotspot pair takes the projection pair, AP restart picks it up.
        reset();
        String a1 = run("adopt");
        st = IWifiManager.Stub.stored;
        check("adopt done", a1.contains("adopt=done") && !a1.contains("SECRET"));
        check("adopt copies projection pair into hotspot pair", "AA_TEST1".equals(st.SSID) && "wirelessSECRET2".equals(st.preSharedKey)
            && "AA_TEST1".equals(st.ConnectivitySSID) && "wirelessSECRET2".equals(st.ConnectivityPSK));
        check("adopt idempotent", run("adopt").contains("adopt=already_equal"));
        Files.write(Paths.get(hostapd), ("ssid=AA_TEST1\nwpa_psk=" + WaaAp.wpaPsk("wirelessSECRET2", "AA_TEST1") + "\n").getBytes("UTF-8"));
        String a2 = run("status");
        check("adopt: restarted AP matches projection pair", a2.contains("hostapd.ssid_eq_connectivity=true")
            && a2.contains("hostapd.psk_eq_connectivity=true"));
        reset();
        IWifiManager.Stub.stored.ConnectivityPSK = null;
        check("adopt skips without projection pair", run("adopt").contains("adopt=skip") && IWifiManager.Stub.log.isEmpty());

        // Head unit Bluetooth toggle (K3): off must not persist.
        String b1 = run("bt", "off");
        check("bt off non-persistent", b1.contains("bt.disable=true") && b1.contains("bt.enabled=false")
            && android.bluetooth.IBluetoothManager.Stub.log.equals("disable(false);"));
        String b2 = run("bt", "on");
        check("bt on", b2.contains("bt.enable=true") && b2.contains("bt.enabled=true"));
        check("bt state only reads", run("bt", "state").contains("bt.enabled=true")
            && android.bluetooth.IBluetoothManager.Stub.log.equals("disable(false);enable;"));

        String b3 = run("bt", "state");
        check("bt phone connected, address not printed", b3.contains("bt.phone_connected=true") && !b3.contains("00:11"));
        android.bluetooth.IBluetoothManager.Stub.hfp = null;
        check("bt no phone", run("bt", "state").contains("bt.phone_connected=false"));
        android.bluetooth.IBluetoothManager.Stub.hfp = "";
        check("bt empty address is no phone", run("bt", "state").contains("bt.phone_connected=false"));

        Files.delete(Paths.get(hostapd));
        reset();
        String s3 = run("sync");
        check("sync skips without hostapd.conf", s3.contains("sync=skip") && IWifiManager.Stub.log.isEmpty());
        check("unknown command is usage", run("bogus").contains("result=usage"));
        System.out.println(failed == 0 ? "ALL PASS" : failed + " FAILED");
        System.exit(failed == 0 ? 0 : 1);
    }
}
