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
# Extra steps (not in the default list): libhybris, waydroid, runner
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

# A fresh target cannot install droid-hal-version's build dependencies: mb2 asks zypper for them
# by capability, our droid-config obsoletes Jolla's usb-moded-defaults, and zypper's
# non-interactive mode cancels that vendor change ("Solution 1: install droid-config-pdx246 from
# vendor sony"), so nothing of the transaction is installed (clean build, 2026-10-12). Installing
# droid-config-$DEVICE by name first accepts it, as step c does for the bluez5 config; a target
# that has droid-config from earlier builds never meets the question.
config_in() {
	sdk-assistant -y maintain "$VENDOR-$DEVICE-$PORT_ARCH" zypper -n \
		--plus-repo "$ANDROID_ROOT/droid-local-repo/$DEVICE" in "droid-config-$DEVICE"
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
	# Waydroid (not in the image; users install it with droid-config-pdx246-waydroid):
	# sailfishos-open/waydroid at hybris/mw/waydroid, branch pdx246-1.6.3 (upstream 1.6.3 as
	# submodule, patches in rpm/). mb2 builds in place inside upstream/ and skips %prep, so
	# the patches would silently be left out (the first build packaged plain 1.6.3,
	# 2026-10-23); %prep must not run in place either, %setup would remove upstream/. So the
	# spec's patches are applied here, in spec order, on the clean tag, and the submodule is
	# put back on the clean tag afterwards.
	# -N: the version comes from the spec, not from the packaging repo's tags.
	# Without a checked-out submodule, git -C upstream would act on the packaging repo itself.
	waydroid) run waydroid-clean sh -c '[ -e hybris/mw/waydroid/upstream/.git ] || { echo "hybris/mw/waydroid/upstream is not checked out: git -C hybris/mw/waydroid submodule update --init"; exit 1; }; git -C hybris/mw/waydroid/upstream checkout -q -f 1.6.3 && git -C hybris/mw/waydroid/upstream clean -fdq'
	          run waydroid-patch sh -c 'cd hybris/mw/waydroid && for p in $(sed -n "s/^Patch[0-9]*:[[:space:]]*//p" rpm/waydroid.spec); do echo "applying $p"; git -C upstream apply "../rpm/$p" || exit 1; done'
	          run waydroid $BP -o -N --mw=waydroid --spec=rpm/waydroid.spec
	          run waydroid-reset sh -c 'git -C hybris/mw/waydroid/upstream checkout -q -f 1.6.3 && git -C hybris/mw/waydroid/upstream clean -fdq' ;;
	# Waydroid's window (not in the image either): the sailfishos-open/waydroid-runner fork at
	# hybris/mw/waydroid-runner, branch pdx246-0.3.1 = 0.3.1 plus the background mode (Android keeps
	# running when the window is closed) and app launching (Android apps' launchers, notification
	# taps). -N: the version comes from the spec; upstream's tags would make it 0.3.1.
	runner) run runner $BP -o -N --mw=waydroid-runner --spec=rpm/waydroid-runner.spec ;;
	g) run g $BP -g ;;                      # droidmedia, gst-droid
	imgboot) run imgboot $BP -o -N --mw=droid-hal-img-boot-pdx246 ;;
	v) run v-config config_in
	   run v $BP -v ;;                      # droid-hal-version-pdx246
	i) run i $BP -i ;;                      # the image (mic, LVM)
	*) echo "unknown step $step"; exit 2 ;;
	esac
done
echo "=== all requested steps done: $*"
