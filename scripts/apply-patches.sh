#!/bin/bash
# SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
# SPDX-License-Identifier: BSD-3-Clause
#
# Apply this port's patches (patches/<project path>/*.patch) to the Android tree, after
# Sailfish's hybris patches (hybris-patches/apply-patches.sh --mb):
#   scripts/apply-patches.sh [<android tree>]
# The tree defaults to $ANDROID_ROOT, or to ANDROID_ROOT from ~/.hadk.env without its
# /parentroot prefix (the SDK's view of the host).
# Each project must be on a branch (repo start hybris-23.2 <path>): repo sync drops commits made
# on a detached HEAD. A patch whose change is already in the branch (same git patch-id) is
# skipped, so the script can be run again.
set -uo pipefail

HERE=$(cd "$(dirname "$0")/.." && pwd)
ROOT=${1:-${ANDROID_ROOT:-}}
if [ -z "$ROOT" ] && [ -f "$HOME/.hadk.env" ]; then
	ROOT=$(. "$HOME/.hadk.env" && echo "$ANDROID_ROOT")
fi
[ -d "$ROOT/.repo" ] || [ ! -d "${ROOT#/parentroot}/.repo" ] || ROOT=${ROOT#/parentroot}
[ -d "$ROOT/.repo" ] || { echo "not an Android tree: '$ROOT'" >&2; exit 1; }

rc=0
while IFS= read -r -d '' dir; do
	proj=${dir#"$HERE/patches/"}
	repo_dir="$ROOT/$proj"
	if ! git -C "$repo_dir" symbolic-ref -q HEAD >/dev/null; then
		echo "$proj: detached HEAD; run 'repo start hybris-23.2 $proj' first" >&2
		rc=1
		continue
	fi
	# patch-ids of the branch's recent commits (the hybris patches put up to ~45 on top)
	known=$(git -C "$repo_dir" log -n 300 -p --format='commit %H' | git patch-id --stable |
		cut -d' ' -f1)
	for patch in "$dir"/*.patch; do
		id=$(git patch-id --stable < "$patch" | cut -d' ' -f1)
		if [ -n "$id" ] && grep -qxF "$id" <<< "$known"; then
			echo "$proj: already applied: ${patch##*/}"
			continue
		fi
		if git -C "$repo_dir" am --3way --keep-cr --quiet "$patch"; then
			echo "$proj: applied ${patch##*/}"
		else
			git -C "$repo_dir" am --abort 2>/dev/null
			echo "$proj: FAILED: ${patch##*/}" >&2
			rc=1
			break
		fi
	done
done < <(find "$HERE/patches" -name '*.patch' -printf '%h\0' | sort -zu)
exit $rc
