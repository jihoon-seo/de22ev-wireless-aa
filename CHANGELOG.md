# Changelog

## 1.0.2

- USB kit: after `hmgapid enable`, restart the `waad` service so an update over a running
  version takes effect at once (before, the old daemon kept running until the next boot).
- English mod README and kit usage file.

## 1.0.1

- No longer restarts the car's Android Auto app; after a cold boot, toggle the phone's Bluetooth.
- ACC on now includes the normal running state (`->2`), seen on the car as `2->6` at engine off
  and `6->2` at engine on, so the AP comes back after a short engine off/on.
- The AP broadcasts each car's own projection credentials; docs no longer mention any car's SSID.

## 1.0.0

- First version: aligns the hotspot pair with the projection pair, turns the projection AP on at
  boot and ACC on, keeps it off while the engine is off, skips while client Wi-Fi or the hotspot is on.
