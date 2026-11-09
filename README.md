# de22ev-wireless-aa

[한국어](README.ko.md)

An [HMG-API](https://github.com/VysseCodes/HMG-API) mod that gets the wireless projection access
point of a Gen5W head unit ready for **wireless Android Auto** at every engine start.

> **Tested on one car only:** a Kia head unit with firmware `DE22EV.KOR.0000.V039.001.260902`
> (model DE22EV, Korea, Android 4.4.2, tcc897x). The mod refuses to install on anything else.
> Unofficial; see [Disclaimer](#disclaimer).

## Why

On this unit wireless Android Auto stalled even though the phone completed the Bluetooth
handshake. Three things were in the way:

1. **Two credential pairs.** The car's AP configuration holds a hotspot pair
   (`SSID`/`preSharedKey`) and a projection pair (`ConnectivitySSID`/`ConnectivityPSK`).
   The AA app sends the phone the projection pair, but the AP (hostapd) is built from the hotspot pair.
   The phone looks for a network that isn't there and gives up after about 36 s.
2. **The projection AP is off.** WifiService only starts it at boot when `wifi_ap_on=1`, and the
   stock shutdown path writes `wifi_ap_on=0`.
3. **A boot race.** The phone's handshake with the AA app runs about 2 s after boot, before the
   PhoneProjection service is up. That handshake is lost; the next one (for example after toggling
   the phone's Bluetooth) works.

## What it does

A small root service (`waad`, run and watched by HMG-API) does this at boot and when the ACC
comes back on without a reboot:

- skips everything while the car's client Wi-Fi or the normal hotspot is on;
- makes the hotspot pair equal to **this car's own** projection pair, restarting the AP if it
  changed. The values are read from the car; none are in this package. The hotspot name and
  password shown in Settings become the same value, and the originals are backed up;
- turns the wireless projection AP on;
- restarts the car's AA app when its boot handshake with the phone was lost (cause 3 above): when
  the AA app's log shows a handshake (`[Ready] 1`) but no session (`<< setGpmStatus: N`) within 20 s
  of the AP being up, at most twice, never while a wireless or wired session runs.

At engine off it makes sure the AP is off, and it never turns the AP on while the engine is off.
After a short engine off/on wireless Android Auto connects by itself.

**Screen hold** (hooks in the AA app, `hooks.jar`): with the setting `screen` = `button` (default)
wireless Android Auto connects but the car's screen stays where it is; the home screen's Android
Auto tile opens it, and from then on that session behaves as stock. `auto` switches at once, as
stock. Wired Android Auto always switches at once. The hooks load at the next car start; the
setting (HMG-API app, Mods tab, "Save settings") applies from the next connection.

## Requirements

- NEMESIS and [HMG-API](https://github.com/VysseCodes/HMG-API) 1.0.0-beta.5 on the head unit
  (see HMG-API's [install guide](https://github.com/VysseCodes/HMG-API/wiki/Installing-HMG-API)).
- The unit must already expose wireless projection and Wi-Fi as features
  (`android.hardware.wifi`, `com.hkmc.software.connectivity.androidauto_wireless`). The tested car
  ships without them; they were enabled beforehand with a separate NEMESIS package.

## Install

Download from [Releases](../../releases):

| asset | what |
|---|---|
| `de22ev-wireless-aa-<version>.USB.zip` | NEMESIS USB kit: install, status and uninstall from a USB stick |
| `de22ev-wireless-aa-<version>.zip` | the signed HMG-API mod package, for HMG-API's own installer |
| `SHA256SUMS` | checksums of both |

With the USB kit:

1. Unzip it and put `NEMESIS.data`, `NEMESIS.sh` and the `WAA_AA_MOD` folder at the top of a USB stick.
2. Start the car, wait about a minute, insert the stick and choose **Yes** in NEMESIS.
3. `WAA_AA_MOD_*/STATUS.txt` on the stick says `INSTALLED_RESTART_THE_CAR` when it worked.

The first line of `WAA_AA_MOD/MODE.txt` picks the action: `install` (default), `status`
(copies the daemon log and the AP state to the stick) or `uninstall` (removes the mod, restores
the original hotspot name/password, turns the AP off and sets `wifi_ap_on=0`). See
`USAGE.en.txt` / `사용방법.txt` in the kit.

The package is signed with this repository's author key (uuid `3c503596-94a4-8f10-901e-d6da35861d6a`,
public key in [`keys/author.key.pub`](keys/author.key.pub)). That key is not on HMG-API's trusted
author list, so the install log shows a warning; the install goes ahead. Updates install over
earlier versions only when they come from the same key.

## Verify a download

```
sha256sum -c SHA256SUMS
```

The package's `META-HMGAPI/manifest.json` lists every file's SHA-256 and the author key, and
`META-HMGAPI/signature` signs that manifest. `build.sh` builds HMG-API's own signer, which checks it:

```
java -cp build/hmgsign hmgapi.engine.Signing verify <unzipped package> 3c503596-94a4-8f10-901e-d6da35861d6a
```

## On the car

| | |
|---|---|
| mod | `/data/hmgapi/mods/de22ev-wireless-aa` |
| log | `/data/hmgapi/logs/de22ev-wireless-aa/waad.log` |
| credential backup | `/data/hmgapi/run/de22ev-wireless-aa/waad/credentials.bak` |

## Build from source

```
export D8_JAR=/path/to/r8.jar          # any jar with com.android.tools.r8.D8
export SIGN_KEY=/path/to/author.key    # optional; without it the package is unsigned
./build.sh                             # -> dist/
./tests/run-all.sh                     # host tests: WaaAp, the daemon, the USB kit
```

The build needs a JDK 8+, Python 3, curl and D8; no Android SDK. `WaaAp` reaches the hidden
Android APIs by reflection. The signer comes from HMG-API at a pinned commit
(see [`tools/hmgsign`](tools/hmgsign)). Without `SIGN_KEY`, the built files can be compared with a
release's `META-HMGAPI/manifest.json` (the signature itself differs on every signing run).

## Layout

| path | |
|---|---|
| `mod/` | the mod: `mod.json`, `svc/waad.sh` (the daemon), READMEs |
| `src/WaaAp.java` | the helper the daemon calls (`app_process`): AP state, credentials, AP on/off, backup/restore |
| `usb/` | the NEMESIS USB kit |
| `tests/` | host tests with mocks for Android and hmgapid |
| `tools/` | signer and reproducible zip helper |
| `keys/` | the author's public key and uuid |

## Disclaimer

This is an unofficial hobby project. It is not affiliated with or endorsed by Hyundai Motor
Group, Kia, Hyundai Mobis or Google. Android Auto is a trademark of Google LLC. Modifying a head
unit can void a warranty and may stop it from working. It has been tested on one car and one
firmware only. Use it at your own risk; the software comes with no warranty (see [LICENSE](LICENSE)).

## License

[MIT](LICENSE) for the code in this repository. HMG-API's `Signing.java` and `Json.java`, which
`build.sh` fetches to build the signer, are AGPL-3.0 and are not part of this repository.

## Credits

[HMG-API](https://github.com/VysseCodes/HMG-API) by VysseCodes, which runs and supervises the
service and verifies the signature.
