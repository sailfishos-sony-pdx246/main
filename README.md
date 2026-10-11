<!--
SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Sailfish OS for the Sony Xperia 10 VI (pdx246)

A community port of Sailfish OS 5.1.0.11 to the Sony Xperia 10 VI (XQ-ES54, XQ-ES72), built
with libhybris on top of the LineageOS 23.2 (Android 16) port for the same phone.

**Status:** in development; no image is released yet. To try it, build it yourself
([BUILD.md](BUILD.md)). Flashing instructions will follow with the first image.

## What works

Tested on the developer's phone:

- Calls over VoLTE (ringback tone, DTMF, hold, swap, merging into a conference), SMS, mobile
  data on LTE
- Wi-Fi, Wi-Fi hotspot (2.4 GHz), Bluetooth (audio and headset calls)
- Audio: speaker, earpiece, wired headphones
- Cameras: back (including the ultrawide) and front, photos and videos with sound; video and
  music playback
- GNSS, NFC (tag and card detection), fingerprint unlock
- USB: MTP, developer mode, charging with the charging limit from Settings
- Standby (about 10 mA overnight)

## Known issues

- The call screen does not group merged calls into a conference (no participant list); "End
  call" ends the whole conference. This comes from Sailfish OS's call handling, not from the
  port.
- The hotspot runs on 2.4 GHz only.
- Not tested yet: mic mute, USSD, SMS delivery reports, reading NFC NDEF tags, NFC card
  emulation.

## Repositories

All in [github.com/sailfishos-sony-pdx246](https://github.com/sailfishos-sony-pdx246):

| Repository | What |
|---|---|
| `main` (this one) | build instructions, local manifests, platform patches, build scripts |
| `droid-hal-pdx246` | droid-hal packaging (`rpm/` in the tree) |
| `droid-config-pdx246` | configuration, patterns and kickstart |
| `droid-hal-version-pdx246` | image version package |
| `droid-hal-img-boot-pdx246` | boot and recovery image package |
| `android_device_sony_pdx246`, `android_kernel_sony_sm6450` | the LineageOS port's device tree and kernel with the Sailfish OS changes (branch `hybris-23.2`) |
| `libhybris`, `libhybris-source`, `ofono-binder-plugin-ext-qti`, `geoclue-providers-hybris`, `libncicore`, `nfcd-binder-plugin`, `droid-bthelper` | middleware with this port's fixes (branches `pdx246-*`) |

## Licences

Each repository keeps the licence of the official code it builds on: the device-side packaging
follows mer-hybris' templates (BSD-3-Clause for droid-hal and droid-hal-version, GPL-2.0-only for
droid-config and the boot images), forks keep their upstream licence, the scripts here are
BSD-3-Clause and the documentation is CC-BY-SA-4.0. Patches keep the licence of the project they
change. Jolla's closed Sailfish OS components are not part of these repositories; images built
from them install those from Jolla's repositories.

## Credits

Sailfish OS and its porting kit are Jolla's and mer-hybris'. This port builds on the work of the
Sailfish OS community ports for Sony phones: the Xperia 1/5 IV port (sailfishos-sony-nagara, with
rinigus' AIDL IMS plugin and droid-bthelper) and the Xperia 10 IV/10 V port (sharks-dev), on
Halium (droidmedia's Android 16 adaptation, the audio compatibility layer) and on the LineageOS
23.2 port for the Xperia 10 VI.
