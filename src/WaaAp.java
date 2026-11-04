import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.net.NetworkInterface;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

/*
 * Wireless AA AP test helper for Gen5W (Android 4.4). Runs under app_process as root.
 * Hidden APIs (ServiceManager, IWifiManager, WifiConfiguration Connectivity* fields)
 * are reached by reflection so this builds against plain Java.
 *
 *   status                 print AP state, credential pairs (PSK as length/equality only), hostapd.conf
 *   on | off               setWifiApEnabledForConnectivity(current config, true|false)
 *   backup <file>          save SSID/PSK pairs to <file> (only if <file> does not exist)
 *   adopt                  copy the projection pair into the hotspot pair, so the AP (which is
 *                          built from the hotspot pair) broadcasts what the AA sink tells the phone;
 *                          the AP must be restarted to take it
 *   sync                   set both credential pairs to what hostapd.conf actually uses
 *   restore <file>         put the saved pairs back
 *   bt state|off|on        head unit Bluetooth via IBluetoothManager (off does not persist),
 *                          so a connected phone redoes its wireless AA handshake
 */
public class WaaAp {
    // Overridable only so the desktop test can point at a fixture.
    static final String HOSTAPD_CONF = System.getProperty("waa.hostapd", "/data/misc/wifi/hostapd.conf");
    static final String[] STATE_CALLS = {
        "getWifiEnabledState", "getWifiApEnabledState", "getWifiApMode",
        "getPersistedWifiApEnabled", "getEnableWIFIAPMode", "getApSSID"
    };
    static final String[] CFG_FIELDS = {
        "SSID", "ConnectivitySSID", "BSSID", "apMode", "channel", "connectivityChannel",
        "channel24GHzBand", "is24GHzBand", "hiddenSSID", "allowedKeyManagement"
    };

    static Class<?> iface;
    static Object wifi;

    public static void main(String[] args) {
        try {
            if (args.length < 1) {
                usage();
                return;
            }
            iface = Class.forName("android.net.wifi.IWifiManager");
            Class<?> sm = Class.forName("android.os.ServiceManager");
            Object binder = sm.getMethod("getService", String.class).invoke(null, "wifi");
            if (binder == null) {
                fail("no wifi service");
                return;
            }
            Class<?> stub = Class.forName("android.net.wifi.IWifiManager$Stub");
            Class<?> ibinder = Class.forName("android.os.IBinder");
            wifi = stub.getMethod("asInterface", ibinder).invoke(null, binder);
            String cmd = args[0];
            if (cmd.equals("bt") && args.length > 1) {
                bt(args[1]);
            } else if (cmd.equals("status")) {
                status();
            } else if (cmd.equals("on") || cmd.equals("off")) {
                setAp(cmd.equals("on"));
            } else if (cmd.equals("backup") && args.length > 1) {
                backup(args[1]);
            } else if (cmd.equals("adopt")) {
                adopt();
            } else if (cmd.equals("sync")) {
                sync();
            } else if (cmd.equals("restore") && args.length > 1) {
                restore(args[1]);
            } else {
                usage();
                return;
            }
            System.out.println("result=ok");
        } catch (Throwable t) {
            Throwable c = t.getCause() != null ? t.getCause() : t;
            fail(c.getClass().getName() + ": " + c.getMessage());
        }
    }

    static void usage() {
        System.out.println("usage: status | on | off | backup <file> | adopt | sync | restore <file> | bt state|off|on");
        System.out.println("result=usage");
    }

    static void fail(String why) {
        System.out.println("result=fail " + why);
    }

    static Object call(String name) throws Exception {
        return iface.getMethod(name).invoke(wifi);
    }

    static Object config() throws Exception {
        return call("getWifiApConfiguration");
    }

    static void putConfig(Object cfg) throws Exception {
        Class<?> wc = Class.forName("android.net.wifi.WifiConfiguration");
        iface.getMethod("setWifiApConfiguration", wc).invoke(wifi, cfg);
    }

    static Object get(Object cfg, String field) throws Exception {
        return cfg.getClass().getField(field).get(cfg);
    }

    static void set(Object cfg, String field, Object value) throws Exception {
        Field f = cfg.getClass().getField(field);
        f.set(cfg, value);
    }

    static String len(Object s) {
        return s == null ? "null" : String.valueOf(((String) s).length());
    }

    static boolean same(Object a, Object b) {
        return a == null ? b == null : a.equals(b);
    }

    static void status() throws Exception {
        for (String name : STATE_CALLS) {
            String v;
            try {
                v = String.valueOf(call(name));
            } catch (Throwable t) {
                Throwable c = t.getCause() != null ? t.getCause() : t;
                v = "ERR " + c.getClass().getSimpleName();
            }
            System.out.println("api." + name + "=" + v);
        }
        Object cfg = config();
        if (cfg == null) {
            System.out.println("cfg=null");
        } else {
            for (String f : CFG_FIELDS) {
                String v;
                try {
                    v = String.valueOf(get(cfg, f));
                } catch (NoSuchFieldException e) {
                    v = "NO_FIELD";
                }
                System.out.println("cfg." + f + "=" + v);
            }
            Object psk = get(cfg, "preSharedKey");
            Object cpsk = get(cfg, "ConnectivityPSK");
            System.out.println("cfg.preSharedKey.len=" + len(psk));
            System.out.println("cfg.ConnectivityPSK.len=" + len(cpsk));
            System.out.println("cfg.ssid_equal=" + same(get(cfg, "SSID"), get(cfg, "ConnectivitySSID")));
            System.out.println("cfg.psk_equal=" + same(psk, cpsk));
        }
        String[] hc = hostapd();
        if (hc == null) {
            System.out.println("hostapd.conf=missing");
        } else if (cfg != null) {
            System.out.println("hostapd.ssid_eq_hotspot=" + same(hc[0], get(cfg, "SSID")));
            System.out.println("hostapd.ssid_eq_connectivity=" + same(hc[0], get(cfg, "ConnectivitySSID")));
            System.out.println("hostapd.psk_eq_hotspot=" + hostapdUses(hc, get(cfg, "preSharedKey")));
            System.out.println("hostapd.psk_eq_connectivity=" + hostapdUses(hc, get(cfg, "ConnectivityPSK")));
        }
        // The AA sink reports the MAC of "wlan0" as the car BSSID.
        List<NetworkInterface> nis = Collections.list(NetworkInterface.getNetworkInterfaces());
        for (NetworkInterface ni : nis) {
            byte[] mac = ni.getHardwareAddress();
            StringBuilder sb = new StringBuilder();
            if (mac != null) {
                for (byte b : mac) {
                    if (sb.length() > 0) sb.append(':');
                    sb.append(String.format("%02X", b));
                }
            }
            System.out.println("netif." + ni.getName() + "=" + (ni.isUp() ? "up " : "down ") + sb
                + " " + Collections.list(ni.getInetAddresses()));
        }
    }

    /* Prints hostapd.conf with keys hidden; returns {ssid, passphrase, wpa_psk hex} or null. */
    static String[] hostapd() throws Exception {
        File f = new File(HOSTAPD_CONF);
        if (!f.exists()) return null;
        String[] out = new String[3];
        BufferedReader r = new BufferedReader(new InputStreamReader(new FileInputStream(f), "UTF-8"));
        try {
            String line;
            while ((line = r.readLine()) != null) {
                if (line.startsWith("wpa_passphrase=")) {
                    out[1] = line.substring("wpa_passphrase=".length());
                    System.out.println("hostapd.wpa_passphrase.len=" + out[1].length());
                    continue;
                }
                if (line.startsWith("wpa_psk=")) {
                    out[2] = line.substring("wpa_psk=".length());
                    System.out.println("hostapd.wpa_psk=<hidden>");
                    continue;
                }
                if (line.startsWith("ssid=")) out[0] = line.substring("ssid=".length());
                System.out.println("hostapd." + line);
            }
        } finally {
            r.close();
        }
        return out;
    }

    /* True when hostapd runs with this passphrase (Gen5W writes the derived wpa_psk, not the text). */
    static boolean hostapdUses(String[] hc, Object pass) throws Exception {
        if (pass == null) return false;
        if (hc[1] != null) return hc[1].equals(pass);
        if (hc[2] == null || hc[0] == null) return false;
        return hc[2].equalsIgnoreCase(wpaPsk((String) pass, hc[0]));
    }

    /* WPA2 PSK = PBKDF2-HMAC-SHA1(passphrase, ssid, 4096 rounds, 32 bytes), as hex. */
    static String wpaPsk(String pass, String ssid) throws Exception {
        Mac mac = Mac.getInstance("HmacSHA1");
        mac.init(new SecretKeySpec(pass.getBytes("UTF-8"), "HmacSHA1"));
        byte[] salt = ssid.getBytes("UTF-8");
        byte[] out = new byte[32];
        for (int block = 1, pos = 0; pos < out.length; block++) {
            mac.update(salt);
            byte[] u = mac.doFinal(new byte[] {0, 0, 0, (byte) block});
            byte[] t = u.clone();
            for (int i = 1; i < 4096; i++) {
                u = mac.doFinal(u);
                for (int k = 0; k < t.length; k++) t[k] ^= u[k];
            }
            int n = Math.min(t.length, out.length - pos);
            System.arraycopy(t, 0, out, pos, n);
            pos += n;
        }
        StringBuilder sb = new StringBuilder();
        for (byte b : out) sb.append(String.format("%02x", b));
        return sb.toString();
    }

    static void bt(String what) throws Exception {
        Object binder = Class.forName("android.os.ServiceManager").getMethod("getService", String.class)
            .invoke(null, "bluetooth_manager");
        if (binder == null) throw new IllegalStateException("no bluetooth_manager service");
        Class<?> bif = Class.forName("android.bluetooth.IBluetoothManager");
        Object bm = Class.forName("android.bluetooth.IBluetoothManager$Stub")
            .getMethod("asInterface", Class.forName("android.os.IBinder")).invoke(null, binder);
        if (what.equals("off")) {
            System.out.println("bt.disable=" + bif.getMethod("disable", boolean.class).invoke(bm, false));
        } else if (what.equals("on")) {
            System.out.println("bt.enable=" + bif.getMethod("enable").invoke(bm));
        }
        System.out.println("bt.enabled=" + bif.getMethod("isEnabled").invoke(bm));
        // Only whether a phone is on HFP; the address itself is never printed.
        String hfp;
        try {
            Object a = bif.getMethod("getConnectedHfpAddr").invoke(bm);
            hfp = String.valueOf(a != null && String.valueOf(a).trim().length() > 0);
        } catch (Throwable t) {
            hfp = "unknown";
        }
        System.out.println("bt.phone_connected=" + hfp);
    }

    static void setAp(boolean on) throws Exception {
        Object cfg = config();
        if (cfg == null) throw new IllegalStateException("no AP configuration");
        Class<?> wc = Class.forName("android.net.wifi.WifiConfiguration");
        iface.getMethod("setWifiApEnabledForConnectivity", wc, boolean.class).invoke(wifi, cfg, on);
        System.out.println("ap.request=" + (on ? "on" : "off"));
    }

    static String enc(Object s) {
        return s == null ? "n" : "v" + s;
    }

    static Object dec(String s) {
        return s.startsWith("v") ? s.substring(1) : null;
    }

    static final String[] PAIR = {"SSID", "preSharedKey", "ConnectivitySSID", "ConnectivityPSK"};

    static void backup(String path) throws Exception {
        File f = new File(path);
        if (f.exists()) {
            System.out.println("backup=kept " + path);
            return;
        }
        Object cfg = config();
        if (cfg == null) throw new IllegalStateException("no AP configuration");
        Writer w = new OutputStreamWriter(new FileOutputStream(f), "UTF-8");
        try {
            for (String n : PAIR) w.write(enc(get(cfg, n)) + "\n");
        } finally {
            w.close();
        }
        System.out.println("backup=written " + path);
    }

    static void adopt() throws Exception {
        Object cfg = config();
        if (cfg == null) throw new IllegalStateException("no AP configuration");
        Object cssid = get(cfg, "ConnectivitySSID");
        Object cpsk = get(cfg, "ConnectivityPSK");
        if (cssid == null || cpsk == null) {
            System.out.println("adopt=skip projection pair missing");
            return;
        }
        if (same(get(cfg, "SSID"), cssid) && same(get(cfg, "preSharedKey"), cpsk)) {
            System.out.println("adopt=already_equal");
            return;
        }
        set(cfg, "SSID", cssid);
        set(cfg, "preSharedKey", cpsk);
        putConfig(cfg);
        System.out.println("adopt=done");
    }

    static void sync() throws Exception {
        Object cfg = config();
        if (cfg == null) throw new IllegalStateException("no AP configuration");
        String[] hc = hostapd();
        if (hc == null || hc[0] == null) {
            System.out.println("sync=skip hostapd.conf has no ssid (AP not started?)");
            return;
        }
        // The AA sink sends ConnectivitySSID/ConnectivityPSK; hostapd may run on the hotspot pair.
        String pass = hc[1];
        if (pass == null) {
            Object psk = get(cfg, "preSharedKey");
            Object cpsk = get(cfg, "ConnectivityPSK");
            if (hostapdUses(hc, psk)) pass = (String) psk;
            else if (hostapdUses(hc, cpsk)) pass = (String) cpsk;
        }
        if (pass == null) {
            System.out.println("sync=skip hostapd key matches neither credential pair");
            return;
        }
        boolean changed = false;
        String[][] want = {{"SSID", hc[0]}, {"ConnectivitySSID", hc[0]},
            {"preSharedKey", pass}, {"ConnectivityPSK", pass}};
        for (String[] kv : want) {
            if (!same(get(cfg, kv[0]), kv[1])) {
                set(cfg, kv[0], kv[1]);
                System.out.println("sync.changed=" + kv[0]);
                changed = true;
            }
        }
        if (!changed) {
            System.out.println("sync=already_equal");
            return;
        }
        putConfig(cfg);
        System.out.println("sync=done");
    }

    static void restore(String path) throws Exception {
        List<String> lines = new ArrayList<String>();
        BufferedReader r = new BufferedReader(new InputStreamReader(new FileInputStream(path), "UTF-8"));
        try {
            String line;
            while ((line = r.readLine()) != null) lines.add(line);
        } finally {
            r.close();
        }
        if (lines.size() < PAIR.length) throw new IllegalStateException("backup file too short");
        Object cfg = config();
        if (cfg == null) throw new IllegalStateException("no AP configuration");
        for (int i = 0; i < PAIR.length; i++) set(cfg, PAIR[i], dec(lines.get(i)));
        putConfig(cfg);
        System.out.println("restore=done");
    }
}
