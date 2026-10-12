<!--
SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Installing Sailfish OS on the Sony Xperia 10 VI (pdx246)

No image is released yet; these steps are for an image you built yourself ([BUILD.md](BUILD.md))
and will apply to released images as well. The image zip contains the same instructions in
`flashing-README.txt`.

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
failed: No such device)`, the phone usually reached fastbootd anyway: check with
`fastboot getvar is-userspace`.

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
