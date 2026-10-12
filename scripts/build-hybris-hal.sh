#!/bin/bash
# SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
# SPDX-License-Identifier: BSD-3-Clause
#
# Sailfish OS: build the Android side of pdx246 (hybris-hal) on the host.
#   setsid nohup bash build-hybris-hal.sh gate  > build-<date>-gate.log 2>&1 < /dev/null &
#   setsid nohup bash build-hybris-hal.sh build > build-<date>-hal.log  2>&1 < /dev/null &
# The tree is $ANDROID_ROOT, or ANDROID_ROOT from ~/.hadk.env without the SDK's /parentroot.
# Finished only when the log has "BUILD EXIT=".
#   gate:  soong/kati analysis plus the kernel .config, then hybris/mer-kernel-check
#          (droid-hal's package build runs the same check and stops on an ERROR).
#   build: hybris-hal droidmedia vendor_dlkmimage, then checks on the results.
#   targets <t>...: build extra targets, e.g. audio.hidl_compat.default.
# Same lunch combo as the LineageOS release build: a bare `lunch lineage_pdx246` would
# mean trunk_staging/eng.
STAGE=${1:?usage: $0 gate|build|targets <target>...}
shift
T=${ANDROID_ROOT:-}
if [ -z "$T" ] && [ -f "$HOME/.hadk.env" ]; then
	T=$(. "$HOME/.hadk.env" && echo "$ANDROID_ROOT")
fi
[ -d "$T/.repo" ] || T=${T#/parentroot}
[ -d "$T/.repo" ] && cd "$T" || { echo "BUILD EXIT=99 (no tree: '$T')"; exit 99; }
echo "=== build-hybris-hal.sh $STAGE $(date '+%F %T') ==="
# hybris-boot's droidmedia target derives its module list from PORT_ARCH
# (external/droidmedia/detect_build_targets.sh); unset, it silently builds nothing.
export PORT_ARCH=aarch64
source build/envsetup.sh
lunch lineage_pdx246-bp4a-userdebug || { echo "BUILD EXIT=98 (lunch)"; exit 98; }
echo "release: $(get_build_var TARGET_RELEASE)  board api: $(get_build_var RELEASE_BOARD_API_LEVEL)"
O=out/target/product/pdx246
CHECK=hybris/mer-kernel-check/mer_verify_kernel_config

check_kconfig() {
	local rc=0 c
	for c in $O/obj/KERNEL_OBJ/.config $O/obj/DTB_OBJ/.config; do
		[ -f "$c" ] || continue
		echo "=== mer-kernel-check $c"
		perl $CHECK "$c" >"$c.mer-check" 2>&1
		local r=$?
		echo "rc=$r  ERRORs: $(grep -c ERROR "$c.mer-check")  WARNINGs: $(grep -c WARNING "$c.mer-check")"
		grep ERROR "$c.mer-check"
		[ $r -eq 0 ] || rc=1
	done
	return $rc
}

case $STAGE in
gate)
	m kernelconfig
	rc=$?
	echo "BUILD RC=$rc $(date +%T)"
	[ $rc -eq 0 ] && { check_kconfig; rc=$?; }
	grep -E "^CONFIG_(DEVTMPFS|SYSVIPC|VT|PM_AUTOSLEEP|BT_HCIVHCI)=|^# CONFIG_(DUMMY|STATIC_USERMODEHELPER) is not set" \
		$O/obj/KERNEL_OBJ/.config
	;;
build)
	m hybris-hal droidmedia vendor_dlkmimage audio.hidl_compat.default
	rc=$?
	echo "BUILD RC=$rc $(date +%T)"
	check_kconfig || rc=1
	echo "=== kernel release: $(cat $O/obj/KERNEL_OBJ/include/config/kernel.release 2>&1)"
	echo "=== modules: vendor_dlkm $(ls $O/vendor_dlkm/lib/modules/*.ko 2>/dev/null | wc -l) (expect 351)," \
		"vendor_ramdisk $(ls $O/vendor_ramdisk/lib/modules/*.ko 2>/dev/null | wc -l) (expect 302)"
	echo "=== droidmedia: $(ls $O/system/lib64/libdroidmedia.so $O/system/bin/minimediaservice $O/system/bin/minisfservice $O/system/lib64/libminisf.so 2>&1 | tr '\n' ' ')"
	echo "=== audio compat: $(ls $O/system/lib64/hw/audio.hidl_compat.default.so 2>&1)"
	echo "=== images"
	ls -la --time-style=+%F_%T $O/hybris-boot.img $O/hybris-recovery.img $O/boot.img \
		$O/vendor_boot.img $O/dtbo.img $O/vendor_dlkm.img 2>&1
	for i in hybris-boot hybris-recovery; do
		echo "$i: $(python3 system/tools/mkbootimg/unpack_bootimg.py --boot_img $O/$i.img 2>/dev/null |
			grep -E 'boot image header version' | head -1)"
	done
	;;
targets)
	m "$@"
	rc=$?
	echo "BUILD RC=$rc $(date +%T)"
	for t in "$@"; do find $O -name "$t*" -mmin -120 -printf '%TF_%TT %s %p\n' 2>/dev/null | head -5; done
	;;
esac
echo "BUILD EXIT=$rc $(date +%T)"
exit $rc
