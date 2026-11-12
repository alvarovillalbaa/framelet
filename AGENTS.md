# Framelet agent instructions

- Native, local macOS recorder. Keep recordings, camera/audio data, and edits on the user's Mac. No network, account, telemetry, or hosted dependency is required.
- Use first-party SwiftUI/AppKit, ScreenCaptureKit, AVFoundation, and AVKit. Preserve the screen/camera timing contract in `docs/specs/recorder.md`.
- Capture, permission prompts, microphone/camera use and UI automation need an explicit bounded execution scope. Dependency/CI changes and signed distribution follow the workspace approval gates. Source publication is covered by the owning project task; native builds/tests must respect Storage Guard and the approved verification scope.
- Never run the app, record screens, enumerate user windows, or request device access as an incidental verification step.
- Preserve source packages and partial media after failures. Never silently delete a recording or overwrite an export. Trash only the package explicitly selected by the user.
- Follow the workspace Storage Guard before building or installing. Do not bypass a failed reserve check.
- Use `script/build_and_run.sh` for local build/launch; its `--build-only` mode must never launch the app.
- Keep verification boundaries explicit: syntax parsing is not typecheck, build, capture, audio synchronization, export playback, signing, or notarization proof.

## Approved preview distribution — 8 November 2026

Standing owner approval covers [universal preview packaging](docs/proposals/preview-package-checks.md):
extend the builder with a non-launching `--build-preview`, one fixed public Mac
CI job capped at 20 minutes, Release arm64/x86_64 build, ad-hoc bundle/ZIP
round-trip verification, checksum/manifest and a GitHub prerelease. No paid
identity, notarization, store, device, account, capture or app launch. Preserve
all app/package/resource source and the old 30-case evidence; do not rerun it.
Only the builder changes among its 38 original inputs. Every new profile keeps
its actual source/toolchain/architecture boundary.

Storage Guard failed at 9.9 GiB free/34.0 GiB required. No local environment,
build, app/test/CLI/server or capture execution. Static syntax/source inspection
and bounded evidence handling only. Own and verify CI exports, caches, children,
archives and cleanup; preserve failures and retire the temporary execution path.

The [first preview control](docs/results/2026/11-08/preview-package-attempt-1.md)
failed before any build because Mac Python lacks `os.listxattr`. Its cleanup
is unverified. Standing approval covers a changed control using bounded
read-only macOS native attribute APIs via standard-library `ctypes`, with the
same builder/application source and fresh packaging checks. Preserve the first
failure; no new dependency, attribute mutation, app launch or test rerun.

The [second preview control](docs/results/2026/11-08/preview-package-attempt-2.md)
verified native metadata/cleanup but Xcode's build service crashed before
compilation. Standing approval covers the changed native single-architecture
Release builds plus `lipo`, preserving the full universal output/checks and
both failed originals. No unchanged Xcode retry, weaker architecture target,
old-test rerun, app/device action or new dependency is authorized by this fix.

[Attempt 3](docs/results/2026/11-08/preview-package-attempt-3.md) now passed the
full universal Release packaging/ZIP round-trip and owned cleanup. Both earlier
failures remain immutable with their false/true cleanup outcomes. Do not repeat
the closed packaging or old 30-test scopes. Publish unchanged retained assets;
record actual release/tag/digest readback. The archived controller guards its
original checked source, not later status-only main. App/device/trust gates
remain open, and temporary controls must stay disabled/retired.

The [preview is public](docs/results/2026/11-08/preview-package-publication.json)
at `v0.1.0-preview.1`, with all three unchanged asset server digests verified.
Main has no active workflow files; both provider workflow records are disabled
and all three QA controls retired. Do not turn public metadata into a fresh-Mac
launch or Gatekeeper/capture acceptance claim.

## Native editor qualification — 12 November 2026

Alvaro's standing "I approve everything / Keep going / Do all the work" covers
the separate [FUI01 native UI scope](docs/proposals/native-ui-acceptance.md).
This is an explicit app-launch/edit/export journey with generated media in a
fresh nonce-bound CI library, not an extension of the non-launching preview
profile. Use only its bounded temporary public Mac runner and preserve actual
failure/cleanup evidence. No source picker, screen recording, camera/microphone,
personal media, paid identity or old accepted-scope rerun. All existing product
inputs stay unchanged unless observed native evidence identifies a real defect.

[FUI01 passed](docs/results/2026/11-12/native-ui-attempt-9.md) at its exact
debug/arm64 source. Its native UI and independent file verifier are closed;
do not replay them as routine follow-up. Preserve all eight failed originals.
Standing approval covers the separate [0.1.1 preview refresh](docs/proposals/preview-refresh-checks.md),
including read-only analysis of the retained MP4 and a new non-launching
universal Release package. Only version metadata/builder guard change among
the qualified product inputs. Keep the old controller and release intact.

The [0.1.1 refresh passed](docs/results/2026/11-12/preview-refresh-attempt-1.md),
including retained-export Sand pixels and both Release slices. Do not repeat
the closed build/inspection scope. Publish its three unchanged, hash-pinned
assets through the bounded data-only publication helper; retain exact public
tag/server/anonymous-download evidence and retire only its temporary control.
Keep capture, trust, physical devices and observed narrow-window clipping open.
