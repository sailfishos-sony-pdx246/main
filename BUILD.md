<!--
SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Building Sailfish OS for the Sony Xperia 10 VI (pdx246)

> **Tested end to end (2026-10-11/12).** A build from these repositories alone, in a new
> directory with a freshly installed Platform SDK and build target, reproduced the developer's
> image: the same 795 packages, Jolla's at identical versions and this port's at the same
> commits. The port's repositories are at https://github.com/sailfishos-sony-pdx246.

The port runs Sailfish OS 5.1.0.11 on top of the LineageOS 23.2 (Android 16 QPR2) port for the
Xperia 10 VI (XQ-ES54, XQ-ES72; one build for both). It uses libhybris: the Android vendor
blobs and a minimal Android system run underneath Sailfish OS.

## Overview

The build has two halves:

1. **The Android half ("hybris-hal")**, built on the host like LineageOS: a `repo` tree of
   [mer-hybris/android](https://github.com/mer-hybris/android) branch `hybris-23.2` (LineageOS 23.2
   plus Sailfish's hybris patches) with this port's local manifests. `make hybris-hal` produces
   the kernel, its modules, `hybris-boot.img`, `vendor_boot.img`, `dtbo.img`, `vendor_dlkm.img`
   and the Android binaries Sailfish needs.
2. **The Sailfish half**, built in Jolla's Platform SDK: the RPM packages of the adaptation
   (droid-hal, droid-config, middleware with this port's fixes), then the flashable image,
   assembled by `mic` from Jolla's package repositories plus the local packages.

Everything else in Sailfish OS comes prebuilt from Jolla's repositories.

## 1. Requirements

- **Host:** x86-64 Linux that can build LineageOS 23.2 (see the LineageOS build guide for the
  packages), 16 GB RAM or more, and `sudo` (the Platform SDK needs it).
- **Disk, Android tree:** about 180 GiB for the synced tree plus about 40 GiB for the
  hybris-hal build output. It can live on an external drive.
- **Disk, SDKs:** about 7 GiB under `/srv/sailfishos`, on a filesystem **without** `nosuid` and
  `nodev` (desktops mount USB drives with both, and `sudo` and `mic` then fail inside the SDK).
  The internal disk is the safe choice.
- **Network:** the tree sync (about 90 GiB of git objects), the SDK downloads (about 1.3 GB) and
  each image build (about 1 GB of RPMs from Jolla's repositories).
- **The phone:** unlocked bootloader, and the LineageOS 23.2 release this port is pinned to
  installed first (the vendor partitions come from it); see `INSTALL.md`.

Paths below: `$ANDROID_ROOT` is the Android tree; the SDKs see the host's `/` under
`/parentroot`, so inside the SDK the same tree is `/parentroot$ANDROID_ROOT`.

## 2. Platform SDK (once per host)

Download the Sailfish OS 5.1.0.11 SDK parts (check the published checksums):

- `https://releases.sailfishos.org/sdk/installers/latest/Jolla-latest-SailfishOS_Platform_SDK_Chroot-i486.tar.bz2`
- `https://releases.sailfishos.org/sdk/targets/Sailfish_OS-5.1.0.11-Sailfish_SDK_Tooling-i486.tar.7z`
- `https://releases.sailfishos.org/sdk/targets/Sailfish_OS-5.1.0.11-Sailfish_SDK_Target-aarch64.tar.7z`
- `https://releases.sailfishos.org/ubu/ubuntu-focal-20210531-android-rootfs.tar.bz2` (only if you
  build the Android half in Jolla's Ubuntu chroot; see section 4)

`scripts/install-sdks.sh <download dir> <android tree>` does the rest (about 2 minutes):

1. Unpack the Platform SDK to `/srv/sailfishos/sdks/sfossdk` (`sudo tar --numeric-owner -p -xjf`).
2. Inside it (`/srv/sailfishos/sdks/sfossdk/sdk-chroot`): `sudo zypper ref` (an error for
   repository `adaptation0` is expected: it is Jolla's store-only repository), then
   `sudo zypper in android-tools-hadk kmod createrepo_c`.
3. `sdk-assistant tooling create SailfishOS-5.1.0.11 <tooling .tar.7z>` and
   `sdk-assistant target create --tooling SailfishOS-5.1.0.11 sony-pdx246-aarch64 <target .tar.7z>`.
4. Optional: unpack the Ubuntu rootfs to `/srv/sailfishos/sdks/ubuntu`.

Then create `~/.hadk.env` (read by the build scripts and the SDK):

```sh
export ANDROID_ROOT="/parentroot<your tree>"   # as the SDK sees it
export VENDOR="sony"
export DEVICE="pdx246"
export HABUILD_DEVICE="pdx246"
export PORT_ARCH="aarch64"
export RELEASE="5.1.0.11"
export EXTRA_NAME=""
```

If your shell enables ccache for LineageOS builds (`USE_CCACHE`, `CCACHE_EXEC`), unset both in
`~/.mersdkubu.profile`: the Ubuntu chroot has no ccache.

## 3. The Android tree

```sh
mkdir -p $ANDROID_ROOT && cd $ANDROID_ROOT
repo init -u https://github.com/mer-hybris/android.git -b hybris-23.2 --git-lfs --no-clone-bundle
mkdir -p .repo/local_manifests
cp <main>/local_manifests/*.xml .repo/local_manifests/
repo sync -c -j8 --no-clone-bundle --retry-fetches=2 --force-sync
for p in rpm hybris/droid-configs hybris/droid-hal-version-pdx246 \
        hybris/mw/droid-hal-img-boot-pdx246 hybris/mw/libhybris hybris/mw/waydroid; do
    git -C $p submodule update --init --recursive
done
```

The last loop checks out the submodules of the adaptation repositories, libhybris and Waydroid
(mer-hybris' droid-hal-device with `build_packages.sh`, the templates, the initramfs, libhybris'
source, Waydroid's upstream source):
`repo sync` records them but does not check them out.

- **Never** pass `--reference <your LineageOS checkout>` to `repo init`: it borrows objects
  from that tree through alternates without telling you, and a later `git gc` or the removal of
  the LineageOS tree then breaks this one. Sync fresh, or reference a `repo init --mirror`.
- AOSP rate-limits big syncs (HTTP 429): rerun `repo sync` with `-j2` for the failed projects.
  The first sync downloads about 81 GB and takes 3½ to 4½ hours (the 2026-10-11 test needed one
  `-j2` rerun).

**Local manifests** (in `local_manifests/` of this repository):

| File | What |
|---|---|
| `pdx246.xml` | device tree and kernel (the port's forks, at their `hybris-23.2` branches), kernel modules and kernel device trees (the LineageOS port's repos) and `hardware/sony` (LineageOS), pinned by SHA |
| `halium.xml` | `vendor/halium/hardware` (the audio compatibility layer `audio.hidl_compat`), Halium `halium-16.0` at 0cc91ec |
| `droidmedia.xml` | `sailfishos/droidmedia` at `master` (the hybris-23.2 manifest pins branch `android15`, which was merged and deleted upstream) |
| `sailfish.xml` | the adaptation repositories and the middleware of section 5 at their paths in the tree, all pinned |

**Vendor blobs:** extract them as for LineageOS, with the device tree's `extract-files.py`, from
the stock firmware, a phone running the pinned LineageOS release, or that release's OTA zip:

```sh
cd device/sony/pdx246 && ./extract-files.py <path>/lineage-23.2-20260924-UNOFFICIAL-pdx246.zip
```

From the OTA zip, every library, binary and firmware file comes out identical to the developer's
copy (3214 files); only APKs differ, which LineageOS repackages and Sailfish OS does not use. The
port does not ship the blobs.

**Sailfish's hybris patches:** start branches on the patched projects first (the script commits
onto whatever is checked out, and a later `repo sync` drops commits on a detached HEAD), then:

```sh
repo start hybris-23.2 bionic build/make build/soong frameworks/av frameworks/native \
    hardware/libhardware system/apex system/core system/hardware/interfaces \
    system/linkerconfig system/media
hybris-patches/apply-patches.sh --mb
```

**This port's own patches** (in `patches/<project path>/`; `scripts/apply-patches.sh` applies
them after the hybris patches, skips the ones already in the branch, and can be run again):

```sh
repo start hybris-23.2 external/droidmedia hybris/hybris-boot
<main>/scripts/apply-patches.sh $ANDROID_ROOT
```


| Project | Change | Upstream status |
|---|---|---|
| `system/core` | regenerate the linker configuration after `enter_default_mount_ns` (Android 16 init) | to offer to mer-hybris |
| `system/apex` | skip the SELinux context check of decompressed APEXes without SELinux | to offer to mer-hybris |
| `frameworks/av` | expose the physical cameras of logical multi-cameras to camera API1 (ultrawide) | to offer to mer-hybris |
| `external/droidmedia` | Halium's adaptation to LineageOS 23.2 (Android 16 QPR2); a revert of 81db5a7 that keeps the codec metadata layout of Sailfish OS 5.1's gst-droid; raw decoder output named by its real layout (Qualcomm's NV12 with 128-aligned rows), with the codec's stride and slice height kept in the output metadata, which fixes browser video whose width is not a multiple of 128 | revert to be dropped once Jolla ships a matching gst-droid; the layout fix to offer to sailfishos/droidmedia |
| `hybris/hybris-boot` | pdx246 entry in `fixup-mountpoints`; init-script switches the USB controller to peripheral mode when the UDC is missing | to offer to mer-hybris |

**libhybris:** `make hybris-hal` builds libhybris' compatibility layers from
`hybris/mw/libhybris`, which no manifest provides. The port uses its own branch (a fix for
getprop/setprop aborting at exit), which `sailfish.xml` checks out there with its submodule.

## 4. Build the Android half

The HADK builds it in Jolla's Ubuntu chroot; building on the host that builds LineageOS works
just as well and needs no `sudo`. Use the same lunch combo as the LineageOS release:

```sh
scripts/build-hybris-hal.sh gate     # kernel .config + Sailfish's kernel config check
scripts/build-hybris-hal.sh build    # hybris-hal droidmedia vendor_dlkmimage audio.hidl_compat.default
```

The script runs `lunch lineage_pdx246-bp4a-userdebug` and exports `PORT_ARCH=aarch64` first:
without it, hybris-boot's `droidmedia` target is empty and the build "succeeds" without it.
`gate` runs `hybris/mer-kernel-check/mer_verify_kernel_config` on the kernel's `.config`; it
must report 0 ERRORs (the package build stops on any). `build` then checks the results: 351
modules in vendor_dlkm and 302 in vendor_ramdisk, a kernel release without `-dirty`, boot
header versions, and the droidmedia and audio-compat binaries. About 35 minutes on a 20-core
host without ccache (gate 4, build 30).

## 5. Build the packages and the image

Middleware with this port's fixes lives in `hybris/mw/`, at these branches (checked out by
`sailfish.xml`). `build_packages.sh` clones any missing middleware at its upstream branch head,
but with `-o` it builds an existing checkout as is, so these must be in place first. It takes
each package's version from `git describe --tags`; the forks carry the upstream tags it needs.

| Path | Upstream | Branch (commit) | Why |
|---|---|---|---|
| `hybris/mw/libhybris` | mer-hybris/libhybris | pdx246-0.0.5.58 (a2ae3fc; submodule 92ccb48 from libhybris-source) | getprop/setprop exit abort |
| `hybris/mw/ofono-binder-plugin-ext-qti` | rinigus/ofono-binder-plugin-ext-qti (AIDL) | pdx246-0.1.1-aidl (e912b7c) | VoLTE ringback, conference, request fixes |
| `hybris/mw/geoclue-providers-hybris` | mer-hybris/geoclue-providers-hybris | pdx246-0.3.1 (6ba81f2) | GNSS on AIDL V1 vendors |
| `hybris/mw/libncicore` | mer-hybris/libncicore | pdx246-1.2.0 (aa586b5) | NFC reader polling |
| `hybris/mw/nfcd-binder-plugin` | mer-hybris/nfcd-binder-plugin | pdx246-1.2.0 (a9598eb) | NFC core initialisation |
| `hybris/mw/droid-bthelper` | sailfishos-sony-nagara droid-bthelper | pdx246-0.3.0 (34f77d1; needs tag `0.3.0`) | Bluetooth headset calls |
| `hybris/mw/waydroid` | sailfishos-open/waydroid (upstream 1.6.3 as submodule `upstream`) | pdx246-1.6.3 (1a62070; patches in `rpm/`) | Android apps (not in the image) |
| `hybris/mw/waydroid-runner` | sailfishos-open/waydroid-runner | pdx246-0.3.1 (b2134b5) | Android's window; Android keeps running when it is closed (a setting can make closing stop it), Android apps open from the app grid (not in the image) |
| `hybris/mw/droid-hal-img-boot-pdx246` | this port | main | boot and recovery image package |

And the adaptation repositories, at the paths the HADK scripts expect:

| Path | Package | Submodule |
|---|---|---|
| `rpm/` | droid-hal-pdx246 | `dhd` = mer-hybris/droid-hal-device |
| `hybris/droid-configs` | droid-config-pdx246 | `droid-configs-device` = mer-hybris/droid-hal-configs |
| `hybris/droid-hal-version-pdx246` | droid-hal-version-pdx246 | `droid-hal-version` = mer-hybris/droid-hal-version |

`sailfish.xml` also pins the default middleware to the commits the port is tested with:
pulseaudio-modules-droid 65edd31 (14.2.106), pulseaudio-modules-droid-hidl 818df80,
mce-plugin-libhybris 2c48a3f, qt5-qpa-hwcomposer-plugin 31f4f65, sensorfw b889c3d,
parse-android-dynparts 4e6f70f, community-adaptation 8afd975.

Then, from the host (asks for the `sudo` password once, through `sdk-chroot`; the steps never
prompt, so the run can be left alone: all packages in about 20 minutes, the image in about 7):

```sh
/srv/sailfishos/sdks/sfossdk/sdk-chroot bash /parentroot<main>/scripts/build-packages-sdk.sh
```

The steps, in order (name some to run only those; the run stops at the first failure, so it
can be resumed with the remaining steps):

| Step | Builds |
|---|---|
| `d` | droid-hal-pdx246 (packages the Android build output) |
| `c` | droid-config-pdx246 and the adaptation patterns |
| `pa` | pulseaudio-modules-droid at the pinned commit |
| `mw` | the default middleware set, including libhybris |
| `dynparts`, `sensorfw`, `geoclue`, `imsqti`, `nfc`, `bthelper` | the middleware above |
| `g` | droidmedia (from `external/droidmedia`) |
| `imgboot` | droid-hal-pdx246-img-boot (always after `d`: it requires the exact version of the dtbo package) |
| `v` | droid-hal-version-pdx246 |
| `i` | the image, with `mic` |
| `waydroid` | Waydroid 1.6.3 with the port's patches (only when named; not in the image, see INSTALL.md section 8). mb2 skips `%prep`, so the step applies the spec's patches itself |
| `runner` | waydroid-runner 0.6.0 with the background mode, app launching and the close setting (only when named; not in the image) |

The image is `$ANDROID_ROOT/SailfishOScommunity-release-5.1.0.11-pdx246/Sailfish_OS-5.1.0.11-pdx246-<version>.zip`,
with the `.packages` list and the kickstart next to it. `mic` can fail while
`build_packages.sh -i` still exits 0; the script checks the log for that.

## 6. Rebuilding single packages

- `build_packages.sh` removes older versions of a package from `$ANDROID_ROOT/droid-local-repo`
  when it builds a new one. To keep a way back, copy the installed version's RPMs aside first.
- After `d`, run `imgboot` too, or the image step fails on the img-boot version pin.
- On the phone, `rpm -U` the new RPMs; config and boot-time changes need a reboot.

## 7. Known pitfalls

- The build's `zypper ref` reports an error for `adaptation0` (Jolla's store-only repository):
  expected, but a script with `set -e` stops there.
- `PORT_ARCH` unset during `make`: droidmedia silently missing.
- A kernel tree that only ever built in a working copy may miss files its `.gitignore`
  excludes (pdx246's touchscreen firmware includes): build the kernel from a fresh clone once.
- `hybris/hybris-boot/fixup-mountpoints` patterns are unanchored substrings: generate the list
  from the phone, longest names first.
- Anything that waits for an answer inside the SDK (a bare `build_packages.sh --mw`,
  `sdk-assistant` without `-y`) does not show its question when the output goes into a pipe:
  sudo runs the command in the background of its own pseudo-terminal, and the read suspends it.
  `build-packages-sdk.sh` avoids all of them.
- Packages built from `repo` checkouts carry `+HEAD` in their version where a branch checkout
  has the branch name; they sort below such builds, which matters only when mixing both on one
  phone.
