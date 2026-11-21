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
3. Update `README.md` (status, what works, known issues), `INSTALL.md` (image name, the tested
   LineageOS builds) and `BUILD.md` (release numbers, branches and commits, steps).
4. Sailfish OS runs on any LineageOS 23.2 build for pdx246 (Android 16); INSTALL.md section 1
   names the builds it was tested with. When a newer 23.2 build is out, test the release on it
   (section 3) and add it to INSTALL.md and to the web installer (section 4, step 8). The device
   repositories in `local_manifests/pdx246.xml` are the sources of the port's own kernel and
   device tree; they move only when those are rebased.
5. If the release is tested with other Android images for Waydroid: put their entries from
   Waydroid's channel (ota.waydro.id) into `waydroid-ota` (`system/lineage/waydroid_arm64/VANILLA.json`,
   `vendor/waydroid_arm64/HALIUM_16.json`) and their dates into INSTALL.md section 8. Phones set
   Android up from that channel, so its files change only together with a tested release.

## 2. Build

Build from the pinned commits as BUILD.md describes: the Android half when the kernel, the device
tree or an Android patch changed (then also steps `d` and `imgboot`), the packages (Waydroid and
its dependencies among them: they are in the image) and the image (step `i`).

Compare the image's `.packages` list with the previous release's: every added, removed or changed
package should follow from the release's changes or from Jolla's repositories. Test packages and
debugging aids installed on a test phone by hand never belong in the image.

## 3. Test

Flash the image with `flash.sh` onto a phone running the newest LineageOS 23.2 build, as
INSTALL.md describes (a fresh install, not a phone updated package by package), and check:

- the first start: language, encryption, security code, setup;
- calls over VoLTE (ringback tone, DTMF, hold, conference), SMS both ways, mobile data;
- Wi-Fi, the hotspot, Bluetooth audio and headset calls;
- speaker, earpiece, wired headphones, and the sound and vibration of a real SMS;
- the cameras (photos, videos with sound), video playback in Gallery and the browser;
- GNSS outdoors, NFC, fingerprint unlock, the sensors (rotation, proximity, light);
- USB modes (MTP, developer mode, charging only), charging and the charging limit;
- standby overnight (current and time suspended) and a reboot;
- Waydroid: Android set up from the Waydroid app (INSTALL.md section 8), an Android app with
  network, and after a reboot no Waydroid until the app is opened.

If `flash-config.sh` changed, also run the new zip through the
[web installer](https://github.com/sailfishos-sony-pdx246/web-installer) against its simulated
phone (`?mock=1`, see its README): it refuses operations it does not know.

Fix what fails, or list it in the known issues.

## 4. Publish

1. Collect the assets: the image zip, its `.packages` list and a `SHA256SUMS` of both.
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
8. Add the release to the web installer: its tag, image file name, size and SHA-256 in `releases`
   in `js/device-pdx246.js` of `web-installer`, and push; GitHub Pages publishes it within a
   minute. Until then the page warns that the image is unknown. A newly tested LineageOS build
   goes first in `lineage.releases`: its tag and link, its OTA zip's name, size and SHA-256 (the
   page names the newest one for the option "Install Sailfish OS from Sony's Android") and the
   sums of its images. Other 23.2 builds are accepted with a note.
