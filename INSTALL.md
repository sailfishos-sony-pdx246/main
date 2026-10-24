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

The script checks the phone model and the md5 sums, makes slot a active and reboots into the
userspace fastboot (fastbootd) of the LineageOS recovery. There `flash-preflight.sh` checks that
fastbootd runs from slot a, that no Virtual A/B merge is pending and that `vendor_dlkm_a`
exists, and stops with an explanation if not, before anything is written. It then writes
`vendor_dlkm_a` and `userdata` (the Sailfish OS root filesystem) from fastbootd, returns to the
bootloader, writes `boot_a`, `vendor_boot_a` and `dtbo_a`, and reboots.

fastbootd comes first because it lives in `recovery_a`, which boots with the kernel of `boot_a`
and the modules of `vendor_boot_a`; on the first install these are still LineageOS's.

**If `flash.sh` stops halfway** (the USB connection can drop during a large transfer):
reconnect until `fastboot devices` lists the phone, run `fastboot reboot bootloader`, and
start `./flash.sh` again. If it stops right after "reboot fastboot" with `FAILED (usb_read
failed: No such device)`, the phone usually reached fastbootd anyway (`fastboot getvar
is-userspace` answers `yes`). A new run can hit the same race; instead, finish the remaining
steps of `flash.sh` by hand, in the image's directory (with `sudo` if your fastboot needs it;
for a fastboot outside the `PATH`, give its path, and run the first line as
`FASTBOOT_BIN_NAME=/path/to/fastboot ./flash-preflight.sh`):

```sh
./flash-preflight.sh
fastboot flash vendor_dlkm_a vendor_dlkm.img
fastboot flash userdata sailfish.img001
fastboot reboot bootloader
fastboot flash boot_a hybris-boot.img
fastboot flash vendor_boot_a vendor_boot.img
fastboot flash dtbo_a dtbo.img
fastboot --set-active=a
fastboot reboot
```

Do not go on if the pre-flight check fails.

**Flashing by hand:** see `flashing-README.txt` in the zip. Always use the explicit `_a`
partition names, flash logical partitions (`vendor_dlkm_a`) from fastbootd only, and flash
`boot`, `vendor_boot`, `dtbo` and `vendor_dlkm` from the same image together.

## 3. First start

- The first start takes longer than later ones. Then the setup asks for the language, the
  date and time and a security code, and shows a short tutorial.
- **Mobile data, LTE and VoLTE** work only after you enable mobile data and choose the SIM
  for data (Settings, Mobile network). Calls over VoLTE need that too.
- **Developer mode** (Settings, Developer tools) gives you a terminal and SSH.
- The Jolla Store is not available for this port.

## 4. Flashing again over Sailfish OS

fastbootd cannot be reached while `boot_a` holds Sailfish OS: `fastboot reboot fastboot` then
just starts Sailfish OS again, and `flash.sh` waits for fastbootd forever (stop it with
Ctrl-C; nothing has been written). So first enter the bootloader and flash the saved LineageOS
images of the release to slot a:

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
repository.

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

What to expect: Android runs inside the Waydroid app, in its own window, and only while the app is
open. Android apps do not appear in the app grid, and their notifications do not reach Sailfish
OS. The images below have no Google services.

All commands run in a root shell (`devel-su`, needs Developer mode).

1. Add the Chum repository. It has the Waydroid app (waydroid-runner) and Waydroid's dependencies:

   ```sh
   ssu ar sailfishos-chum https://repo.sailfishos.org/obs/sailfishos:/chum/5.1_aarch64/
   zypper ref
   ```

2. Download the port's Waydroid packages from the
   [release](https://github.com/sailfishos-sony-pdx246/main/releases/latest) (`waydroid-1.6.3-1.noarch.rpm`,
   `waydroid-gbinder-config-hybris-1.6.3-1.noarch.rpm` and
   `droid-config-pdx246-waydroid-<version>.aarch64.rpm`), for example with the browser into
   Downloads, and install them from that folder together with the app:

   ```sh
   cd /home/defaultuser/Downloads
   zypper in --allow-unsigned-rpm ./waydroid-1.6.3-1.noarch.rpm \
       ./waydroid-gbinder-config-hybris-1.6.3-1.noarch.rpm \
       ./droid-config-pdx246-waydroid-*.aarch64.rpm waydroid-runner
   ```

   Use these instead of Chum's `waydroid`: they carry the fixes for this phone's Android 16 vendor
   and binder devices, and droid-config-pdx246-waydroid sets the phone up for them.

3. Download the Android images, about 950 MB, and unpack them where Waydroid looks for
   preinstalled images (unpacking needs about 3 GB free in /home). `waydroid init` cannot
   download images for this phone itself: there is no vendor image channel for it. These are the
   images the port is tested with, LineageOS 20 of 2026-09-27:

   ```sh
   cd /home/waydroid-extra
   curl -L -o system.zip https://sourceforge.net/projects/waydroid/files/images/system/lineage/waydroid_arm64/lineage-20.0-20260927-VANILLA-waydroid_arm64-system.zip/download
   curl -L -o vendor.zip https://sourceforge.net/projects/waydroid/files/images/vendor/waydroid_arm64/lineage-20.0-20260927-HALIUM_13-waydroid_arm64-vendor.zip/download
   sha256sum system.zip vendor.zip
   ```

   The sums must be `5fb8179ed4455f45919c5a2bfbfdd1591619295994ad321217f03bb1dcfc53a7` for
   system.zip and `b1dde0b0f97bb06812c952424925f61c17e73d91f54b0f7c77d272621d473a9e` for
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

5. Open **Waydroid** from the app grid. Android appears after about half a minute; if the app
   closes before that, open it again. Install Android apps inside Android, for example F-Droid
   from f-droid.org in Android's browser.

**If Android does not start:** `systemctl status waydroid-container` shows why the service refused
to start (lines beginning with `pdx246-waydroid:`), and `waydroid log` shows Waydroid's log. Do not
use `waydroid show-full-ui` or the waydroid-settings package: Android then gets no touch input.

**Removing Waydroid:** `zypper rm --clean-deps waydroid` removes it with the app, the port's
Waydroid packages and the dependencies installed for them. Android's system and data stay in
`/home/waydroid`, `/home/waydroid-extra` and `.local/share/waydroid` in your home folder; delete
these to free the space.
