# Framelet

Last updated: 2026-11-12

A local Mac screen recorder with a recording library and clip editor. Choose a display or window, optionally include camera and audio, pause between takes, edit the clips, and export an MP4 with your canvas layout. Recordings stay on your Mac.

**A universal developer preview is available. Native editing and actual silent-window capture through pause, reopen and export passed on disposable Macs at their recorded sources.** This is a native macOS app, not a Vercel website or a Supabase service. The [product contract](docs/specs/recorder.md) records the owning brief, exact scope and open acceptance boundaries.

## Download the preview

[Download Framelet 0.1.5 for Apple silicon and Intel Macs](https://github.com/alvarovillalbaa/framelet/releases/download/v0.1.5-preview.1/Framelet-0.1.5-macos-universal.zip)
(macOS 15+), with its [SHA-256 checksum](https://github.com/alvarovillalbaa/framelet/releases/download/v0.1.5-preview.1/Framelet-0.1.5-macos-universal.zip.sha256),
[build manifest](https://github.com/alvarovillalbaa/framelet/releases/download/v0.1.5-preview.1/Framelet-preview-manifest.json)
and [later playback qualification](https://github.com/alvarovillalbaa/framelet/releases/download/v0.1.5-preview.1/Framelet-playback-qualification.json).

Version 0.1.5/build6 fixes the black Recording preview caused by a tiny final
instruction gap. Both Release slices/ZIP/signatures passed; the exact archive
also passed all ten native playback phases and nine rendered-color assertions
on an Intel VM. [Public delivery](docs/results/2026/11-12/coverage-preview-publication.md)
verified all four server digests and anonymous downloaded bytes.

The [developer preview](https://github.com/alvarovillalbaa/framelet/releases/tag/v0.1.5-preview.1)
is ad-hoc signed, without Developer ID or notarization. Apple silicon runtime
and downloaded-app Gatekeeper acceptance remain unverified. See
[installation and trust limits](docs/distribution.md). Downloading does not grant
recording permissions.

## Local build

macOS 15 or later and a Swift 5.9+ toolchain with a macOS 15+ SDK are required. There are no external package dependencies. Use a toolchain whose installed SDK contains the ScreenCaptureKit recording and microphone APIs.

```sh
./script/build_and_run.sh --build-only
./script/build_and_run.sh
```

For a Release preview archive containing both Apple silicon and Intel slices:

```sh
./script/build_and_run.sh --build-preview
```

This mode never launches or quits Framelet. It refuses existing preview ZIP/
checksum leaves and produces `dist/Framelet-0.1.5-macos-universal.zip` plus its
`.zip.sha256` checksum. Use the reviewed `v0.1.5-preview.1` tag to reproduce
the public package. It uses the same icon, bundle metadata and ad-hoc signing
flow. The [universal package](docs/results/2026/11-12/coverage-preview-attempt-1.md)
and [full Release playback](docs/results/2026/11-12/coverage-playback-attempt-1.md)
passed their separate scopes. Earlier 30-case evidence retains its original
ARM64/debug source/profile. See [distribution notes](docs/distribution.md).

The [first packaging invocation](docs/results/2026/11-08/preview-package-attempt-1.md)
stopped before build because the metadata observer used a Linux-only Python
API. Cleanup could not be verified. The [second invocation](docs/results/2026/11-08/preview-package-attempt-2.md)
verified Mac-native metadata and cleanup, then encountered an Xcode build-service
crash before Swift compilation. The third native per-architecture build and full
ZIP round-trip passed. Both failures remain preserved; download publication is
recorded with the [public release/tag/digest readback](docs/results/2026/11-08/preview-package-publication.json).

The script builds SwiftPM, packages `dist/Framelet.app`, and applies a local ad-hoc signature. Its no-flag mode opens that real app bundle. It respects an installed Codex Storage Guard policy and never force-kills an active recording. The Codex Run action uses this same script. Debug, logs, telemetry and process-only verification modes are available; `--verify` proves only that a process launched, not successful capture or UI behavior.

Original icon artwork is in `artwork/app-icon.svg`, with a flat PNG reference
and a ten-representation `Resources/AppIcon.icns`. The bundle metadata names
the icon, and packaging copies it before the existing signing step. App bundle
packaging and a local ad-hoc signature were verified in CI; Dock appearance and
trusted distribution remain unverified.

```sh
./script/render_app_icon.sh --check
```

The optional artwork exporter uses Bash and Python 3's standard library; it
does not build, sign or launch Framelet. Omit `--check` to regenerate the PNG
and ICNS. The comparison checks current-host output bytes, which can vary with
Python/zlib versions on other machines. See [icon-source evidence](docs/results/2026/10-28/app-icon.md).

The first Choose source action opens macOS's content-sharing picker. Camera and microphone default off and are requested only when enabled for a recording. Source selection does not start recording. System permission refusals are surfaced; the app does not bypass them. No permission or device access is needed just to review source or run the proposed isolated core tests.

The library lives in the app's Application Support folder as UUID-named `.framelet` packages. The manifest preserves source segments, camera offsets, clip edits and canvas settings. Originals and partial media remain after failures. Removing a clip edits the timeline; moving a recording to Trash requires confirmation. Export creates a new file and leaves source media intact. Unfinished packages are shown as interrupted on the next launch.

Preview defaults to **Recording**, with one playback cursor across the ordered,
trimmed edit. It shares the export composition's canvas, camera gaps and source
audio. Choose **Selected Clip** to audition a single clip. Changing the edit or
preview scope stops and reloads playback; active capture clears the preview.
Playback failures expose **Reload Preview** without changing original files.
These native playback behaviors have
[focused synthetic-media evidence](docs/results/2026/10-28/ordered-playback-checks.md).

Version 0.1.5 [passed full Release playback](docs/results/2026/11-12/coverage-playback-attempt-1.md):
play/pause, continuous take boundary, global seeks, Selected Clip reset, end/
replay and normal Quit/reopen. Original screenshots and independent colors,
actual Release process/bundle/input hashes and acknowledged cleanup verify the
result. The [direct product regression](docs/results/2026/11-12/exact-coverage-attempt-1.md)
also covers original, fractional-trim and reordered projects.

The earlier [0.1.3](docs/results/2026/11-12/release-playback-attempt-5.md) and
[0.1.4](docs/results/2026/11-12/compatible-playback-attempt-1.md) Recording-pixel
failures remain preserved. The [causal experiment](docs/results/2026/11-12/composition-properties-attempt-2.md)
isolated instructions ending one project tick before the native asset; the
builder now covers the exact asset duration. The old 0.1.4
[raw failed packet](docs/results/2026/11-12/compatible-packet-verification.md)
remains publicly preserved. No old failed verdict was overwritten.

## Verification and delivery

Eighteen core XCTest cases passed, covering timeline ordering, pause-gap omission, positive/negative camera offsets, trims, unsafe paths, identity integrity, canvas bounds, manifest round-tripping and asynchronous acknowledgement/cancellation recovery. See the [native results](docs/results/2026/10-28/ordered-playback-checks.md) and [initial source evidence](docs/results/2026/10-27/initial-source.md).

Twelve additional native cases passed for the shared composition and player,
using small generated media in disposable custom libraries. The approved
[30-case scope](docs/proposals/ordered-playback-checks.md) also verified native
compilation, packaging, metadata, local ad-hoc signature, unchanged source and
cleanup. The temporary workflow was removed. The test target uses only this
package's modules and system frameworks; it does not launch the app or capture.

No account, cloud hosting, model call, paid plan or Apple enrollment is required for local source/build. Trusted external distribution requires its own Developer ID signing/notarization process and acceptance. This repository does not claim a notarized download or App Store release. Captioning, transcription, region selection, custom camera masks and cloud sharing are not implemented features.

The [native edit/export journey](docs/results/2026/11-12/native-ui-attempt-9.md)
passed in a disposable macOS 15.8.2/arm64 VM: rename, trim, duplicate, reorder,
remove, Square/Sand canvas settings, real save-panel export, and saved edits
after relaunch. Independent inspection verified the actual MP4 and unchanged
originals. This uses authored silent media, not live capture or physical devices.
That original profile showed clipped edges after relaunch. The separate
[FUI02 window check](docs/results/2026/11-12/window-sizing-attempt-3.md) passed
first launch, relaunch, an additional window and relaunch again on that display,
with unchanged authored media. Physical multi-display/rotated layouts, old-install
migration, human accessibility and trusted downloaded-app launch remain open.

The separate [actual window-capture journey](docs/results/2026/11-12/capture-attempt-4.md)
passed on a macOS 15.7.9/x86_64 Debug VM: exact authored-window selection,
two real takes, Pause/Resume/Stop, normal Quit/reopen and native export.
Independent decoding verified red then blue in the 23.08-second 1920×1080 MP4,
with the pause excluded and original media/manifest hashes unchanged.
Camera, microphone and system audio were off. That capture qualification retains
its original Debug source; 0.1.5 adds separately qualified Release playback.
Selected-window titles have the earlier-OS fallback. Camera/audio synchronization
and encoded first-frame timing remain open.

The temporary playback/diagnostic controls are retired, including the
[data-only retirement closeout](docs/results/2026/11-12/composition-control-closeout.md).
All failed original attempts remain preserved. The universal 0.1.5 download
has separate package, full Release playback and anonymous-delivery evidence.
The later0.1.4 native failure's [raw result packet is permanently retained and
anonymous delivery verified](docs/results/2026/11-12/compatible-packet-verification.md).
Its temporary controls are retired; original failure/cleanup gaps remain explicit.
