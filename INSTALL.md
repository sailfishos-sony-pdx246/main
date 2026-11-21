<!--
SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Installing Sailfish OS on the Sony Xperia 10 VI (pdx246)

Download the image zip and its `SHA256SUMS` from the
[releases](https://github.com/sailfishos-sony-pdx246/main/releases/latest), or build it yourself
([BUILD.md](BUILD.md)). The image zip contains the same instructions in `flashing-README.txt`.

**Flashing erases the userdata partition** (all Android data, apps and files) and replaces the
boot chain of slot a. This is an unofficial community port, not affiliated with Jolla or Sony.

There are two ways to install it:

- **In the browser:** the [web installer](https://sailfishos-sony-pdx246.github.io/web-installer/)
  installs from Chrome, Edge or Brave over USB, with no fastboot on the computer. It reads the
  zips as downloaded, checks them before it writes anything, and says what Linux or Windows may
  need first.
  - On a phone that still runs Sony's Android, choose **Install Sailfish OS from Sony's
    Android**. It also does what section 1 asks for: it unlocks the bootloader with Sony's
    unlock code, writes LineageOS 23.2 to slot a straight from its OTA zip, and then installs
    Sailfish OS.
  - Before that, install Sony's newest software update (Sony offers none once the bootloader is
    unlocked), turn on OEM unlocking in the Developer options, and get the unlock code for the
    phone's IMEI 1 from
    [Sony's unlock page](https://opendevices.sony.net/aosp-on-xperia-open-devices/get-started/unlock-bootloader/).
    Unlocking erases the phone and removes Sony's DRM keys for good.
  - Besides the image zip, the page needs a LineageOS 23.2 OTA zip for pdx246, preferably the
    newest one tested with Sailfish OS: `lineage-23.2-20261102-UNOFFICIAL-pdx246.zip` from
    [release v23.2-20261102](https://github.com/johanneszab/lineageos-pdx246-releases/releases/tag/v23.2-20261102).
  - This option is new: it has run on a phone with Sailfish OS, not yet on one with Sony's
    Android.
  - The page's other options install over LineageOS, install again (section 4) and go back to
    LineageOS (section 5).
- **With the script or by hand:** sections 1 and 2. You unlock the bootloader and install
  LineageOS yourself, then run `flash.sh` from the image zip or flash the images one by one.
  `flash.sh` remains the reference, and the web installer follows it.

## 1. Before you start

1. **Install Sony's newest software update** while the phone still runs Sony's Android.
   LineageOS 23.2 needs Sony's firmware 70.2 or newer, and Sony offers no updates once the
   bootloader is unlocked.
2. **Unlock the bootloader** with
   [Sony's unlock procedure](https://opendevices.sony.net/aosp-on-xperia-open-devices/get-started/unlock-bootloader/):
   turn on OEM unlocking in the Developer options, get the unlock code for the phone's IMEI 1,
   and run `fastboot oem unlock 0x<code>` in the bootloader's fastboot mode (section 2, step 2).
   Unlocking erases the phone.
3. **Install LineageOS 23.2 for pdx246 on slot a,** complete with its super partition
   (system, system_ext, product, vendor, vendor_dlkm, odm). Sailfish OS runs on top of these
   Android partitions of slot a and never uses slot b. Any LineageOS 23.2 build for pdx246
   works ([releases](https://github.com/johanneszab/lineageos-pdx246-releases/releases));
   Sailfish OS was tested with the builds of 2026-11-02 (v23.2-20261102, the newest) and
   2026-09-24 (v23.2-20260924). LineageOS 24 does not work: it is Android 17, and Sailfish OS
   is built for Android 16. Install it the usual LineageOS way, with its `recovery.img` and an
   `adb sideload` of the OTA zip. A sideload and an OTA update both write the inactive slot:
   an install that went to slot b has to be repeated so that slot a holds it. The LineageOS
   install also writes `vbmeta_a` with verification disabled, which the unsigned Sailfish OS
   boot image needs.
4. **Boot LineageOS to the home screen once** and leave it running for a minute, so that the
   Virtual A/B merge completes. Until then, fastbootd refuses to flash userdata.
5. **Download the images of the LineageOS release you installed:** `boot.img`,
   `vendor_boot.img`, `dtbo.img`, `vendor_dlkm.img` and `recovery.img`, and check them against
   its `SHA256SUMS` (the first four are extracted from the OTA zip and match the hashes recorded
   in it). They are the only way back: slot b holds no bootable LineageOS (Virtual A/B keeps one
   copy of the dynamic partitions), and the Sailfish OS kernel and the LineageOS modules do not
   mix, so going back means flashing all of them. Flashing again over Sailfish OS needs the
   first three (section 4).
6. Use a recent Android platform-tools `fastboot` (34 or newer).

## 2. Flashing

**From the browser:** the [web installer](https://sailfishos-sony-pdx246.github.io/web-installer/)
does what the steps below do (see the start of this document).

1. Extract the zip (`Sailfish_OS-5.2.0.22-pdx246-<version>.zip`) and enter the directory.
2. Power the phone off, then hold **volume up** while plugging in the USB cable: the bootloader's
   fastboot mode. Check that `fastboot devices` lists the phone.
3. Run:

   ```sh
   ./flash.sh
   ```

   The script runs fastboot through `sudo`, which resets the `PATH`. If your fastboot is not in
   root's `PATH` (for example platform-tools unpacked in your home folder), name it:
   `./flash.sh --fastboot /path/to/platform-tools/fastboot`.

The script checks the phone model and the md5 sums and makes slot a active. Then
`flash-preflight.sh` reboots the phone into the userspace fastboot (fastbootd) of the LineageOS
recovery and waits for it: a `FAILED (usb_read failed: No such device)` from that reboot only
means that the reply got lost, which is common and harmless. It checks that fastbootd runs from
slot a, that no Virtual A/B merge is pending and that `vendor_dlkm_a` exists, and stops with an
explanation if not, before anything is written. The script then writes `vendor_dlkm_a` and
`userdata` (the Sailfish OS root filesystem) from fastbootd, returns to the bootloader, writes
`boot_a`, `vendor_boot_a` and `dtbo_a`, and reboots.

fastbootd comes first because it lives in `recovery_a`, which boots with the kernel of `boot_a`
and the modules of `vendor_boot_a`; on the first install these are still LineageOS's.

**If `flash.sh` stops halfway** (the USB connection can drop during a large transfer):
reconnect until `fastboot devices` lists the phone, run `fastboot reboot bootloader`, and
start `./flash.sh` again. A half-written `userdata` or `vendor_dlkm_a` is rewritten by the new
run. If the run had already written `boot_a`, the new run cannot reach fastbootd (Sailfish OS
starts instead); continue as in section 4.

**Flashing by hand:** see `flashing-README.txt` in the zip. Always use the explicit `_a`
partition names, flash logical partitions (`vendor_dlkm_a`) from fastbootd only, and flash
`boot`, `vendor_boot`, `dtbo` and `vendor_dlkm` from the same image together.

## 3. First start

- **The first start encrypts your data.** After the language and the terms of use, the phone
  encrypts its user data partition (`/home`, LUKS); this takes only a few seconds. It needs a
  charger or more than 30 % battery and waits for one otherwise. The setup then asks for a
  **security code**, which cannot be skipped because it unlocks the encrypted data, and goes on
  with the internet connection, the accounts and the fingerprint, and a short tutorial.
- **Every start asks for the security code** on a keypad before Sailfish OS starts. Without input
  the phone switches itself off after about five minutes. Wi-Fi connects only after the code.
- **Choose a code you will remember, and preferably a long one.** A forgotten code cannot be
  reset: the only way back is flashing again (section 4), which erases all data. The data key is
  protected by the code alone, without a hardware-bound key, so someone with a copy of the
  phone's storage could try short codes quickly.
- **Mobile data, LTE and VoLTE** work only after you enable mobile data and choose the SIM
  for data (Settings, Mobile network). Calls over VoLTE need that too.
- **Developer mode** (Settings, Developer tools) gives you a terminal and SSH.
- The Jolla Store is not available for this port.

## 4. Flashing again over Sailfish OS

fastbootd cannot be reached while `boot_a` holds Sailfish OS: `fastboot reboot fastboot` then
just starts Sailfish OS again, and `flash.sh` stops after 90 seconds (nothing has been written;
on a computer without the `timeout` command it waits until you press Ctrl-C). So first enter
the bootloader and flash the saved images of your LineageOS release to slot a:

```sh
fastboot flash boot_a <LineageOS boot.img>
fastboot flash vendor_boot_a <LineageOS vendor_boot.img>
fastboot flash dtbo_a <LineageOS dtbo.img>
```

Do not let the phone boot normally with these; run `./flash.sh` right away. It writes the
Sailfish OS images again at the end.

## 5. Going back to LineageOS

From the bootloader, flash the saved LineageOS `boot`, `vendor_boot`, `dtbo` and `recovery`
images to the `_a` partitions; from fastbootd (`fastboot reboot fastboot`), flash its
`vendor_dlkm` image to `vendor_dlkm_a`; then format the data from the LineageOS recovery.

## 6. If the phone does not boot

- If it falls back to slot b ("device is corrupt"), enter fastboot mode and run
  `fastboot --set-active=a`. Slot b holds no bootable system.
- `hybris-recovery.img` in the zip is a debug image (a USB network shell): flash it only to
  `boot_a`, never to `recovery_a`, and restore `hybris-boot.img` afterwards.

## 7. Updates

There is no update channel yet: a new image means flashing again (section 4), which erases the
userdata partition, Android's apps and data in Waydroid included. Package updates through
`zypper` will follow once the port has a package repository.

**Never run `zypper dup`, `version --dup` or `sfos-upgrade` on this port.** Its packages are in
no repository, so a distribution upgrade replaces them with other builds or removes them: a test
run planned to remove droid-config-pdx246, droid-hal-version-pdx246 and libhybris' graphics
libraries, to install a software renderer instead, and to downgrade the port's GPS, NFC, VoLTE and
sensor fixes. The phone would most likely not start its user interface afterwards. Before you
confirm a `zypper up`, check that it does not replace one of the port's packages either.

## 8. Android apps with Waydroid

Waydroid runs Android 13 (LineageOS 20) in a container, with the phone's GPU. It is part of the
image; Android itself is downloaded when you set it up in the Waydroid app (below).

What to expect:

- Android runs in the Waydroid app's window. Closing the window keeps Android running in the
  background: it shows again at once, and its apps can notify you. To stop Android, open
  Waydroid, go back to the home screen and tap the cross on its cover. To make every close stop
  it, change **Closing the window** in Settings, Apps, Waydroid.
- The Android apps you install appear in the app grid and open in the Waydroid window.
  Android's own apps, such as its Clock or Settings, stay on Android's home screen.
- Their notifications appear in Sailfish OS; tapping one opens the app. Notifications of an
  app's running service stay in Android: a ringing Android alarm or timer is heard, but you stop
  it in Waydroid, and a music app's controls appear only there.
- Android follows Sailfish OS's time zone and its 24-hour clock setting.
- The Android images have no Google services: apps that depend on them may not work, and
  notifications that come through Google's push service do not arrive.

**Setting Android up:** open **Waydroid** from the app grid and tap **Set up Android**. Waydroid
then downloads the Android images the port is tested with, LineageOS 20's system of 2026-09-27
and vendor of 2026-10-22 (about 950 MB, from Waydroid's mirror on SourceForge), checks their
SHA-256 sums and unpacks them. This takes a few minutes and needs about 3 GB free in /home; use
Wi-Fi. If the download server stops sending, Waydroid continues where it stopped after 30
seconds. **Cancel** stops the setup, and **Try again** starts over. Android then starts in the
window after about half a minute. Install Android apps inside Android, for example F-Droid from
f-droid.org in Android's browser.

**Removing Android:** **Remove Android** in Settings, Apps, Waydroid stops Android and deletes
it with its apps and their data, which frees its space (about 2 GB, plus the apps). Opening
Waydroid then offers to set Android up again.

Waydroid's service starts when Waydroid is opened, not at boot: a phone that never sets Android
up runs no Android. Flashing a new image (section 4) erases Android with the rest of /home; set
it up again afterwards. Releases up to v5.2.0.22-20261101 did not have Waydroid in the image;
[their INSTALL.md](https://github.com/sailfishos-sony-pdx246/main/blob/v5.2.0.22-20261101/INSTALL.md#8-android-apps-with-waydroid)
describes installing it separately.

**If Android does not start:** `systemctl status waydroid-container` shows why the service refused
to start (lines beginning with `pdx246-waydroid:`), and `waydroid log` shows Waydroid's log. Do not
start Android with `waydroid show-full-ui` or install the waydroid-settings package: Android then
appears in Sailfish OS's own window manager, where it gets no touch input.

**Do not remove Waydroid's packages:** they belong to the image's configuration pattern, and
removing them also removes that pattern and droid-hal-version-pdx246. To free Android's space,
remove Android in Settings instead (above). Android's system and data are in `/home/waydroid`
and in `.local/share/waydroid` in your home folder.
