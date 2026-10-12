#!/bin/bash
# SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
# SPDX-License-Identifier: BSD-3-Clause
#
# Sailfish OS: build the pdx246 packages and the image in the Platform SDK.
# Run from the host (asks for the sudo password once, through sdk-chroot):
#   $PLATFORM_SDK_ROOT/sdks/sfossdk/sdk-chroot bash /parentroot<this repo>/scripts/build-packages-sdk.sh [step...]
# The tree is ANDROID_ROOT from ~/.hadk.env; logs go to $PDX246_LOG_DIR, by default to
# build-logs/ next to the tree.
# Steps, in order (default: all): d c pa mw dynparts sensorfw geoclue imsqti nfc bthelper g imgboot v i
# Extra step (not in the default list): libhybris
# Each step logs to pkg-<date>-<step>.log and the run stops at the first failure,
# so it can be resumed by naming the remaining steps.
# After d, always rebuild imgboot too: droid-hal-pdx246-img-boot requires the exact
# version-release of droid-hal-pdx246-kernel-dtbo, so an old img-boot makes mic's resolver
# fail in step i ("nothing provides droid-hal-pdx246-kernel-dtbo = ...", 2026-10-06).
set -uo pipefail
source "$HOME/.hadk.env"
LOGDIR=${PDX246_LOG_DIR:-$(dirname "$ANDROID_ROOT")/build-logs}
BP=rpm/dhd/helpers/build_packages.sh
cd "$ANDROID_ROOT" || { echo "no ANDROID_ROOT $ANDROID_ROOT"; exit 1; }
mkdir -p "$LOGDIR" || { echo "cannot create $LOGDIR"; exit 1; }
[ "$#" -gt 0 ] || set -- d c pa mw dynparts sensorfw geoclue imsqti nfc bthelper g imgboot v i

run() {
	local step=$1; shift
	local log=$LOGDIR/pkg-$(date +%F)-$step.log
	echo "=== $(date +%T) step $step: $*" | tee -a "$LOGDIR/pkg-$(date +%F)-summary.log"
	"$@" 2>&1 | tee "$log"
	local rc=${PIPESTATUS[0]}
	echo "=== $(date +%T) step $step: rc=$rc" | tee -a "$LOGDIR/pkg-$(date +%F)-summary.log"
	# mic can fail (e.g. a resolver problem) while build_packages.sh -i still exits 0.
	if [ "$rc" -eq 0 ] && [ "$step" = i ] && grep -qE "^Error|resolver problem" "$log"; then
		rc=1; echo "=== $(date +%T) step $step: mic reported an error, treating as rc=1" | tee -a "$LOGDIR/pkg-$(date +%F)-summary.log"
	fi
	[ "$rc" -eq 0 ] || { echo "Stopped at step $step; see $log"; exit "$rc"; }
}

case " $* " in *" d "*) case " $* " in *" imgboot "*) ;; *) echo "Note: step d without imgboot; the image step will fail on the img-boot version pin." ;; esac ;; esac

for step in "$@"; do
	case $step in
	d) run d $BP -d ;;                      # droid-hal-pdx246 (rpm/)
	# -o (offline) wherever middleware is built: sailfish.xml pins it, repo leaves those checkouts
	# on a detached HEAD, and build_packages.sh's `git pull` fails there (and would move them off
	# the pin). Step c builds community-adaptation first, so it needs -o too.
	c) run c $BP -o -c ;;                   # droid-config-pdx246 (hybris/droid-configs)
	pa)                                     # pulseaudio-modules-droid pinned to 14.2.106
		if [ ! -d hybris/mw/pulseaudio-modules-droid ]; then
			run pa git clone --recurse-submodules https://github.com/mer-hybris/pulseaudio-modules-droid.git hybris/mw/pulseaudio-modules-droid
		fi
		run pa-checkout git -C hybris/mw/pulseaudio-modules-droid checkout 65edd31f62f22e2eec1f765608ca9c6ae5c4af7b ;;
	# The default middleware set (what a bare `build_packages.sh --mw` builds for Android 11 and
	# later), one package at a time: with a bare --mw, build_packages.sh asks before each package
	# ([Y/n/all]), and an unattended run stalls there (behind sudo's pty the read stops it).
	mw) for p in libhybris pulseaudio-modules-droid pulseaudio-modules-droid-hidl \
	        mce-plugin-libhybris qt5-qpa-hwcomposer-plugin; do
	        run mw-$p $BP -o --mw=$p
	    done ;;
	dynparts) run dynparts $BP -o --mw=https://github.com/sailfish-on-nabu/parse-android-dynparts ;;
	sensorfw) run sensorfw $BP -o --mw=https://github.com/sailfishos/sensorfw --spec=rpm/sensorfw-qt5-binder.spec ;;
	# geoclue-providers-hybris: the port's branch in hybris/mw, pdx246-0.3.1 (0.3.1 plus the
	# AIDL interface-version check); offline so build_packages does not git pull it.
	geoclue) run geoclue $BP -o --mw=geoclue-providers-hybris --spec=rpm/geoclue-providers-hybris-binder.spec ;;
	# AIDL IMS client for oFono (VoLTE, SMS over IMS): rinigus/ofono-binder-plugin-ext-qti with the
	# port's fixes, branch pdx246-0.1.1-aidl (on tag 0.1.1+aidl, f5bbe27).
	imsqti) run imsqti $BP -o --mw=ofono-binder-plugin-ext-qti --spec=rpm/ofono-binder-plugin-ext-qti.spec ;;
	# NFC: mer-hybris/libncicore (branch pdx246-1.2.0: passive-only reader polling)
	# and nfcd-binder-plugin (branch pdx246-1.2.0: CORE_INIT_RSP for HIDL coreInitialized).
	# libncicore first, the plugin links against it. build_packages.sh builds with mb2
	# --no-check, so libncicore's unit tests run separately in the target (sb2, qemu).
	nfc) run nfc-libncicore $BP -o --mw=libncicore --spec=rpm/libncicore.spec
	     run nfc-libncicore-test sb2 -t "$VENDOR-$DEVICE-$PORT_ARCH" -m sdk-build make -C hybris/mw/libncicore test
	     run nfc-binder $BP -o --mw=nfcd-binder-plugin --spec=rpm/nfcd-binder-plugin.spec ;;
	# Bluetooth headset call audio: droid-bthelper tells the audio HAL (setConnectedState) when an
	# HFP/HSP headset connects; without it PAL rejects BT_SCO=on. The Nagara port's helper with the
	# port's fixes, branch pdx246-0.3.0 on upstream 511bcd9 (audio@7.0, as pdx246 serves).
	bthelper) run bthelper $BP -o --mw=droid-bthelper --spec=rpm/droid-bthelper.spec ;;
	# libhybris alone (the mw step also builds it): branch pdx246-0.0.5.58 = 0.0.5.58 plus 'keep
	# libcutils loaded at exit' (getprop/setprop aborted in the atexit dlclose). Not in the default list.
	libhybris) run libhybris $BP -o --mw=libhybris --spec=rpm/libhybris.spec ;;
	g) run g $BP -g ;;                      # droidmedia, gst-droid
	imgboot) run imgboot $BP -o -N --mw=droid-hal-img-boot-pdx246 ;;
	v) run v $BP -v ;;                      # droid-hal-version-pdx246
	i) run i $BP -i ;;                      # the image (mic, LVM)
	*) echo "unknown step $step"; exit 2 ;;
	esac
done
echo "=== all requested steps done: $*"
