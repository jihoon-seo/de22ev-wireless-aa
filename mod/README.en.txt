de22ev-wireless-aa 1.0.2 (HMG-API mod) - for DE22EV.KOR V039 260902 only

Keeps the car's wireless projection access point ready for wireless Android Auto at every engine start.
- Makes the AP (hostapd) broadcast this car's own projection SSID/password, i.e. the
  ConnectivitySSID/ConnectivityPSK stored in the car, which is what the AA app tells the phone.
  The values are read from the car; none are contained in the mod.
  (The hotspot name/password in Settings becomes the same value. The originals are backed up.)
- Turns the wireless projection AP (connectivity mode) on.
- Does not restart the AA app. After a cold boot, toggle the phone's Bluetooth off and on
  and wireless Android Auto connects.
- At engine off it turns the AP off, and never turns it on while the engine is off.
- Leaves things alone while the car's client Wi-Fi (Wi-Fi tab) or the normal hotspot is on.

Log: /data/hmgapi/logs/de22ev-wireless-aa/waad.log
Credential backup: /data/hmgapi/run/de22ev-wireless-aa/waad/credentials.bak
