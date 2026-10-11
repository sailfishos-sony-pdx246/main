#!/bin/bash
# SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
# SPDX-License-Identifier: BSD-3-Clause
#
# Install the Sailfish OS Platform SDK, the SDK tooling and the aarch64 build target for
# pdx246 (and optionally Jolla's Ubuntu HABUILD chroot), and write ~/.hadk.env:
#   scripts/install-sdks.sh <download dir> <android tree>
# The download dir holds the files BUILD.md section 2 lists. The SDKs go to
# $PLATFORM_SDK_ROOT (default /srv/sailfishos), which must not be mounted nosuid or nodev.
# Asks for the sudo password once; safe to run again (skips what exists).
set -euo pipefail

D=$(cd "${1:?usage: $0 <download dir> <android tree>}" && pwd)
TREE=$(cd "${2:?usage: $0 <download dir> <android tree>}" && pwd)
RELEASE=5.1.0.11
export PLATFORM_SDK_ROOT=${PLATFORM_SDK_ROOT:-/srv/sailfishos}
SDK=$PLATFORM_SDK_ROOT/sdks/sfossdk
UBU=$PLATFORM_SDK_ROOT/sdks/ubuntu
TOOLING=SailfishOS-$RELEASE
TARGET=sony-pdx246-aarch64
CHROOT_TAR=$D/Jolla-latest-SailfishOS_Platform_SDK_Chroot-i486.tar.bz2
TOOLING_TAR=$D/Sailfish_OS-$RELEASE-Sailfish_SDK_Tooling-i486.tar.7z
TARGET_TAR=$D/Sailfish_OS-$RELEASE-Sailfish_SDK_Target-aarch64.tar.7z
UBU_TAR=$D/ubuntu-focal-20210531-android-rootfs.tar.bz2

step() { printf '\n=== %s\n' "$*"; }

for f in "$CHROOT_TAR" "$TOOLING_TAR" "$TARGET_TAR"; do
	[ -f "$f" ] || { echo "missing: $f" >&2; exit 1; }
done
if findmnt -no OPTIONS -T "$(dirname "$PLATFORM_SDK_ROOT")" | grep -qE '(^|,)(nosuid|nodev)(,|$)'; then
	echo "$PLATFORM_SDK_ROOT is on a nosuid/nodev filesystem; sudo and mic fail there" >&2
	exit 1
fi

step "user config: ~/.hadk.env, ~/.mersdkubu.profile, ~/.bashrc"
if [ ! -e ~/.hadk.env ]; then
	cat >~/.hadk.env <<EOF
# Sailfish OS HADK environment for the Xperia 10 VI (pdx246). Paths as seen inside the SDKs,
# which see the host's / under /parentroot.
export ANDROID_ROOT="/parentroot$TREE"
export VENDOR="sony"
export DEVICE="pdx246"
export HABUILD_DEVICE="pdx246"
export PORT_ARCH="aarch64"
export RELEASE="$RELEASE"
export EXTRA_NAME=""
EOF
else
	echo "~/.hadk.env exists, left as it is"
fi
if [ ! -e ~/.mersdkubu.profile ]; then
	cat >~/.mersdkubu.profile <<'EOF'
function hadk() { source $HOME/.hadk.env; echo "Env setup for $DEVICE"; }
export PS1="HABUILD_SDK [\${DEVICE}] $PS1"
# A ccache setup for LineageOS builds leaks in here; the Ubuntu chroot has no ccache.
unset USE_CCACHE CCACHE_EXEC
hadk
EOF
fi
if ! grep -q 'PLATFORM_SDK_ROOT' ~/.bashrc; then
	cat >>~/.bashrc <<EOF
# Sailfish OS Platform SDK (enter with: sfossdk)
export PLATFORM_SDK_ROOT=$PLATFORM_SDK_ROOT
alias sfossdk=\$PLATFORM_SDK_ROOT/sdks/sfossdk/sdk-chroot
if [[ \$SAILFISH_SDK ]]; then
  PS1="PlatformSDK \$PS1"
  function hadk() { source \$HOME/.hadk.env; echo "Env setup for \$DEVICE"; }
  hadk
fi
EOF
fi

sudo -v
if [ ! -x "$SDK/sdk-chroot" ]; then
	step "unpacking the Platform SDK into $SDK"
	sudo mkdir -p "$SDK"
	sudo tar --numeric-owner -p -xjf "$CHROOT_TAR" -C "$SDK"
else
	step "Platform SDK already unpacked"
fi

step "setting up inside the Platform SDK"
# One script string for bash -c, as the HADK does it; the values go in shell-quoted.
INNER=$(printf 'TOOLING_TAR=%q TARGET_TAR=%q TOOLING=%q TARGET=%q\n' \
	"/parentroot$TOOLING_TAR" "/parentroot$TARGET_TAR" "$TOOLING" "$TARGET")
INNER+=$'\n'$(cat <<'EOF'
set -euo pipefail
grep -E "^(NAME|VERSION)=" /etc/os-release
# adaptation0 is Jolla's store-only adaptation repository (it needs store credentials); a
# community port does not use it, so its refresh error is expected (zypper exits 4 or 106).
sudo zypper --non-interactive ref || echo "(the refresh error for adaptation0 is expected)"
rc=0; sudo zypper --non-interactive in android-tools-hadk kmod createrepo_c || rc=$?
[ $rc -eq 0 ] || [ $rc -eq 106 ] || { echo "zypper install failed: $rc"; exit $rc; }
rpm -q android-tools-hadk kmod createrepo_c
sdk-assistant tooling list 2>/dev/null | grep -q "$TOOLING" ||
	sdk-assistant -y tooling create "$TOOLING" "$TOOLING_TAR"
sdk-assistant target list 2>/dev/null | grep -q "$TARGET" ||
	sdk-assistant -y target create --tooling "$TOOLING" "$TARGET" "$TARGET_TAR"
sdk-assistant list
EOF
)
"$SDK/sdk-chroot" bash -c "$INNER"

if [ -f "$UBU_TAR" ] && [ ! -f "$UBU/etc/debian_version" ]; then
	step "unpacking the Ubuntu HABUILD chroot into $UBU"
	sudo mkdir -p "$UBU"
	sudo tar --numeric-owner -xjf "$UBU_TAR" -C "$UBU"
fi

step "done"
echo "Enter the Platform SDK with: sfossdk (in a new shell, or after: source ~/.bashrc)"
