# Changelog

## 1.1.0

The owner's wish (2026-11-06): Android Auto connects at engine start, but the car's screen stays
where it is until the owner presses the Android Auto tile; or, as a setting, switches at once.

- waad restarts the car's AA app (the sink) when its boot handshake with the phone was lost: at
  boot the sink sends the phone's Ready before PhoneProjection's wireless service is up, and the
  phone then sits on the car's Wi-Fi and Bluetooth retrying until its Bluetooth is toggled. waad
  follows the sink's own log lines ("[Ready] 1" for a handshake, "<< setGpmStatus: N" for a
  session) and restarts it when a handshake was seen and no session followed within 20 s after the
  AP is up, at most twice; never while a wireless or wired session runs. (1.0.0 had a restart too,
  but its phone and connection checks never let it fire on the car.)
- Screen hold (HMG-API hooks in the AA app, hooks.jar): with the new setting `screen` = `button`
  (default) a wireless session's request for the screen is answered "native" and the car's screen
  stays; the home screen's Android Auto tile opens AA, and from then on that session is stock.
  `auto` is the stock behaviour (switch at once). Wired AA always switches as stock. The hooks load
  at the next car start; the setting applies from the next connection.
- USB kit: the install ends with INSTALLED_RESTART_THE_CAR (the hooks load at the next start), the
  uninstall with UNINSTALLED_RESTART_THE_CAR.

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
