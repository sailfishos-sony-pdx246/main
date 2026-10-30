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

## 1. Before you start

1. **Unlock the bootloader** with Sony's unlock procedure.
2. **Install LineageOS 23.2 for pdx246 on slot a,** complete with its super partition
   (system, system_ext, product, vendor, vendor_dlkm, odm). Sailfish OS runs on top of these
   Android partitions of slot a and never uses slot b. Use the LineageOS build the image is
   made for, currently the build of 2026-09-24:
   [release v23.2-20260924](https://github.com/johanneszab/lineageos-pdx246-releases/releases/tag/v23.2-20260924)
   (the device repositories in [local_manifests/pdx246.xml](local_manifests/pdx246.xml) are
   pinned to it). Install it the usual LineageOS way, with its `recovery.img` and an
   `adb sideload` of the OTA zip. A sideload and an OTA update both write the inactive slot:
   an install that went to slot b has to be repeated so that slot a holds it. The LineageOS
   install also writes `vbmeta_a` with verification disabled, which the unsigned Sailfish OS
   boot image needs.
3. **Boot LineageOS to the home screen once** and leave it running for a minute, so that the
   Virtual A/B merge completes. Until then, fastbootd refuses to flash userdata.
4. **Download that release's images** `boot.img`, `vendor_boot.img`, `dtbo.img`,
   `vendor_dlkm.img` and `recovery.img`, and check them against its `SHA256SUMS` (the first
   four are extracted from the OTA zip and match the hashes recorded in it). They are the only
   way back: slot b holds no bootable LineageOS (Virtual A/B keeps one copy of the dynamic
   partitions), and the Sailfish OS kernel and the LineageOS modules do not mix, so going back
   means flashing all of them. Flashing again over Sailfish OS needs the first three
   (section 4).
5. Use a recent Android platform-tools `fastboot` (34 or newer).

## 2. Flashing

1. Extract the zip (`Sailfish_OS-5.1.0.11-pdx246-<version>.zip`) and enter the directory.
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
the bootloader and flash the saved LineageOS images of the release to slot a:

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
userdata partition. Package updates through `zypper` will follow once the port has a package
repository. Waydroid's packages are not part of the image: update them as section 8 describes.

**Never run `zypper dup`, `version --dup` or `sfos-upgrade` on this port.** Its packages are in
no repository, so a distribution upgrade replaces them with other builds or removes them: a test
run planned to remove droid-config-pdx246, droid-hal-version-pdx246 and libhybris' graphics
libraries, to install a software renderer instead, and to downgrade the port's GPS, NFC, VoLTE and
sensor fixes. The phone would most likely not start its user interface afterwards. Before you
confirm a `zypper up`, check that it does not replace one of the port's packages either.

## 8. Android apps with Waydroid

Waydroid runs Android 13 (LineageOS 20) in a container, with the phone's GPU. It is not part of
the image; install it as below. It needs release v5.1.0.11-20261024 or later: the first
release's kernel lacks the binder devices the container uses.

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
- The images below have no Google services: apps that depend on them may not work, and
  notifications that come through Google's push service do not arrive.

All commands run in a root shell (`devel-su`, needs Developer mode).

1. Add the Chum repository. It has Waydroid's dependencies python3-gbinder, waydroid-sensors and
   dnsmasq:

   ```sh
   ssu ar sailfishos-chum https://repo.sailfishos.org/obs/sailfishos:/chum/5.1_aarch64/
   zypper ref
   ```

2. Download the port's four Waydroid packages from the
   [release](https://github.com/sailfishos-sony-pdx246/main/releases/latest)
   (`waydroid-1.6.3-6.noarch.rpm`, `waydroid-gbinder-config-hybris-1.6.3-6.noarch.rpm`,
   `waydroid-runner-0.6.0-1.aarch64.rpm` and `droid-config-pdx246-waydroid-<version>.aarch64.rpm`),
   for example with the browser into Downloads, and install them from that folder:

   ```sh
   cd /home/defaultuser/Downloads
   zypper in --allow-unsigned-rpm ./waydroid-1.6.3-6.noarch.rpm \
       ./waydroid-gbinder-config-hybris-1.6.3-6.noarch.rpm \
       ./waydroid-runner-0.6.0-1.aarch64.rpm \
       ./droid-config-pdx246-waydroid-*.aarch64.rpm
   ```

   Use these instead of Chum's `waydroid` and `waydroid-runner`: they carry the fixes for this
   phone's Android 16 vendor and binder devices and the features above, and
   droid-config-pdx246-waydroid sets the phone up for them.

3. Download the Android images, about 950 MB, and unpack them where Waydroid looks for
   preinstalled images (unpacking needs about 3 GB free in /home). `waydroid init` cannot
   download images for this phone itself: there is no vendor image channel for it. These are the
   images the port is tested with, LineageOS 20's system of 2026-09-27 and vendor of 2026-10-22:

   ```sh
   cd /home/waydroid-extra
   curl -L -o system.zip https://sourceforge.net/projects/waydroid/files/images/system/lineage/waydroid_arm64/lineage-20.0-20260927-VANILLA-waydroid_arm64-system.zip/download
   curl -L -o vendor.zip https://sourceforge.net/projects/waydroid/files/images/vendor/waydroid_arm64/lineage-20.0-20261022-HALIUM_13-waydroid_arm64-vendor.zip/download
   sha256sum system.zip vendor.zip
   ```

   The sums must be `5fb8179ed4455f45919c5a2bfbfdd1591619295994ad321217f03bb1dcfc53a7` for
   system.zip and `2b1f35acc4b4536ce315464e482d0dbeb91a088f8e74ed7a9072924fac2694d1` for
   vendor.zip. Then:

   ```sh
   python3 -m zipfile -e system.zip images/
   python3 -m zipfile -e vendor.zip images/
   rm system.zip vendor.zip
   ```

4. Set Waydroid up and start its service (after a reboot it starts by itself):

   ```sh
   waydroid init
   systemctl start waydroid-container
   ```

5. Open **Waydroid** from the app grid. Android appears after about half a minute. Install
   Android apps inside Android, for example F-Droid from f-droid.org in Android's browser.

**Updating Waydroid** to a newer release's packages: close the Waydroid app, download the
packages as in step 2 and install them the same way. The update stops Android if it is still
running; open Waydroid again afterwards. A Waydroid set up with an earlier release's
instructions gets the port's Waydroid app this way, in place of Chum's; if zypper asks before
replacing Chum's waydroid-runner, choose the solution that installs the port's package. Its
vendor image of 2026-09-27 can stay: the port's waydroid package fixes that image's slow starts.

**If Android does not start:** `systemctl status waydroid-container` shows why the service refused
to start (lines beginning with `pdx246-waydroid:`), and `waydroid log` shows Waydroid's log. Do not
start Android with `waydroid show-full-ui` or install the waydroid-settings package: Android then
appears in Sailfish OS's own window manager, where it gets no touch input.

**Removing Waydroid:** `zypper rm --clean-deps waydroid` removes it with the app, the port's
Waydroid packages and the dependencies installed for them. Android's system and data stay in
`/home/waydroid`, `/home/waydroid-extra` and `.local/share/waydroid` in your home folder; delete
these to free the space.
