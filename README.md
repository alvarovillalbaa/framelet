# Framelet

Last updated: 2026-10-28

A local Mac screen recorder with a recording library and clip editor. Choose a display or window, optionally include camera and audio, pause between takes, edit the clips, and export an MP4 with your canvas layout. Recordings stay on your Mac.

**Source in development. Native build and capture/edit/export acceptance are not yet verified.** This is a native macOS app, not a Vercel website or a Supabase service. The [product contract](docs/specs/recorder.md) records the owning brief, exact scope and open acceptance boundaries.

## Local build

macOS 15 or later and a Swift 5.9+ toolchain with a macOS 15+ SDK are required. There are no external package dependencies. Use a toolchain whose installed SDK contains the ScreenCaptureKit recording and microphone APIs.

```sh
./script/build_and_run.sh --build-only
./script/build_and_run.sh
```

The script builds SwiftPM, packages `dist/Framelet.app`, and applies a local ad-hoc signature. Its no-flag mode opens that real app bundle. It respects an installed Codex Storage Guard policy and never force-kills an active recording. The Codex Run action uses this same script. Debug, logs, telemetry and process-only verification modes are available; `--verify` proves only that a process launched, not successful capture or UI behavior.

Original icon artwork is in `artwork/app-icon.svg`, with a flat PNG reference
and a ten-representation `Resources/AppIcon.icns`. The bundle metadata names
the icon, and packaging copies it before the existing signing step. The actual
built bundle, Dock appearance and signed distribution remain unverified.

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
These native playback behaviors are implemented in source and await the
[focused media acceptance](docs/proposals/ordered-playback-checks.md).

## Verification and delivery

Eighteen authored XCTest cases cover timeline ordering, pause-gap omission, positive/negative camera offsets, trims, unsafe paths, identity integrity, canvas bounds, manifest round-tripping and asynchronous acknowledgement/cancellation recovery. They are source only until execution is approved. See [the compile proposal](docs/proposals/native-checks.md) and [source evidence](docs/results/2026/10-27/initial-source.md).

Twelve additional authored native cases cover the shared composition and player
using small generated media in a disposable custom library. The separate
[30-case proposal](docs/proposals/ordered-playback-checks.md) combines them with
the original eighteen and a compile/package check. None has executed. The new
test target uses only modules already in this package and system frameworks.

No account, cloud hosting, model call, paid plan or Apple enrollment is required for local source/build. Trusted external distribution requires its own Developer ID signing/notarization process and acceptance. This repository does not claim a notarized download or App Store release. Captioning, transcription, region selection, custom camera masks and cloud sharing are not implemented features.
