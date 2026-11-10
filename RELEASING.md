<!--
SPDX-FileCopyrightText: Johannes Meyer zum Alten Borgloh
SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Making a release

How a release of the Sailfish OS port for the Sony Xperia 10 VI is prepared, built, tested and
published. The build itself is described in [BUILD.md](BUILD.md), the installation in
[INSTALL.md](INSTALL.md).

## Names

- **Tag:** `v<Sailfish OS release>-<YYYYMMDD>` on this repository's release commit, a lightweight
  tag, for example `v5.2.0.22-20261101`.
- **Title:** `Sailfish OS <release> for the Xperia 10 VI (<YYYY-MM-DD>)`.
- **Image:** `Sailfish_OS-<release>-pdx246-0.0.1.<YYYYMMDDHHMM>.zip`. The number is the build stamp
  of droid-hal-version-pdx246 (BUILD.md step `v`), so every build has its own.

## 1. Prepare

1. Commit and push every repository that changed; pushes are fast-forwards. For a fork with a new
   branch, make that branch the default branch, and push the upstream tag that the package version
   is derived from (a fork created with only the default branch has no tags).
2. Pin `local_manifests/*.xml` and the commits in `scripts/build-packages-sdk.sh` to what was
   pushed, and check that every pin of a `sailfishos-sony-pdx246` project equals the head of its
   `upstream` branch:
   `git ls-remote https://github.com/sailfishos-sony-pdx246/<name> refs/heads/<branch>`.
3. Update `README.md` (status, what works, known issues), `INSTALL.md` (image name, LineageOS
   release, Waydroid package names) and `BUILD.md` (release numbers, branches and commits, steps).
4. If the LineageOS base changes: publish that LineageOS release's `boot.img`, `vendor_boot.img`,
   `dtbo.img`, `vendor_dlkm.img` and `recovery.img` with their `SHA256SUMS` (INSTALL.md section 1
   links them), and move the pins in `local_manifests/pdx246.xml` to that release.

## 2. Build

Build from the pinned commits as BUILD.md describes: the Android half when the kernel, the device
tree or an Android patch changed (then also steps `d` and `imgboot`), the packages, the image
(step `i`), and Waydroid's packages (steps `waydroid` and `runner`; `droid-config-pdx246-waydroid`
comes from step `c`).

Compare the image's `.packages` list with the previous release's: every added, removed or changed
package should follow from the release's changes or from Jolla's repositories. Test packages and
debugging aids installed on a test phone by hand never belong in the image.

## 3. Test

Flash the image with `flash.sh` onto a phone running the pinned LineageOS release, as INSTALL.md
describes (a fresh install, not a phone updated package by package), and check:

- the first start: language, encryption, security code, setup;
- calls over VoLTE (ringback tone, DTMF, hold, conference), SMS both ways, mobile data;
- Wi-Fi, the hotspot, Bluetooth audio and headset calls;
- speaker, earpiece, wired headphones, and the sound and vibration of a real SMS;
- the cameras (photos, videos with sound), video playback in Gallery and the browser;
- GNSS outdoors, NFC, fingerprint unlock, the sensors (rotation, proximity, light);
- USB modes (MTP, developer mode, charging only), charging and the charging limit;
- standby overnight (current and time suspended) and a reboot;
- Waydroid, installed from the release's packages as INSTALL.md section 8 describes.

Fix what fails, or list it in the known issues.

## 4. Publish

1. Collect the assets: the image zip, its `.packages` list, `waydroid`,
   `waydroid-gbinder-config-hybris`, `waydroid-runner` and `droid-config-pdx246-waydroid`, and a
   `SHA256SUMS` of all of them. INSTALL.md points to the latest release for the Waydroid packages,
   so every release carries them.
2. Write the release notes: what's new, upgrading from the previous release, before you install,
   the files with their checksums, what works, known issues, sources and credits.
3. Check the pushed commits, the release notes and the text assets for private data: IP and MAC
   addresses, serial numbers, IMEIs, phone numbers, network names, local paths.
4. Tag the release commit and push the tag:
   `git tag v<release>-<date>` and `git push origin v<release>-<date>`.
5. Create the release as a draft:
   `gh release create v<release>-<date> --repo sailfishos-sony-pdx246/main --draft --verify-tag --title "<title>" --notes-file release-notes.md <assets>`.
6. Compare the digests GitHub computed with `SHA256SUMS`, using the draft's id from
   `gh api repos/sailfishos-sony-pdx246/main/releases --jq '.[] | select(.draft) | .id'`:
   `gh api repos/sailfishos-sony-pdx246/main/releases/<id> --jq '.assets[] | "\(.digest) \(.name)"'`.
7. Publish the draft as the latest release:
   `gh api -X PATCH repos/sailfishos-sony-pdx246/main/releases/<id> -F draft=false -f make_latest=true`.
